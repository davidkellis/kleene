require "./kleene.cr"

module Kleene
  class MultiMatchDFA
    include DSL

    @original_nfas : Array(NFA)
    getter nfas_with_err_state : Array(NFA)
    property nfa_to_dfa : Hash(NFA, DFA)
    property nfa_to_nfa_index : Hash(NFA, Int32)
    property nfa_states_to_nfa : Hash(State, NFA)
    property composite_nfa : NFA
    property composite_dfa : DFA

    def initialize(nfas : Array(NFA))
      composite_alphabet = nfas.reduce(Set(Char).new) {|memo, nfa| memo | nfa.alphabet }

      # copy NFAs and add dead-end error states to each of them
      @original_nfas = nfas
      @nfas_with_err_state = nfas.map {|nfa| with_err_dead_end(nfa, composite_alphabet) }
      @nfa_to_nfa_index = @nfas_with_err_state.map_with_index {|nfa, index| {nfa, index} }.to_h

      dfas = @nfas_with_err_state.map(&.to_dfa)
      # dfas.each {|dfa| puts dfa.to_s }
      @nfa_to_dfa = @nfas_with_err_state.zip(dfas).to_h

      # build a mapping of (state -> nfa) pairs that capture which nfa owns each state
      @nfa_states_to_nfa = Hash(State, NFA).new
      @nfas_with_err_state.each do |nfa|
        nfa.states.each do |state|
          @nfa_states_to_nfa[state] = nfa
        end
      end

      # create a composite NFA as the union of all the NFAs with epsilon transitions from every NFA state back to the union NFA's start state
      @composite_nfa = create_composite_nfa(@nfas_with_err_state)
      # puts "composite_nfa = #{@composite_nfa.to_s}"
      # puts


      @composite_dfa = @composite_nfa.to_dfa
      # puts "nfa -> dfa state mappings"
      # @composite_dfa.dfa_state_to_nfa_state_sets.each do |dfa_state, nfa_state_set|
      #   puts dfa_state.to_s
      #   nfa_state_set.each do |nfa_state|
      #     puts "  #{nfa_state.to_s}"
      #   end
      # end
      # puts

      # puts "composite_dfa = #{@composite_dfa.to_s}"
    end

    # create a composite NFA as the union of all the NFAs with epsilon transitions from every NFA state back to the union NFA's start state
    def create_composite_nfa(nfas)
      nfa = union!(nfas)

      # add epsilon transitions from all the states except the start state back to the start state
      nfa.states.each do |state|
        if state != nfa.start_state
          nfa.add_transition(NFATransition::Epsilon, state, nfa.start_state)
        end
      end
      
      nfa.update_final_states

      nfa
    end
    
    def match_tracker(input : String) : MatchTracker
      dfa = @composite_dfa.deep_clone
      match_tracker = setup_callbacks(dfa)
      
      input.each_char_with_index do |char, index|
        dfa.handle_token!(char, index)
      end

      match_tracker
    end

    def matches(input : String) : Hash(NFA, Array(MatchRef))
      mt = match_tracker(input)
      
      start_index_to_nfas_that_may_match = mt.invert_candidate_match_start_positions

      active_dfas = Array(Tuple(DFA, Int32)).new    # the Int32 represents the start of match

      input.each_char_with_index do |char, index|
        active_dfas.reject! do |dfa, start_of_match_index|
          dfa.handle_token!(char, index)
          original_nfa = @original_nfas[@nfa_to_nfa_index[dfa.origin_nfa]]
          mt.add_match(original_nfa, MatchRef.new(input, start_of_match_index..index)) if dfa.accept?

          dfa.error?
        end

        if nfas = start_index_to_nfas_that_may_match[index]?
          nfas.each do |nfa|
            dfa = nfa_to_dfa[nfa].shallow_clone

            dfa.handle_token!(char, index)
            original_nfa = @original_nfas[@nfa_to_nfa_index[dfa.origin_nfa]]
            mt.add_match(original_nfa, MatchRef.new(input, index..index)) if dfa.accept?

            active_dfas << {dfa, index} unless dfa.error?
          end
        end
      end

      mt.matches
    end

    def setup_callbacks(dfa)
      match_tracker = MatchTracker.new

      # 1. identify DFA states that correspond to successful match of first character of the NFAs
      #    then set up transition callbacks to push the index position of the start of a match of each NFA that has begun 
      #    to be matched on the transition to one of the states in (1). this maintains a stack per NFA.
      epsilon_closure_of_nfa_start_state = composite_nfa.epsilon_closure(composite_nfa.start_state)
      nfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa = composite_nfa.transitions_from(epsilon_closure_of_nfa_start_state).
                                                                                                         reject {|transition| transition.epsilon? || transition.to.error? }.
                                                                                                         map(&.to).to_set
      dfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa = nfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa.
                                                                                              compact_map {|nfa_state| dfa.nfa_state_to_dfa_state_sets[nfa_state]? }.
                                                                                              reduce{|memo, state_set| memo | state_set }
      dfa_state_to_nfas_that_have_matched_their_first_character = Hash(State, Set(NFA)).new
      # puts "callbacks"
      # puts "dfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa"
      # puts dfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa.map(&.id)
      dfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa.each do |dfa_state|
        dfa_state_to_nfas_that_have_matched_their_first_character[dfa_state] = dfa.dfa_state_to_nfa_state_sets[dfa_state].
                                                                                   select {|nfa_state| nfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa.includes?(nfa_state) }.
                                                                                   compact_map do |nfa_state|
          nfa_states_to_nfa[nfa_state] unless nfa_state == composite_nfa.start_state    # composite_nfa.start_state is not referenced in the nfa_states_to_nfa map
        end.to_set
      end

      # 2. set up transition callbacks to push the index position of the end of a successful match
      nfa_final_states = @nfas_with_err_state.map(&.final_states).reduce {|memo, state_set| memo | state_set }
      dfa_states_that_correspond_to_nfa_final_states = nfa_final_states.compact_map {|nfa_state| dfa.nfa_state_to_dfa_state_sets[nfa_state]? }.
                                                                        reduce{|memo, state_set| memo | state_set }
      nfas_that_have_transitioned_to_final_state = Hash(State, Set(NFA)).new
      dfa_states_that_correspond_to_nfa_final_states.each do |dfa_state|
        nfas_that_have_transitioned_to_final_state[dfa_state] = dfa.dfa_state_to_nfa_state_sets[dfa_state].
                                                                    select {|nfa_state| nfa_final_states.includes?(nfa_state) }.
                                                                    compact_map do |nfa_state|
          nfa_states_to_nfa[nfa_state] unless nfa_state == composite_nfa.start_state    # composite_nfa.start_state is not referenced in the nfa_states_to_nfa map
        end.to_set
      end

      # set up call transition call backs, since the callbacks may only be defined once per state and transition
      destination_dfa_states_for_callbacks = dfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa | dfa_states_that_correspond_to_nfa_final_states
      destination_dfa_states_for_callbacks.each do |dfa_state|
        dfa.on_transition_to(dfa_state) do |transition, token, token_index|
          destination_dfa_state = transition.to

          # track start of candidate match if applicable
          if dfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa.includes?(destination_dfa_state)
            dfa_state_to_nfas_that_have_matched_their_first_character[destination_dfa_state].each do |nfa|
              match_tracker.add_start_of_candidate_match(nfa, token_index)
            end
          end

          # track end of match if applicable
          if dfa_states_that_correspond_to_nfa_final_states.includes?(destination_dfa_state)
            nfas_that_have_transitioned_to_final_state[destination_dfa_state].each do |nfa|
              match_tracker.add_end_of_match(nfa, token_index)
            end
          end
        end
      end

      match_tracker
    end

  end

  class MatchTracker
    # The NFA keys in the following two structures are not the original NFAs supplied to the MultiMatchDFA.
    # They are the original NFAs that have been augmented with a dead end error state, so the keys are objects that
    # are the internal state of a MultiMatchDFA
    property candidate_match_start_positions : Hash(NFA, Array(Int32))     # NFA -> Array(IndexPositionOfStartOfMatch)
    property match_end_positions : Hash(NFA, Array(Int32))                 # NFA -> Array(IndexPositionOfEndOfMatch)

    # The NFA keys in the following structure are the original NFAs supplied to the MultiMatchDFA.
    # This is in contrast to the augmented NFAs that are used as keys in the candidate_match_start_positions and
    # match_end_positions structures, documented above ^^^.
    property matches : Hash(NFA, Array(MatchRef))  # NFA -> Array(MatchRef)

    def initialize
      @candidate_match_start_positions = Hash(NFA, Array(Int32)).new
      @match_end_positions = Hash(NFA, Array(Int32)).new
      @matches = Hash(NFA, Array(MatchRef)).new
    end

    def start_positions(nfa)
      candidate_match_start_positions[nfa] ||= Array(Int32).new
    end

    def end_positions(nfa)
      match_end_positions[nfa] ||= Array(Int32).new
    end

    def matches_for(nfa)
      matches[nfa] ||= Array(MatchRef).new
    end

    def add_start_of_candidate_match(nfa, token_index)
      # puts "add_start_of_candidate_match(#{nfa.object_id}, #{token_index})"
      positions = start_positions(nfa)
      positions << token_index
    end

    def add_end_of_match(nfa, token_index)
      # puts "add_end_of_match(#{nfa.object_id}, #{token_index})"
      positions = end_positions(nfa)
      positions << token_index
    end

    def invert_candidate_match_start_positions : Hash(Int32, Array(NFA))
      index_to_nfas = Hash(Int32, Array(NFA)).new
      candidate_match_start_positions.each do |nfa, indices|
        indices.each do |index|
          nfas = index_to_nfas[index] ||= Array(NFA).new
          nfas << nfa
        end
      end
      index_to_nfas
    end

    def add_match(nfa : NFA, match : MatchRef)
      matches = matches_for(nfa)
      matches << match
    end
  end
end
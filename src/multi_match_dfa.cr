require "./kleene.cr"

module Kleene
  class MultiMatchDFA
    include DSL

    property nfas : Array(NFA)
    property nfa_states_to_nfa : Hash(State, NFA)
    property nfa : NFA
    property dfa : DFA

    def initialize(nfas : Array(NFA))
      composite_alphabet = nfas.reduce(Set(Char).new) {|memo, nfa| memo | nfa.alphabet }

      @nfas = nfas.map {|nfa| with_err(nfa, composite_alphabet) }

      # build a mapping of (state -> nfa) pairs that capture which nfa owns each state
      @nfa_states_to_nfa = Hash(State, NFA).new
      @nfas.each do |nfa|
        nfa.states.each do |state|
          @nfa_states_to_nfa[state] = nfa
        end
      end

      @nfa = create_composite_nfa(@nfas)

      @dfa = @nfa.to_dfa
    end

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

    def matches(input : String) : Hash(NFA, Array(MatchRef))
      dfa = @dfa.deep_clone
      match_tracker = setup_callbacks(dfa)
      
      input.each_char_with_index do |char, index|
        dfa.accept_token!(char, index)
      end

      matches_per_nfa = Hash(NFA, Array(MatchRef)).new
      match_tracker

      
      matches_per_nfa
    end

    def setup_callbacks(dfa)
      match_tracker = NonOverlappingMatchTracker.new

      # 1. identify DFA states that correspond to successful match of first character of the NFAs
      epsilon_closure_of_nfa_start_state = nfa.epsilon_closure(nfa.start_state)
      nfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa = nfa.transitions_from(epsilon_closure_of_nfa_start_state).
                                                                                               reject {|transition| transition.epsilon? || transition.to.error? }.
                                                                                               map(&.to).to_set
      dfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa = nfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa.
                                                                                              compact_map {|nfa_state| dfa.nfa_state_to_dfa_state_sets[nfa_state]? }.
                                                                                              reduce{|memo, state_set| memo | state_set }

      # 2. set up transition callbacks to push the index position of the start of a match of each NFA that has begun to be matched on the transition to one of the states in (1). this maintains a stack per NFA.
      nfas_that_have_matched_their_first_character = Hash(State, Array(NFA)).new
      dfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa.each do |dfa_state|
        nfas_that_have_matched_their_first_character[dfa_state] = dfa_state_to_nfa_state_sets[dfa_state].map {|nfa_state| nfa_states_to_nfa[nfa_state] }.uniq
        dfa.on_transition_to(dfa_state, ->(transition : DFATransition, token : Char, token_index : Int32) {
          nfas_that_have_matched_their_first_character[transition.to].each do |nfa|
            match_tracker.add_start_of_candidate_match(nfa, token_index)
          end
        })
      end

      # 3. set up transition callbacks to zero out the NFA-specific start-of-match stack from (2) if we transition to a DFA state that corresponds to the error state for that NFA.
      # 4. set up transition callbacks to produce MatchRef objects on successful matches and zero out the NFA-specific start-of-match stack from (2).
      
      match_tracker
    end

  end

  class NonOverlappingMatchTracker
    property start_of_match_stack : Hash(NFA, Array(Int32))     # NFA -> Array(IndexPositionOfStartOfMatch)
    property matches : Hash(NFA, Array(MatchRef))  # NFA -> Array(MatchRef)

    def add_start_of_candidate_match(nfa, token_index)
      match_stack = start_of_match_stack[nfa] ||= Array(Int32).new
      match_stack << token_index
    end
  end
end
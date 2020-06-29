require "./kleene.cr"

module Kleene
  class RegexSet
    include DSL

    property nfas : Array(NFA)
    property nfa_states_to_nfa : Hash(State, NFA)
    property nfa : NFA
    property dfa : NFA

    def initialize(nfas : Array(NFA))
      @nfas = nfas.map(&.deep_clone)

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
      matches_per_nfa = Hash(NFA, Array(MatchRef)).new
      input.each_char_with_index do |char, index|
        dfa << char
        dfa.accepting_nfa_states.each do |accepting_nfa_state|
          nfa = @nfa_states_to_nfa[accepting_nfa_state]
          matches_for_nfa = matches_per_nfa[nfa] ||= Array(MatchRef).new
          input_start_index = ???
          matches_for_nfa << MatchRef.new(input, input_start_offset..index)
        end
      end
      matches_per_nfa
    end
  end
end
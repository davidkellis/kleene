module Kleene
  class DFATransition
    property token : Char
    property from : State
    property to : State
    
    def initialize(token, from_state, to_state)
      @token = token
      @from = from_state
      @to = to_state
    end
    
    def accept?(input)
      @token == input
    end
  end
  

  class DFA
    property alphabet : Set(Char)
    property states : Set(State)
    property start_state : State
    property current_state : State
    property transitions : Hash(State, Hash(Char, DFATransition))
    property final_states : Set(State)
    property dfa_state_to_nfa_state_sets : Hash(State, Set(State))            # this map contains (dfa_state => nfa_state_set) pairs
    
    def initialize(start_state, alphabet = DEFAULT_ALPHABET, transitions = Hash(State, Hash(Char, DFATransition)).new, @dfa_state_to_nfa_state_sets = Hash(State, Set(State)).new)
      @start_state = start_state
      @current_state = start_state
      @transitions = transitions
      
      @alphabet = alphabet
      @alphabet.concat(all_transitions.map(&.token))
      
      @states = reachable_states
      @final_states = Set(State).new

      update_final_states
      reset_current_state
    end
    
    def all_transitions() : Array(DFATransition)
      transitions.flat_map {|state, char_transition_map| char_transition_map.values }
    end

    def deep_clone
      old_states = @states.to_a
      new_states = old_states.map(&.dup)
      state_mapping = old_states.zip(new_states).to_h
      # new_transitions = @transitions.map {|t| DFATransition.new(t.token, state_mapping[t.from], state_mapping[t.to]) }
      new_transitions = transitions.map {|state, char_transition_map|
        {
          state, 
          char_transition_map.map {|char, transition|
            {char, DFATransition.new(transition.token, state_mapping[transition.from], state_mapping[transition.to])}
          }.to_h
        }
      }.to_h

      new_dfa_state_to_nfa_state_sets = dfa_state_to_nfa_state_sets.map {|dfa_state, nfa_state_set| {state_mapping[dfa_state], nfa_state_set} }.to_h
      
      DFA.new(state_mapping[@start_state], @alphabet.clone, new_transitions, new_dfa_state_to_nfa_state_sets)
    end

    def update_final_states
      @final_states = @states.select {|s| s.final? }.to_set
    end
    
    def reset_current_state
      @current_state = @start_state
    end
    
    def add_transition(token, from_state, to_state)
      @alphabet << token      # alphabet is a set, so there will be no duplications
      @states << to_state     # states is a set, so there will be no duplications (to_state should be the only new state)
      new_transition = DFATransition.new(token, from_state, to_state)
      @transitions[from_state][token] = new_transition
      new_transition
    end
    
    def match?(input : String)
      reset_current_state
      
      input.each_char do |char|
        self << char
      end
      
      if accept?
        MatchRef.new(input, 0...input.size)
      end
    end
    
    # Returns an array of matches found in the input string, each of which begins at the offset input_start_offset
    def matches_at_offset(input, input_start_offset)
      reset_current_state

      matches = [] of MatchRef
      (input_start_offset...input.size).each do |offset|
        token = input[offset]
        self << token
        if accept?
          matches << MatchRef.new(input, input_start_offset..offset)
        end
      end
      matches
    end
    
    # Returns an array of matches found anywhere in the input string
    def matches(input)
      (0...input.size).reduce([] of MatchRef) do |memo, offset|
        memo + matches_at_offset(input, offset)
      end
    end
    
    # process another input token
    def <<(input_token)
      @current_state = next_state(@current_state, input_token)
    end
    
    def accept?
      @current_state.final?
    end

    # if the DFA is currently in a final state, then we look up the associated NFA states that were also final, and return them
    def accepting_nfa_states : Set(State)
      if accept?
        dfa_state_to_nfa_state_sets[@current_state].select(&.final?).to_set
      else
        Set(State).new
      end
    end
    
    def next_state(from_state, input_token)
      # t = @transitions.find {|t| state == t.from && t.accept?(input_token) } || raise "No DFA transition found!"
      transition = @transitions[from_state][input_token]? || raise "No DFA transition found!"
      transition.to
    end

    # Returns a set of State objects which are reachable through any transition path from the NFA's start_state.
    def reachable_states
      visited_states = Set(State).new()
      unvisited_states = Set{@start_state}
      while !unvisited_states.empty?
        # outbound_transitions = @transitions.select { |t| unvisited_states.includes?(t.from) }
        outbound_transitions = unvisited_states.flat_map {|state| @transitions[state]?.try(&.values) || Array(DFATransition).new }
        destination_states = outbound_transitions.map(&.to).to_set
        visited_states.concat(unvisited_states)         # add the unvisited states to the visited_states
        unvisited_states = destination_states - visited_states
      end
      visited_states
    end
    
    # this is currently broken
    # def to_nfa
    #   dfa = self.deep_clone
    #   NFA.new(dfa.start_state, dfa.alphabet.clone, dfa.transitions)
    #   # todo: add all of this machine's transitions to the new machine
    #   # @transitions.each {|t| nfa.add_transition(t.token, t.from, t.to) }
    #   # nfa
    # end
    
    # This is an implementation of the "Reducing a DFA to a Minimal DFA" algorithm presented here: http://web.cecs.pdx.edu/~harry/compilers/slides/LexicalPart4.pdf
    # This implements Hopcroft's algorithm as presented on page 142 of the first edition of the dragon book.
    def minimize!
      # todo: I'll implement this when I need it
    end
  end
  
end
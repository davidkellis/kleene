module Kleene
  class NFATransition
    Epsilon = '\u0000'    # todo/hack: we use the null character as a sentinal character indicating epsilon transition
    
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

  class NFA
    property alphabet : Set(Char)
    property states : Set(State)
    property start_state : State
    property transitions : Hash(State, Hash(Char, NFATransition))
    property current_states : Set(State)
    property final_states : Set(State)
    
    def initialize(start_state, alphabet = DEFAULT_ALPHABET, transitions = Hash(State, Hash(Char, NFATransition)).new)
      @start_state = start_state
      @transitions = transitions
      
      @alphabet = alphabet
      @alphabet.concat(all_transitions.map(&.token))
      
      @states = reachable_states
      @current_states = Set(State).new
      @final_states = Set(State).new

      update_final_states
      reset_current_states
    end

    def all_transitions() : Array(NFATransition)
      transitions.flat_map {|state, char_transition_map| char_transition_map.values }
    end
    
    def deep_clone
      old_states = @states.to_a
      new_states = old_states.map(&.dup)
      state_mapping = old_states.zip(new_states).to_h
      new_transitions = transitions.map {|state, char_transition_map|
        {
          state, 
          char_transition_map.map {|char, transition|
            {char, NFATransition.new(transition.token, state_mapping[transition.from], state_mapping[transition.to])}
          }.to_h
        }
      }.to_h
      
      NFA.new(state_mapping[@start_state], @alphabet.clone, new_transitions)
    end

    def update_final_states
      @final_states = @states.select { |s| s.final? }.to_set
    end
    
    def reset_current_states
      @current_states = epsilon_closure([@start_state])
    end
    
    def add_transition(token, from_state, to_state)
      @alphabet << token      # alphabet is a set, so there will be no duplications
      @states << to_state     # states is a set, so there will be no duplications (to_state should be the only new state)
      new_transition = NFATransition.new(token, from_state, to_state)

      char_transition_map = @transitions[from_state] ||= Hash(Char, NFATransition).new
      char_transition_map[token] = new_transition

      new_transition
    end
    
    def match?(input : String) : MatchRef?
      reset_current_states
      
      input.each_char do |char|
        self << char
      end
      
      if accept?
        MatchRef.new(input, 0...input.size)
      end
    end
    
    # Returns an array of matches found in the input string, each of which begins at the offset input_start_offset
    def matches_at_offset(input, input_start_offset)
      reset_current_states

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
      @current_states = next_states(@current_states, input_token)
    end
    
    def accept?
      @current_states.any?(&.final?)
    end
    
    def next_states(state_set, input_token)
      # Retrieve a list of states in the epsilon closure of the given state set
      epsilon_reachable_states = epsilon_closure(state_set)
      
      # Build an array of outbound transitions from each state in the epsilon-closure
      # Filter the outbound transitions, selecting only those that accept the input we are given.
      # outbound_transitions = @transitions.select {|t| epsilon_reachable_states.includes?(t.from) && t.accept?(input_token) }
      outbound_transitions : Array(NFATransition) = epsilon_reachable_states.map {|state| @transitions.dig?(state, input_token) }.compact
      
      # Build an array of epsilon-closures of each transition's destination state.
      destination_state_epsilon_closures = outbound_transitions.map {|transition| epsilon_closure([transition.to]) }
      
      # Union each of the epsilon-closures (each is a set) together to form a flat array of states in the epsilon-closure of all of our current states.
      next_states = destination_state_epsilon_closures.reduce? {|combined_state_set, individual_state_set| combined_state_set.concat(individual_state_set) }
      
      next_states || Set(State).new
    end

    # Determine the epsilon closure of the given state set
    # That is, determine what states are reachable on an epsilon transition from the current state set (@current_states).
    # Returns a Set of State objects.
    def epsilon_closure(state_set) : Set(State)
      visited_states = Set(State).new()
      unvisited_states = state_set
      while !unvisited_states.empty?
        # epsilon_transitions = @transitions.select { |t| t.accept?(NFATransition::Epsilon) && unvisited_states.includes?(t.from) }
        epsilon_transitions = unvisited_states.map {|state| @transitions.dig?(state, NFATransition::Epsilon) }.compact
        destination_states = epsilon_transitions.map(&.to).to_set
        visited_states.concat(unvisited_states)         # add the unvisited states to the visited_states
        unvisited_states = destination_states - visited_states
      end
      visited_states
    end
    
    # Returns a set of State objects which are reachable through any transition path from the NFA's start_state.
    def reachable_states
      visited_states = Set(State).new()
      unvisited_states = Set{@start_state}
      while !unvisited_states.empty?
        # outbound_transitions = @transitions.select { |t| unvisited_states.includes?(t.from) }
        outbound_transitions = unvisited_states.flat_map {|state| @transitions[state]?.try(&.values) || Array(NFATransition).new }
        destination_states = outbound_transitions.map(&.to).to_set
        visited_states.concat(unvisited_states)         # add the unvisited states to the visited_states
        unvisited_states = destination_states - visited_states
      end
      visited_states
    end

    # This implements the subset construction algorithm presented on page 118 of the first edition of the dragon book.
    # I found a similar explanation at: http://web.cecs.pdx.edu/~harry/compilers/slides/LexicalPart3.pdf
    def to_dfa
      state_map = Hash(Set(State), State).new            # this map contains (nfa_state_set => dfa_state) pairs
      dfa_transitions = Hash(State, Hash(Char, DFATransition)).new
      dfa_alphabet = @alphabet - Set{NFATransition::Epsilon}
      visited_state_sets = Set(Set(State)).new()
      nfa_start_state_set : Set(State) = epsilon_closure([@start_state])
      unvisited_state_sets : Set(Set(State)) = Set{nfa_start_state_set}

      dfa_start_state = State.new(nfa_start_state_set.any?(&.final?))
      state_map[nfa_start_state_set] = dfa_start_state
      until unvisited_state_sets.empty?
        # take one of the unvisited state sets
        state_set = unvisited_state_sets.first

        current_dfa_state = state_map[state_set]

        # Figure out the set of next-states for each token in the alphabet
        # Add each set of next-states to unvisited_state_sets
        dfa_alphabet.each do |token|
          next_nfa_state_set = next_states(state_set, token)
          unvisited_state_sets << next_nfa_state_set

          # this new DFA state, next_dfa_state, represents the next nfa state set, next_nfa_state_set
          next_dfa_state = state_map[next_nfa_state_set] ||= State.new(next_nfa_state_set.any?(&.final?))
        
          char_transition_map = dfa_transitions[current_dfa_state] ||= Hash(Char, DFATransition).new
          char_transition_map[token] = DFATransition.new(token, current_dfa_state, next_dfa_state)
        end
        
        visited_state_sets << state_set
        unvisited_state_sets = unvisited_state_sets - visited_state_sets
      end
      
      # `state_map.invert` is sufficient to convert from a (nfa_state_set => dfa_state) mapping to a (dfa_state => nfa_state_set) mapping, because the mappings are strictly one-to-one.
      DFA.new(state_map[nfa_start_state_set], dfa_alphabet, dfa_transitions, state_map.invert)
    end
    
    # def traverse
    #   visited_states = Set.new()
    #   unvisited_states = Set[@start_state]
    #   begin
    #     state = unvisited_states.shift
    #     outbound_transitions = @transitions.select { |t| t.from == state }
    #     outbound_transitions.each {|t| yield t }
    #     destination_states = outbound_transitions.map(&.to).to_set
    #     visited_states << state
    #     unvisited_states = (unvisited_states | destination_states) - visited_states
    #   end until unvisited_states.empty?
    #   nil
    # end
    
    def graphviz
      retval = "digraph G { "
      all_transitions.each do |t|
        retval += "#{t.from.id} -> #{t.to.id} [label=\"#{t.token}\"];"
      end
      @final_states.each do |s|
        retval += "#{s.id} [color=lightblue2, style=filled, shape=doublecircle];"
      end
      retval += " }"
      retval
    end
  end
  
end
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
  
  # ->(transition : DFATransition, token : Char, token_index : Int32) : Nil { ... }
  alias DFATransitionCallback = Proc(DFATransition, Char, Int32, Nil)

  class DFA
    property alphabet : Set(Char)
    property states : Set(State)
    property start_state : State
    property current_state : State
    property transitions : Hash(State, Hash(Char, DFATransition))
    property final_states : Set(State)
    property dfa_state_to_nfa_state_sets : Hash(State, Set(State))            # this map contains (dfa_state => nfa_state_set) pairs
    property nfa_state_to_dfa_state_sets : Hash(State, Set(State))            # this map contains (nfa_state => dfa_state_set) pairs
    property transition_callbacks : Hash(DFATransition, DFATransitionCallback)
    property transition_callbacks_per_destination_state : Hash(State, DFATransitionCallback)
    @origin_nfa : NFA?
    @error_states : Set(State)?
    
    def initialize(start_state, alphabet = DEFAULT_ALPHABET, transitions = Hash(State, Hash(Char, DFATransition)).new, @dfa_state_to_nfa_state_sets = Hash(State, Set(State)).new, transition_callbacks = nil, @origin_nfa = nil)
      @start_state = start_state
      @current_state = start_state
      @transitions = transitions
      
      @alphabet = alphabet
      @alphabet.concat(all_transitions.map(&.token))
      
      @states = reachable_states(@start_state)
      @final_states = Set(State).new

      @nfa_state_to_dfa_state_sets = Hash(State, Set(State)).new
      @dfa_state_to_nfa_state_sets.each do |dfa_state, nfa_state_set|
        nfa_state_set.each do |nfa_state|
          dfa_state_set = @nfa_state_to_dfa_state_sets[nfa_state] ||= Set(State).new
          dfa_state_set << dfa_state
        end
      end

      @transition_callbacks = transition_callbacks || Hash(DFATransition, DFATransitionCallback).new
      @transition_callbacks_per_destination_state = Hash(State, DFATransitionCallback).new

      update_final_states
      reset_current_state
    end

    def origin_nfa
      @origin_nfa || raise "This DFA was not created from an NFA, therefore it has no origin_nfa."
    end

    def error_states
      @error_states ||= @states.select {|s| s.error? }.to_set
    end

    def clear_error_states
      @error_states = nil
    end
    
    def all_transitions() : Array(DFATransition)
      transitions.flat_map {|state, char_transition_map| char_transition_map.values }
    end

    def on_transition(transition, &blk : DFATransitionCallback)
      @transition_callbacks[transition] = blk
    end

    def on_transition_to(state, &blk : DFATransitionCallback)
      @transition_callbacks_per_destination_state[state] = blk
    end

    def shallow_clone
      DFA.new(start_state, alphabet, transitions, dfa_state_to_nfa_state_sets, transition_callbacks, origin_nfa)
    end

    # transition callbacks are not copied beacuse it is assumed that the state transition callbacks may be stateful and reference structures or states that only exist in `self`, but not the cloned copy.
    def deep_clone
      old_states = @states.to_a
      new_states = old_states.map(&.dup)
      state_mapping = old_states.zip(new_states).to_h
      transition_mapping = Hash(DFATransition, DFATransition).new
      new_transitions = transitions.map do |state, char_transition_map|
        {
          state_mapping[state], 
          char_transition_map.map do |char, old_transition|
            new_transition = DFATransition.new(old_transition.token, state_mapping[old_transition.from], state_mapping[old_transition.to])
            transition_mapping[old_transition] = new_transition
            {char, new_transition}
          end.to_h
        }
      end.to_h
      # new_transition_callbacks = transition_callbacks.map do |transition, callback|
      #   {
      #     transition_mapping[transition],
      #     callback
      #   }
      # end.to_h

      new_dfa_state_to_nfa_state_sets = dfa_state_to_nfa_state_sets.map {|dfa_state, nfa_state_set| {state_mapping[dfa_state], nfa_state_set} }.to_h
      
      DFA.new(state_mapping[@start_state], @alphabet.clone, new_transitions, new_dfa_state_to_nfa_state_sets, origin_nfa: origin_nfa)
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
      
      input.each_char_with_index do |char, index|
        handle_token!(char, index)
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
        handle_token!(token, offset)
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
    
    # accept an input token and transition to the next state in the state machine
    def handle_token!(input_token, token_index)
      @current_state = next_state(@current_state, input_token, token_index)
    end
    
    def accept?
      @current_state.final?
    end

    def error?
      @current_state.final?
    end

    # def terminal?
    #   accept? || error?
    # end

    # if the DFA is currently in a final state, then we look up the associated NFA states that were also final, and return them
    # def accepting_nfa_states : Set(State)
    #   if accept?
    #     dfa_state_to_nfa_state_sets[@current_state].select(&.final?).to_set
    #   else
    #     Set(State).new
    #   end
    # end
    
    # this function transitions from state to state on an input token
    def next_state(from_state, input_token, token_index)
      transition = @transitions[from_state][input_token]? || raise "No DFA transition found. Input token #{input_token} not in DFA alphabet."
      
      # invoke the relevant transition callback function
      transition_callbacks[transition]?.try {|callback_fn| callback_fn.call(transition, input_token, token_index) }
      transition_callbacks_per_destination_state[transition.to]?.try {|callback_fn| callback_fn.call(transition, input_token, token_index) }
      
      transition.to
    end

    # Returns a set of State objects which are reachable through any transition path from the DFA's start_state.
    def reachable_states(start_state)
      visited_states = Set(State).new()
      unvisited_states = Set{start_state}
      while !unvisited_states.empty?
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

    def to_s
      retval = states.map(&.to_s).join("\n")
      retval += "\n"
      all_transitions.each do |t|
        retval += "#{t.from.id} -> #{t.token} -> #{t.to.id}\n"
      end
      retval
    end
    
    # This is an implementation of the "Reducing a DFA to a Minimal DFA" algorithm presented here: http://web.cecs.pdx.edu/~harry/compilers/slides/LexicalPart4.pdf
    # This implements Hopcroft's algorithm as presented on page 142 of the first edition of the dragon book.
    def minimize!
      # todo: I'll implement this when I need it
    end
  end
  
end
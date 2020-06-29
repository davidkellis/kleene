# this is a port and extension of https://github.com/davidkellis/fsm/

require "./dsl.cr"

module Kleene
  # The default alphabet consists of the following:
  # Set{' ', '!', '"', '#', '$', '%', '&', '\'', '(', ')', '*', '+', ',', '-', '.', '/', 
  #     '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 
  #     ':', ';', '<', '=', '>', '?', '@', 
  #     'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 
  #     'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 
  #     '[', '\\', ']', '^', '_', '`', 
  #     'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 
  #     'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 
  #     '{', '|', '}', '~', "\n", "\t"}
  DEFAULT_ALPHABET = ((' '..'~').to_a + "\n\t".chars).to_set

  class NFA
    property alphabet : Set(Char)
    property states : Set(State)
    property start_state : State
    property transitions : Array(NFATransition)
    property current_states : Set(State)
    property final_states : Set(State)
    
    def initialize(start_state, transitions = [] of NFATransition, alphabet = DEFAULT_ALPHABET)
      @start_state = start_state
      @transitions = transitions
      
      @alphabet = alphabet
      @alphabet.concat(@transitions.map(&.token))
      
      @states = reachable_states
      @current_states = Set(State).new
      @final_states = Set(State).new

      update_final_states
      reset_current_states
    end
    
    def deep_clone
      old_states = @states.to_a
      new_states = old_states.map(&.dup)
      state_mapping = old_states.zip(new_states).to_h
      new_transitions = @transitions.map {|t| NFATransition.new(t.token, state_mapping[t.from], state_mapping[t.to]) }
      
      NFA.new(state_mapping[@start_state], new_transitions, @alphabet.clone)
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
      t = NFATransition.new(token, from_state, to_state)
      @transitions << t
      t
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
      outbound_transitions = @transitions.select {|t| epsilon_reachable_states.includes?(t.from) && t.accept?(input_token) }
      
      # Build an array of epsilon-closures of each transition's destination state.
      destination_state_epsilon_closures = outbound_transitions.map { |t| epsilon_closure([t.to]) }
      
      # Union each of the epsilon-closures (each is an array) together to form a flat array of states in the epsilon-closure of all of our current states.
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
        epsilon_transitions = @transitions.select { |t| t.accept?(NFATransition::Epsilon) && unvisited_states.includes?(t.from) }
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
        outbound_transitions = @transitions.select { |t| unvisited_states.includes?(t.from) }
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
      dfa_transitions = [] of DFATransition
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
        
          dfa_transitions << DFATransition.new(token, current_dfa_state, next_dfa_state)
        end
        
        visited_state_sets << state_set
        unvisited_state_sets = unvisited_state_sets - visited_state_sets
      end
      
      # `state_map.invert` is sufficient to convert from a (nfa_state_set => dfa_state) mapping to a (dfa_state => nfa_state_set) mapping, because the mappings are strictly one-to-one.
      DFA.new(state_map[nfa_start_state_set], dfa_transitions, dfa_alphabet, state_map.invert)
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
      @transitions.each do |t|
        retval += "#{t.from.id} -> #{t.to.id} [label=\"#{t.token}\"];"
      end
      @final_states.each do |s|
        retval += "#{s.id} [color=lightblue2, style=filled, shape=doublecircle];"
      end
      retval += " }"
      retval
    end
  end
  
  class State
    @@next_id : Int32 = 0

    def self.next_id
      @@next_id += 1
    end


    getter id : Int32
    property final : Bool

    def initialize(final = false, id : Int32? = nil)
      @id = id || State.next_id
      @final = final
    end

    def final?
      @final
    end
    
    def dup
      State.new(@final, nil)
    end
  end

  class NFATransition
    Epsilon = '\u0000'    # hack: we use the null character as a sentinal character indicating epsilon transition
    
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
  
  class MatchRef
    property string : String
    property range : Range(Int32, Int32)

    def initialize(original_string, match_range)
      @string = original_string
      @range = match_range
    end
    
    def match : String
      @string[@range]
    end
    
    def to_s
      match
    end
    
    def ==(other : MatchRef)
      @string == other.string &&
      @range == other.range
    end
    
    def eql?(other : MatchRef)
      self == other
    end
  end

  class DFA
    property alphabet : Set(Char)
    property states : Set(State)
    property start_state : State
    property current_state : State
    property transitions : Array(DFATransition)
    property final_states : Set(State)
    property dfa_state_to_nfa_state_sets : Hash(State, Set(State))            # this map contains (dfa_state => nfa_state_set) pairs
    
    def initialize(start_state, transitions = [] of DFATransition, alphabet = DEFAULT_ALPHABET, @dfa_state_to_nfa_state_sets = Hash(State, Set(State)).new)
      @start_state = start_state
      @current_state = start_state
      @transitions = transitions
      
      @alphabet = alphabet
      @alphabet.concat(@transitions.map(&.token))
      
      @states = reachable_states
      @final_states = Set(State).new

      update_final_states
      reset_current_state
    end
    
    def deep_clone
      old_states = @states.to_a
      new_states = old_states.map(&.dup)
      state_mapping = old_states.zip(new_states).to_h
      new_transitions = @transitions.map {|t| DFATransition.new(t.token, state_mapping[t.from], state_mapping[t.to]) }
      new_dfa_state_to_nfa_state_sets = dfa_state_to_nfa_state_sets.map {|dfa_state, nfa_state_set| {state_mapping[dfa_state], nfa_state_set} }.to_h
      
      DFA.new(state_mapping[@start_state], new_transitions, @alphabet.clone, new_dfa_state_to_nfa_state_sets)
    end

    def update_final_states
      @final_states = @states.select { |s| s.final? }.to_set
    end
    
    def reset_current_state
      @current_state = @start_state
    end
    
    def add_transition(token, from_state, to_state)
      @alphabet << token      # alphabet is a set, so there will be no duplications
      @states << to_state     # states is a set, so there will be no duplications (to_state should be the only new state)
      t = DFATransition.new(token, from_state, to_state)
      @transitions << t
      t
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
        dfa_state_to_nfa_state_sets[@current_state].select(&.final?)
      else
        Set(State).new
      end
    end
    
    def next_state(state, input_token)
      t = @transitions.find {|t| state == t.from && t.accept?(input_token) } || raise "No DFA transition found!"
      t.to
    end

    # Returns a set of State objects which are reachable through any transition path from the NFA's start_state.
    def reachable_states
      visited_states = Set(State).new()
      unvisited_states = Set{@start_state}
      while !unvisited_states.empty?
        outbound_transitions = @transitions.select { |t| unvisited_states.includes?(t.from) }
        destination_states = outbound_transitions.map(&.to).to_set
        visited_states.concat(unvisited_states)         # add the unvisited states to the visited_states
        unvisited_states = destination_states - visited_states
      end
      visited_states
    end
    
    def to_nfa
      dfa = self.deep_clone
      NFA.new(dfa.start_state, dfa.transitions, dfa.alphabet.clone)
      # todo: add all of this machine's transitions to the new machine
      # @transitions.each {|t| nfa.add_transition(t.token, t.from, t.to) }
      # nfa
    end
    
    # This is an implementation of the "Reducing a DFA to a Minimal DFA" algorithm presented here: http://web.cecs.pdx.edu/~harry/compilers/slides/LexicalPart4.pdf
    # This implements Hopcroft's algorithm as presented on page 142 of the first edition of the dragon book.
    def minimize!
      # todo: I'll implement this when I need it
    end
  end

  # class MultiFSA
  #   @nfas : Array(NFA)
  #   @composite_nfa : NFA?
  #   @composite_dfa : DFA?

  #   include DSL
    
  #   def initialize(nfas = nil)
  #     @nfas = nfas || [] of NFA
  #     @composite_nfa = nil
  #     @composite_dfa = nil
  #   end

  #   # returns the tag identifying the newly added nfa
  #   def add(nfa)
  #     @composite_dfa = nil    # invalidate memoized dfa

  #     tag = @nfas.size
  #     nfa = nfa.deep_clone
  #     nfa.tag(tag)
  #     @nfas << nfa
  #     if composite_nfa = @composite_nfa
  #       @composite_nfa = union(composite_nfa, nfa)
  #     else
  #       @composite_nfa = nfa
  #     end
  #     tag
  #   end

  #   def match?(input : String) : Set(Int32)?
  #     composite_dfa = (@composite_dfa ||= @composite_nfa.to_dfa)
  #     if composite_dfa
  #       match = composite_dfa.match?(input)
  #       match && match.tags
  #     end
  #   end
  # end

  # # FSA::Map allows you to insert Regex -> V pairs, and lookup values based on a search string
  # class Map(V)
  #   @map : Hash(Int32, V)
  #   @multi_fsa : MultiFSA

  #   def initialize()
  #     @map = Hash(Int32, V).new
  #     @multi_fsa = MultiFSA.new
  #   end

  #   def []=(nfa : NFA, value : V)
  #     tag = @multi_fsa.add(nfa)
  #     @map[tag] = value
  #   end

  #   # return an Array(V) representing the values corresponding to the regex matches that match the given `search_key`
  #   # if there are no matches, returns nil
  #   def [](search_key : String) : Array(V)?
  #     match = @multi_fsa.match?(search_key)
  #     match.tags.map {|tag| @map[tag] } if match
  #   end
  # end
end
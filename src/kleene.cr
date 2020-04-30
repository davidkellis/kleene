# this is a port and extension of https://github.com/davidkellis/fsm/

# Most of the machines constructed here are based
# on section 2.5 of the Ragel User Guide (http://www.complang.org/ragel/ragel-guide-6.6.pdf)

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
  DEFAULT_ALPHABET = ((' '..'~').map(&.to_s) + ["\n"] + ["\t"]).to_set

  module DSL
    ############### The following methods create FSAs given a stream of input tokens #################
    
    def literal(token_stream : String, alphabet = DEFAULT_ALPHABET)
      start = current_state = State.new
      nfa = NFA.new(start, [] of Transition, alphabet)
      token_stream.each_char do |token|
        next_state = State.new
        nfa.add_transition(token, current_state, next_state)
        current_state = next_state
      end
      current_state.final = true
      nfa.update_final_states
      nfa
    end
    
    def any(token_collection, alphabet = DEFAULT_ALPHABET)
      start = State.new
      nfa = NFA.new(start, [] of Transition, alphabet)
      final = State.new(true)
      token_collection.each {|token| nfa.add_transition(token, start, final) }
      nfa.update_final_states
      nfa
    end
    
    def dot(alphabet = DEFAULT_ALPHABET)
      any(alphabet)
    end
    
    # This implements a character class, and is specifically for use with matching strings
    def range(c_begin : Char, c_end : Char, alphabet = DEFAULT_ALPHABET)
      any((c_begin..c_end).to_a, alphabet)
    end
    
    ############### The following methods create FSAs given other FSAs #################
    
    # Append b onto a
    # Appending produces a machine that matches all the strings in machine a 
    # followed by all the strings in machine b.
    # This differs from concat in that the composite machine's final states are the union of machine a's final states
    # and machine b's final states.
    def append(a, b)
      a = a.deep_clone
      b = b.deep_clone
      
      # add an epsilon transition from each final state of machine a to the start state of maachine b.
      # then mark each of a's final states as not final
      a.final_states.each do |final_state|
        a.add_transition(Transition::Epsilon, final_state, b.start_state)
      end
      
      # add all of machine b's transitions to machine a
      b.transitions.each {|t| a.add_transition(t.token, t.from, t.to) }
      a.final_states = a.final_states | b.final_states
      a.alphabet = a.alphabet | b.alphabet
      
      a
    end
    
    # Concatenate b onto a
    # Concatenation produces a machine that matches all the strings in machine a 
    # followed by all the strings in machine b.
    # This differs from append in that the composite machine's final states are the set of final states
    # taken from machine b.
    def concat(a, b)
      a = a.deep_clone
      b = b.deep_clone
      
      # add an epsilon transition from each final state of machine a to the start state of maachine b.
      # then mark each of a's final states as not final
      a.final_states.each do |final_state|
        a.add_transition(Transition::Epsilon, final_state, b.start_state)
        final_state.final = false
      end
      
      # add all of machine b's transitions to machine a
      b.transitions.each {|t| a.add_transition(t.token, t.from, t.to) }
      a.final_states = b.final_states
      a.alphabet = a.alphabet | b.alphabet
      
      a
    end
    
    def union(a, b)
      a = a.deep_clone
      b = b.deep_clone
      start = State.new
      nfa = NFA.new(start, [] of Transition, a.alphabet | b.alphabet)
      
      # add epsilon transitions from the start state of the new machine to the start state of machines a and b
      nfa.add_transition(Transition::Epsilon, start, a.start_state)
      nfa.add_transition(Transition::Epsilon, start, b.start_state)
      
      # add all of a's and b's transitions to the new machine
      (a.transitions + b.transitions).each {|t| nfa.add_transition(t.token, t.from, t.to) }
      nfa.update_final_states
      
      nfa
    end
    
    def kleene(machine)
      machine = machine.deep_clone
      start = State.new
      final = State.new(true)
      
      nfa = NFA.new(start, [] of Transition, machine.alphabet)
      nfa.add_transition(Transition::Epsilon, start, final)
      nfa.add_transition(Transition::Epsilon, start, machine.start_state)
      machine.final_states.each do |final_state|
        nfa.add_transition(Transition::Epsilon, final_state, start)
        final_state.final = false
      end
      
      # add all of machine's transitions to the new machine
      (machine.transitions).each {|t| nfa.add_transition(t.token, t.from, t.to) }
      nfa.update_final_states
      
      nfa
    end
    
    def plus(machine)
      concat(machine, kleene(machine))
    end
    
    def optional(machine)
      union(machine, NFA.new(State.new(true), [] of Transition, machine.alphabet))
    end
    
    def repeat(machine, min, max = nil)
      max ||= min
      m = NFA.new(State.new(true), [] of Transition, machine.alphabet)
      min.times { m = concat(m, machine) }
      (max - min).times { m = append(m, machine) }
      m
    end
    
    def negate(machine)
      # difference(kleene(any(alphabet)), machine)
      machine = machine.to_dfa
      
      # invert the final flag of every state
      machine.states.each {|state| state.final = !state.final? }
      machine.update_final_states
      
      machine.to_nfa
    end
    
    # a - b == a && !b
    def difference(a, b)
      intersection(a, negate(b))
    end
    
    # By De Morgan's Law: !(!a || !b) = a && b
    def intersection(a, b)
      negate(union(negate(a), negate(b)))
    end
  end

  class NFA
    property alphabet : Set(Char)
    property states : Set(State)
    property start_state : State
    property transitions : Array(Transition)
    property final_states : Set(State)
    property tags : Set(Int32)
    
    def initialize(start_state, transitions = [] of Transition, alphabet = DEFAULT_ALPHABET, tags = Set(Int32).new)
      @start_state = start_state
      @transitions = transitions
      
      @alphabet = alphabet
      @alphabet.merge(@transitions.map(&.token))
      
      @states = reachable_states
      @final_states = Set(State).new

      @tags = tags || Set(Int32).new

      update_final_states
      reset_current_states
    end
    
    def deep_clone
      old_states = @states.to_a
      new_states = old_states.map(&.dup)
      state_mapping = old_states.zip(new_states).to_h
      new_transitions = @transitions.map {|t| Transition.new(t.token, state_mapping[t.from], state_mapping[t.to]) }
      
      NFA.new(state_mapping[@start_state], new_transitions, @alphabet.clone, @tags.clone)
    end

    def tag(tag : T)
      @states.each {|state| state.tag(tag) }
    end

    def tag(tags : Set(Int32))
      @states.each {|state| state.tag(tags) }
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
      t = Transition.new(token, from_state, to_state)
      @transitions << t
      t
    end
    
    def match?(input : String)
      reset_current_states
      
      input.each_char do |char|
        self << char
      end
      
      if accept?
        accept_state_tags = @current_states.select(&.final?).map(&.tags).reduce {|tag_set_accumulator, tag_set| tag_set_accumulator | tag_set }
        MatchRef.new(input, 0...input.size, accept_state_tags)
      end
    end
    
    # Returns an array of matches found in the input string, each of which begins at the offset input_start_offset
    def matches_at_offset(input, input_start_offset)
      reset_current_states

      matches = [] of MatchRef
      (input_start_offset...input.length).each do |offset|
        token = input[offset]
        self << token
        if accept?
          accept_state_tags = @current_states.select(&.final?).map(&.tags).reduce {|tag_set_accumulator, tag_set| tag_set_accumulator | tag_set }
          matches << MatchRef.new(input, input_start_offset..offset, accept_state_tags)
        end
      end
      matches
    end
    
    # Returns an array of matches found anywhere in the input string
    def matches(input)
      (0...input.length).reduce([] of MatchRef) do |memo, offset|
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
      outbound_transitions = @transitions.select {|t| epsilon_reachable_states.include?(t.from) && t.accept?(input_token) }
      
      # Build an array of epsilon-closures of each transition's destination state.
      destination_state_epsilon_closures = outbound_transitions.map { |t| epsilon_closure([t.to]) }
      
      # Union each of the epsilon-closures (each is an array) together to form a flat array of states in the epsilon-closure of all of our current states.
      next_states = destination_state_epsilon_closures.reduce { |combined_state_set, individual_state_set| combined_state_set.merge(individual_state_set) }
      
      next_states || Set.new
    end

    # Determine the epsilon closure of the given state set
    # That is, determine what states are reachable on an epsilon transition from the current state set (@current_states).
    # Returns a Set of State objects.
    def epsilon_closure(state_set)
      visited_states = Set.new()
      unvisited_states = state_set
      while !unvisited_states.empty?
        epsilon_transitions = @transitions.select { |t| t.accept?(Transition::Epsilon) && unvisited_states.include?(t.from) }
        destination_states = epsilon_transitions.map(&.to).to_set
        visited_states.merge(unvisited_states)         # add the unvisited states to the visited_states
        unvisited_states = destination_states - visited_states
      end
      visited_states
    end
    
    # Returns a set of State objects which are reachable through any transition path from the NFA's start_state.
    def reachable_states
      visited_states = Set(State).new()
      unvisited_states = Set[@start_state]
      while !unvisited_states.empty?
        outbound_transitions = @transitions.select { |t| unvisited_states.include?(t.from) }
        destination_states = outbound_transitions.map(&.to).to_set
        visited_states.merge(unvisited_states)         # add the unvisited states to the visited_states
        unvisited_states = destination_states - visited_states
      end
      visited_states
    end

    # This implements the subset construction algorithm presented on page 118 of the first edition of the dragon book.
    # I found a similar explanation at: http://web.cecs.pdx.edu/~harry/compilers/slides/LexicalPart3.pdf
    def to_dfa
      state_map = Hash.new            # this map contains nfa_state_set => dfa_state pairs
      dfa_transitions = [] of Transition
      dfa_alphabet = @alphabet - Set{Transition::Epsilon}
      visited_state_sets = Set.new()
      nfa_start_state_set = epsilon_closure([@start_state])
      unvisited_state_sets = Set[nfa_start_state_set]
      until unvisited_state_sets.empty?
        # take one of the unvisited state sets
        state_set = unvisited_state_sets.first
        unvisited_state_sets.delete(state_set)

        # this new DFA state, new_dfa_state, represents the nfa state set, state_set
        new_dfa_state = State.new(state_set.any?(&.final?))
        
        # add the mapping from nfa state set => dfa state
        state_map[state_set] = new_dfa_state
        
        # Figure out the set of next-states for each token in the alphabet
        # Add each set of next-states to unvisited_state_sets
        dfa_alphabet.each do |token|
          next_nfa_state_set = next_states(state_set, token)
          unvisited_state_sets << next_nfa_state_set
          # add a transition from new_dfa_state -> next_nfa_state_set
          # next_nfa_state_set is a placeholder that I'll go back and replace with the corresponding dfa_state
          # I don't insert the dfa_state yet, because it hasn't been created yet
          dfa_transitions << Transition.new(token, new_dfa_state, next_nfa_state_set)
        end
        
        visited_state_sets << state_set
        unvisited_state_sets = unvisited_state_sets - visited_state_sets
      end
      
      # replace the nfa_state_set currently stored in each transition's "to" field with the
      # corresponding dfa state.
      dfa_transitions.each {|transition| transition.to = state_map[transition.to] }
      
      DFA.new(state_map[nfa_start_state_set], dfa_transitions, dfa_alphabet, @tags.clone)
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
    property tags : Set(Int32)

    def initialize(final = false, id : Int32? = nil, tags = Set(Int32).new)
      @id = id || State.next_id
      @final = final
      @tags = tags
    end

    def tag(tag)
      @tags << tag
    end

    def tag(tags : Set(Int32))
      @tags |= tags
    end


    def final?
      @final
    end
    
    def dup
      State.new(@final, nil, tags)
    end
  end

  class Transition
    Epsilon = :epsilon
    
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
    property tags : Set(Int32)

    def initialize(original_string, match_range, tags)
      @string = original_string
      @range = match_range
      @tags = tags
    end
    
    def match
      @string[@range]
    end
    
    def to_s
      match.to_s
    end
    
    def ==(other)
      @string == other.string &&
      @range == other.range &&
      @tags == other.tags
    end
    
    def eql?(other)
      self == other
    end
  end

  class DFA
    property alphabet : Set(Char)
    property states : Set(State)
    property start_state : State
    property transitions : Array(Transition)
    property final_states : Set(State)
    property tags : Set(Int32)
    
    def initialize(start_state, transitions = [] of Transition, alphabet = DEFAULT_ALPHABET, tags = Set(Int32).new)
      @start_state = start_state
      @transitions = transitions
      
      @alphabet = alphabet
      @alphabet.merge(@transitions.map(&.token))
      
      @states = reachable_states
      @final_states = Set(State).new

      @tags = tags || Set(Int32).new

      update_final_states
      reset_current_state
    end
    
    def deep_clone
      old_states = @states.to_a
      new_states = old_states.map(&.dup)
      state_mapping = old_states.zip(new_states).to_h
      new_transitions = @transitions.map {|t| Transition.new(t.token, state_mapping[t.from], state_mapping[t.to]) }
      
      DFA.new(state_mapping[@start_state], new_transitions, @alphabet.clone, @tags.clone)
    end

    def tag(tag : T)
      @states.each {|state| state.tag(tag) }
    end

    def tag(tags : Set(Int32))
      @states.each {|state| state.tag(tags) }
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
      t = Transition.new(token, from_state, to_state)
      @transitions << t
      t
    end
    
    def match?(input : String)
      reset_current_state
      
      input.each_char do |char|
        self << char
      end
      
      if accept?
        accept_state_tags = @current_state.tags
        MatchRef.new(input, 0...input.size, accept_state_tags)
      end
    end
    
    # Returns an array of matches found in the input string, each of which begins at the offset input_start_offset
    def matches_at_offset(input, input_start_offset)
      reset_current_state

      matches = [] of MatchRef
      (input_start_offset...input.length).each do |offset|
        token = input[offset]
        self << token
        if accept?
          accept_state_tags = @current_state.tags
          matches << MatchRef.new(input, input_start_offset..offset, accept_state_tags)
        end
      end
      matches
    end
    
    # Returns an array of matches found anywhere in the input string
    def matches(input)
      (0...input.length).reduce([] of MatchRef) do |memo, offset|
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
    
    def next_state(state, input_token)
      t = @transitions.find {|t| state == t.from && t.accept?(input_token) }
      t.to
    end

    # Returns a set of State objects which are reachable through any transition path from the NFA's start_state.
    def reachable_states
      visited_states = Set(State).new()
      unvisited_states = Set[@start_state]
      while !unvisited_states.empty?
        outbound_transitions = @transitions.select { |t| unvisited_states.include?(t.from) }
        destination_states = outbound_transitions.map(&.to).to_set
        visited_states.merge(unvisited_states)         # add the unvisited states to the visited_states
        unvisited_states = destination_states - visited_states
      end
      visited_states
    end
    
    def to_nfa
      dfa = self.deep_clone
      NFA.new(dfa.start_state, dfa.transitions, dfa.alphabet.clone, @tags.clone)
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

  class MultiFSA
    @nfas : Array(NFA)
    @composite_nfa : NFA?
    @composite_dfa : DFA?

    include DSL
    
    def initialize(nfas = nil)
      @nfas = nfas || [] of NFA
      @composite_nfa = nil
      @composite_dfa = nil
    end

    # returns the tag identifying the newly added nfa
    def add(nfa)
      @composite_dfa = nil    # invalidate memoized dfa

      tag = @nfas.size
      nfa = nfa.deep_clone
      nfa.tag(tag)
      @nfas << nfa
      if composite_nfa = @composite_nfa
        @composite_nfa = union(composite_nfa, nfa)
      else
        @composite_nfa = nfa
      end
      tag
    end

    def match?(input : String) : Set(Int32)?
      composite_dfa = (@composite_dfa ||= @composite_nfa.to_dfa)
      if composite_dfa
        match = composite_dfa.match?(input)
        match && match.tags
      end
    end
  end

  # FSA::Map allows you to insert Regex -> V pairs, and lookup values based on a search string
  class Map(V)
    @map : Hash(Int32, V)
    @multi_fsa : MultiFSA

    def initialize()
      @map = Hash(Int32, V).new
      @multi_fsa = MultiFSA.new
    end

    def []=(nfa : NFA, value : V)
      tag = @multi_fsa.add(nfa)
      @map[tag] = value
    end

    # return an Array(V) representing the values corresponding to the regex matches that match the given `search_key`
    # if there are no matches, returns nil
    def [](search_key : String) : Array(V)?
      match = @multi_fsa.match?(search_key)
      match.tags.map {|tag| @map[tag] } if match
    end
  end
end
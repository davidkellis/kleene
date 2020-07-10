# Most of the machines constructed here are based on section 2.5 of the Ragel User Guide (http://www.colm.net/files/ragel/ragel-guide-6.10.pdf)

module Kleene
  module DSL
    extend self

    ############### The following methods create FSAs given a stream of input tokens #################
    
    # given a string with N characters in it:
    # N+1 states: start state and N other states
    # structure: start state -> transition for first character in the string -> state for having observed first character in the string -> 
    #                           transition for second character in the string -> state for having observed second character in the string -> 
    #                           ...
    #                           transition for last character in the string -> state for having observed last character in the string (marked final)
    def literal(token_stream : String, alphabet = DEFAULT_ALPHABET)
      start = current_state = State.new
      nfa = NFA.new(start, alphabet)
      token_stream.each_char do |token|
        next_state = State.new
        nfa.add_transition(token, current_state, next_state)
        current_state = next_state
      end
      current_state.final = true
      nfa.update_final_states
      nfa
    end
    
    # two states: start state and final state
    # structure: start state -> transitions for each token in the token collection -> final state
    def any(token_collection, alphabet = DEFAULT_ALPHABET)
      start = State.new
      nfa = NFA.new(start, alphabet)
      final = State.new(true)
      token_collection.each {|token| nfa.add_transition(token, start, final) }
      nfa.update_final_states
      nfa
    end

    # two states: start state and final state
    # structure: start state -> transitions for every token in the alphabet -> final state
    def dot(alphabet = DEFAULT_ALPHABET)
      any(alphabet)
    end
    
    # This implements a character class, and is specifically for use with matching strings
    def range(c_begin : Char, c_end : Char, alphabet = DEFAULT_ALPHABET)
      any((c_begin..c_end).to_a, alphabet)
    end
    
    ############### The following methods create FSAs given other FSAs #################
    
    # always clones the given nfa and returns a new nfa with a non-final error state
    def with_err(nfa, alphabet = nfa.alphabet)
      with_err!(nfa.deep_clone, alphabet)
    end

    def with_err!(nfa, alphabet = nfa.alphabet)
      error_state = nfa.find(&.error?)
      return nfa if error_state

      error_state = State.new_error_state
      nfa.add_state(error_state)

      nfa.states.each do |state|
        tokens_on_outbound_transitions = nfa.transitions_from(state).map(&.token)
        missing_tokens = alphabet - tokens_on_outbound_transitions
        missing_tokens.each do |token|
          nfa.add_transition(token, state, error_state)
        end
      end

      nfa.remove_state(error_state) if nfa.all_transitions.none? {|transition| transition.from == error_state || transition.to == error_state }
      
      nfa
    end

    # Append b onto a
    # Appending produces a machine that matches all the strings in machine a followed by all the strings in machine b.
    # This differs from `seq` in that the composite machine's final states are the union of machine a's final states and machine b's final states.
    def append(a, b)
      a = a.deep_clone
      b = b.deep_clone
      append!(a, b)
    end

    # Destructively append b onto a
    # Appending produces a machine that matches all the strings in machine a followed by all the strings in machine b.
    # This differs from `seq` in that the composite machine's final states are the union of machine a's final states and machine b's final states.
    def append!(a, b)
      a.alphabet = a.alphabet | b.alphabet

      # add an epsilon transition from each final state of machine a to the start state of maachine b.
      a.final_states.each do |final_state|
        a.add_transition(NFATransition::Epsilon, final_state, b.start_state)
      end
      
      # add all of machine b's transitions to machine a
      b.all_transitions.each {|transition| a.add_transition(transition.token, transition.from, transition.to) }
      # a.final_states = a.final_states | b.final_states
      a.update_final_states
      
      a
    end
    
    def seq(*nfa_splat_tuple)
      seq(nfa_splat_tuple.to_a)
    end

    def seq(nfas : Array(NFA))
      nfas.reduce {|memo_nfa, nfa| seq(memo_nfa, nfa) }
    end

    # Implements concatenation, as defined in the Ragel manual in section 2.5.5 of http://www.colm.net/files/ragel/ragel-guide-6.10.pdf:
    # Seq produces a machine that matches all the strings in machine `a` followed by all the strings in machine `b`.
    # Seq draws epsilon transitions from the final states of thefirst machine to the start state of the second machine.
    # The final states of the first machine lose their final state status, unless the start state of the second machine is final as well.
    def seq(a : NFA, b : NFA)
      a = a.deep_clone
      b = b.deep_clone
      
      a = append!(a, b)
      
      # make sure that b's final states are the only final states in a after we have appended b onto a
      a.states.each {|state| state.final = b.final_states.includes?(state) }
      a.update_final_states
      
      a
    end

    def union(*nfa_splat_tuple)
      union(nfa_splat_tuple.to_a)
    end

    # Build a new machine consisting of a new start state with epsilon transitions to the start state of all the given NFAs in `nfas`.
    # The resulting machine's final states are the set of final states from all the NFAs in `nfas`.
    #
    # Implements Union, as defined in the Ragel manual in section 2.5.1 of http://www.colm.net/files/ragel/ragel-guide-6.10.pdf:
    # The union operation produces a machine that matches any string in machine one or machine two.
    # The operation first creates a new start state.
    # Epsilon transitions are drawn from the new start state to the start states of both input machines.
    # The resulting machine has a final state setequivalent to the union of the final state sets of both input machines.
    def union(nfas : Array(NFA))
      nfas = nfas.map(&.deep_clone)
      union!(nfas)
    end

    # same as union, but doesn't deep clone the constituent nfas
    def union!(nfas : Array(NFA))
      start = State.new
      composite_alphabet = nfas.map(&.alphabet).reduce {|memo, alphabet| memo | alphabet }
      new_nfa = NFA.new(start, composite_alphabet)
      
      # add epsilon transitions from the start state of the new machine to the start state of machines a and b
      nfas.each do |nfa|
        new_nfa.add_states(nfa.states)
        new_nfa.add_transition(NFATransition::Epsilon, start, nfa.start_state)
        nfa.all_transitions.each {|t| new_nfa.add_transition(t.token, t.from, t.to) }
      end
      
      new_nfa.update_final_states
      
      new_nfa
    end
    
    # Implements Kleene Star, as defined in the Ragel manual in section 2.5.6 of http://www.colm.net/files/ragel/ragel-guide-6.10.pdf:
    # The machine resulting from the Kleene Star operator will match zero or more repetitions of the machine it is applied to.
    # It creates a new start state and an additional final state.
    # Epsilon transitions are drawn between the new start state and the old start state, 
    # between the new start state and the new final state, and between the final states of the machine and the new start state.
    def kleene(machine)
      machine = machine.deep_clone
      start = State.new
      final = State.new(true)
      
      nfa = NFA.new(start, machine.alphabet)
      nfa.add_states(machine.states)
      nfa.add_transition(NFATransition::Epsilon, start, final)
      nfa.add_transition(NFATransition::Epsilon, start, machine.start_state)
      machine.final_states.each do |final_state|
        nfa.add_transition(NFATransition::Epsilon, final_state, start)
        final_state.final = false
      end
      
      # add all of machine's transitions to the new machine
      (machine.all_transitions).each {|t| nfa.add_transition(t.token, t.from, t.to) }
      nfa.update_final_states
      
      nfa
    end
    
    def plus(machine)
      seq(machine, kleene(machine))
    end
    
    def optional(machine)
      union(machine, NFA.new(State.new(true), machine.alphabet))
    end
    
    def repeat(machine, min, max = nil)
      max ||= min
      m = NFA.new(State.new(true), machine.alphabet)
      min.times { m = seq(m, machine) }
      (max - min).times { m = append(m, machine) }
      m
    end
    
    def negate(machine)
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
end
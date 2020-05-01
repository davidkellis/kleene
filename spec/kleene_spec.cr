require "./spec_helper"

describe Kleene do
  describe "nfa" do
    it "works" do
      # create some states with which to manually construct an NFA
      start = Kleene::State.new
      a = Kleene::State.new
      b1 = Kleene::State.new
      b2 = Kleene::State.new
      c = Kleene::State.new(true)
    
      # build an NFA to match "abbc"
      nfa = Kleene::NFA.new(start)
      nfa.add_transition('a', start, a)
      nfa.add_transition('b', a, b1)
      nfa.add_transition('b', b1, b2)
      nfa.add_transition('c', b2, c)
    
      # run the NFA
      nfa.match?("abc").should be_nil
      nfa.match?("").should be_nil
      nfa.match?("abbcc").should be_nil
      nfa.match?("abbc").should be_truthy


      # build an NFA to match "abb?c"
      nfa = Kleene::NFA.new(start)
      nfa.add_transition('a', start, a)
      nfa.add_transition('b', a, b1)
      nfa.add_transition(Kleene::NFATransition::Epsilon, a, b1)
      nfa.add_transition('b', b1, b2)
      nfa.add_transition('c', b2, c)
    
      # run the NFA
      nfa.match?("abc").should be_truthy
      nfa.match?("").should be_nil
      nfa.match?("abbcc").should be_nil
      nfa.match?("abbc").should be_truthy
      
      matches = nfa.matches("abcdefg,abcdefg,abbcdefg,abbbcdefg")
      matches.size.should eq 3
      matches[0].should_not eq matches[1]
      matches[0].match.should eq matches[1].match
      matches[0].range.should eq (0..2)
      matches[1].range.should eq (8..10)
      matches[2].range.should eq (16..19)
      matches[0].match.should eq "abc"
      matches[1].match.should eq "abc"
      matches[2].match.should eq "abbc"
    end
  end

  describe "dfa" do
    it "works" do
      # create some states with which to manually construct an NFA and a DFA
      start = Kleene::State.new
      a = Kleene::State.new
      b1 = Kleene::State.new
      b2 = Kleene::State.new
      c = Kleene::State.new(true)
    
      # build a DFA to match "abbc"
      nfa = Kleene::NFA.new(start)
      nfa.add_transition('a', start, a)
      nfa.add_transition('b', a, b1)
      nfa.add_transition('b', b1, b2)
      nfa.add_transition('c', b2, c)
      dfa = nfa.to_dfa
    
      # run the DFA
      dfa.match?("abc").should be_nil
      dfa.match?("").should be_nil
      dfa.match?("abbcc").should be_nil
      dfa.match?("abbc").should be_truthy
      

      # build a DFA to match "abb?c"
      nfa = Kleene::NFA.new(start)
      nfa.add_transition('a', start, a)
      nfa.add_transition('b', a, b1)
      nfa.add_transition(Kleene::NFATransition::Epsilon, a, b1)
      nfa.add_transition('b', b1, b2)
      nfa.add_transition('c', b2, c)
      dfa = nfa.to_dfa

      # run the DFA
      dfa.match?("abc").should be_truthy
      dfa.match?("").should be_nil
      dfa.match?("abbcc").should be_nil
      dfa.match?("abbc").should be_truthy
      
      matches = dfa.matches("abcdefg,abcdefg,abbcdefg,abbbcdefg")
      matches.size.should eq 3
      matches[0].should_not eq matches[1]
      matches[0].match.should eq matches[1].match
      matches[0].range.should eq (0..2)
      matches[1].range.should eq (8..10)
      matches[2].range.should eq (16..19)
      matches[0].match.should eq "abc"
      matches[1].match.should eq "abc"
      matches[2].match.should eq "abbc"
    end
  end
end

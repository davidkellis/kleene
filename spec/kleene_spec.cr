require "./spec_helper"

describe Kleene do
  describe "nfa" do
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
    nfa.match?("abc").should be_false
    nfa.match?("").should be_false
    nfa.match?("abbcc").should be_false
    nfa.match?("abbc").should be_true

    # build an NFA to match "abb?c"
    nfa = Kleene::NFA.new(start)
    nfa.add_transition('a', start, a)
    nfa.add_transition('b', a, b1)
    nfa.add_transition(:epsilon, a, b1)
    nfa.add_transition('b', b1, b2)
    nfa.add_transition('c', b2, c)
  
    # run the NFA
    nfa.match?("abc").should be_true
    nfa.match?("").should be_false
    nfa.match?("abbcc").should be_false
    nfa.match?("abbc").should be_true
    
    matches = nfa.matches("abcdefg,abcdefg,abbcdefg,abbbcdefg")
    matches.count.should eq 3
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

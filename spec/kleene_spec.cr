require "./spec_helper"

include Kleene
include DSL

describe Kleene do
  describe "nfa" do
    it "matches string literals" do
      # /abbc/
      nfa = literal("abbc")
      nfa.match?("abc").should be_nil
      nfa.match?("").should be_nil
      nfa.match?("abbcc").should be_nil
      nfa.match?("abbc").should be_truthy
    end

    it "matches sequences of string literals" do
      # /(a)(b)/
      nfa = seq(literal("a"), literal("b"))
      nfa.match?("a").should be_nil
      nfa.match?("ab").should be_truthy
      nfa.match?("abc").should be_nil
      nfa.match?("").should be_nil
      nfa.match?("abbcc").should be_nil
    end

    it "matches unions of string literals" do
      # /a|b/
      nfa = union(literal("a"), literal("b"))
      nfa.match?("a").should be_truthy
      nfa.match?("b").should be_truthy
      nfa.match?("c").should be_nil
      nfa.match?("").should be_nil
    end

    it "matches sequences of string literals and unions" do
      # /abb?c/
      nfa = seq(literal("ab"), optional(literal("b")), literal("c"))
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

    it "matches kleene start operator" do
      # /ab*c/
      nfa = seq(literal("a"), kleene(literal("b")), literal("c"))
      nfa.match?("a").should be_nil
      nfa.match?("b").should be_nil
      nfa.match?("c").should be_nil
      nfa.match?("").should be_nil
      nfa.match?("aa").should be_nil
      nfa.match?("ab").should be_nil
      nfa.match?("ac").should be_truthy
      nfa.match?("abc").should be_truthy
      nfa.match?("abbc").should be_truthy
      nfa.match?("abbbbbbbbbbbbbbbbbbbbbbbbc").should be_truthy
      nfa.match?("bc").should be_nil
      nfa.match?("bbbbc").should be_nil
    end
  end

  describe "dfa" do
    it "matches string literals" do
      # /abbc/
      nfa = literal("abbc")
      dfa = nfa.to_dfa
      dfa.match?("abc").should be_nil
      dfa.match?("").should be_nil
      dfa.match?("abbcc").should be_nil
      dfa.match?("abbc").should be_truthy
    end

    it "matches sequences of string literals" do
      # /(a)(b)/
      nfa = seq(literal("a"), literal("b"))
      dfa = nfa.to_dfa
      dfa.match?("a").should be_nil
      dfa.match?("ab").should be_truthy
      dfa.match?("abc").should be_nil
      dfa.match?("").should be_nil
      dfa.match?("abbcc").should be_nil
    end

    it "matches unions of string literals" do
      # /a|b/
      nfa = union(literal("a"), literal("b"))
      dfa = nfa.to_dfa
      dfa.match?("a").should be_truthy
      dfa.match?("b").should be_truthy
      dfa.match?("c").should be_nil
      dfa.match?("").should be_nil
    end

    it "matches sequences of string literals and unions" do
      # /abb?c/
      nfa = seq(literal("ab"), optional(literal("b")), literal("c"))
      dfa = nfa.to_dfa
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

    it "matches kleene start operator" do
      # /ab*c/
      nfa = seq(literal("a"), kleene(literal("b")), literal("c"))
      dfa = nfa.to_dfa
      dfa.match?("a").should be_nil
      dfa.match?("b").should be_nil
      dfa.match?("c").should be_nil
      dfa.match?("").should be_nil
      dfa.match?("aa").should be_nil
      dfa.match?("ab").should be_nil
      dfa.match?("ac").should be_truthy
      dfa.match?("abc").should be_truthy
      dfa.match?("abbc").should be_truthy
      dfa.match?("abbbbbbbbbbbbbbbbbbbbbbbbc").should be_truthy
      dfa.match?("bc").should be_nil
      dfa.match?("bbbbc").should be_nil
    end
  end

end

describe "MultiMatchDFA" do
  it "works" do
    alphabet = Kleene::DEFAULT_ALPHABET   # Set{'a', 'b', 'z'}
    a_dot = seq(literal("a", alphabet), dot(alphabet))   # /a./
    dot_b = seq(dot(alphabet), literal("b", alphabet))   # /.b/
    mmdfa = MultiMatchDFA.new([a_dot, dot_b])

    mt = mmdfa.match_tracker("abzbazaaabzbzbbbb")
    mt.candidate_match_start_positions.should eq({
      mmdfa.nfas_with_err_state[0] => [0, 4, 6, 7, 8],                                              # mmdfa.nfas_with_err_state[0] is just a_dot with a dead end error state
      mmdfa.nfas_with_err_state[1] => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]    # mmdfa.nfas_with_err_state[1] is just dot_b with a dead end error state
    })
    mt.match_end_positions.should eq({
      mmdfa.nfas_with_err_state[0] => [1, 5, 7, 8, 9],                   # mmdfa.nfas_with_err_state[0] is just a_dot with a dead end error state
      mmdfa.nfas_with_err_state[1] => [1, 3, 9, 11, 13, 14, 15, 16]      # mmdfa.nfas_with_err_state[1] is just dot_b with a dead end error state
    })

    input_string = "abzbazaaabzbzbbbb"
    mmdfa.matches(input_string).should eq({
      a_dot => [
        MatchRef.new(input_string, 0..1),
        MatchRef.new(input_string, 4..5),
        MatchRef.new(input_string, 6..7),
        MatchRef.new(input_string, 7..8),
        MatchRef.new(input_string, 8..9)
      ],
      dot_b => [
        MatchRef.new(input_string, 0..1),
        MatchRef.new(input_string, 2..3),
        MatchRef.new(input_string, 8..9),
        MatchRef.new(input_string, 10..11),
        MatchRef.new(input_string, 12..13),
        MatchRef.new(input_string, 13..14),
        MatchRef.new(input_string, 14..15),
        MatchRef.new(input_string, 15..16)
      ]
    })
  end
end

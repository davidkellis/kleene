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
      matches[0].text.should eq matches[1].text
      matches[0].range.should eq (0..2)
      matches[1].range.should eq (8..10)
      matches[2].range.should eq (16..19)
      matches[0].text.should eq "abc"
      matches[1].text.should eq "abc"
      matches[2].text.should eq "abbc"
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
      matches[0].text.should eq matches[1].text
      matches[0].range.should eq (0..2)
      matches[1].range.should eq (8..10)
      matches[2].range.should eq (16..19)
      matches[0].text.should eq "abc"
      matches[1].text.should eq "abc"
      matches[2].text.should eq "abbc"
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

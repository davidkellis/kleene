require "./spec_helper"

include Kleene
include DSL
include LexerDSL

describe Lexer do
  describe "#match" do
    it "works" do
      ident = Token.new("ident", alphanumeric )   # ident -> /[a-zA-Z0-9]+/
      int = Token.new("int", numeric )            # int -> /[0-9]+/
      lexer = Lexer.new([ident, int])

      input_string = "123abc456"
      # lexer.tokenize(input_string).each {|lexeme| puts "#{lexeme}" }
      lexer.tokenize(input_string).should eq([
        Lexeme.new(int, MatchRef.new(input_string, 0..0)),
        Lexeme.new(int, MatchRef.new(input_string, 0..1)),
        Lexeme.new(int, MatchRef.new(input_string, 1..1)),
        Lexeme.new(int, MatchRef.new(input_string, 0..2)),
        Lexeme.new(int, MatchRef.new(input_string, 1..2)),
        Lexeme.new(int, MatchRef.new(input_string, 2..2)),
        Lexeme.new(int, MatchRef.new(input_string, 6..6)),
        Lexeme.new(int, MatchRef.new(input_string, 6..7)),
        Lexeme.new(int, MatchRef.new(input_string, 7..7)),
        Lexeme.new(int, MatchRef.new(input_string, 6..8)),
        Lexeme.new(int, MatchRef.new(input_string, 7..8)),
        Lexeme.new(int, MatchRef.new(input_string, 8..8)),
        Lexeme.new(ident, MatchRef.new(input_string, 0..0)),
        Lexeme.new(ident, MatchRef.new(input_string, 0..1)),
        Lexeme.new(ident, MatchRef.new(input_string, 1..1)),
        Lexeme.new(ident, MatchRef.new(input_string, 0..2)),
        Lexeme.new(ident, MatchRef.new(input_string, 1..2)),
        Lexeme.new(ident, MatchRef.new(input_string, 2..2)),
        Lexeme.new(ident, MatchRef.new(input_string, 0..3)),
        Lexeme.new(ident, MatchRef.new(input_string, 1..3)),
        Lexeme.new(ident, MatchRef.new(input_string, 2..3)),
        Lexeme.new(ident, MatchRef.new(input_string, 3..3)),
        Lexeme.new(ident, MatchRef.new(input_string, 0..4)),
        Lexeme.new(ident, MatchRef.new(input_string, 1..4)),
        Lexeme.new(ident, MatchRef.new(input_string, 2..4)),
        Lexeme.new(ident, MatchRef.new(input_string, 3..4)),
        Lexeme.new(ident, MatchRef.new(input_string, 4..4)),
        Lexeme.new(ident, MatchRef.new(input_string, 0..5)),
        Lexeme.new(ident, MatchRef.new(input_string, 1..5)),
        Lexeme.new(ident, MatchRef.new(input_string, 2..5)),
        Lexeme.new(ident, MatchRef.new(input_string, 3..5)),
        Lexeme.new(ident, MatchRef.new(input_string, 4..5)),
        Lexeme.new(ident, MatchRef.new(input_string, 5..5)),
        Lexeme.new(ident, MatchRef.new(input_string, 0..6)),
        Lexeme.new(ident, MatchRef.new(input_string, 1..6)),
        Lexeme.new(ident, MatchRef.new(input_string, 2..6)),
        Lexeme.new(ident, MatchRef.new(input_string, 3..6)),
        Lexeme.new(ident, MatchRef.new(input_string, 4..6)),
        Lexeme.new(ident, MatchRef.new(input_string, 5..6)),
        Lexeme.new(ident, MatchRef.new(input_string, 6..6)),
        Lexeme.new(ident, MatchRef.new(input_string, 0..7)),
        Lexeme.new(ident, MatchRef.new(input_string, 1..7)),
        Lexeme.new(ident, MatchRef.new(input_string, 2..7)),
        Lexeme.new(ident, MatchRef.new(input_string, 3..7)),
        Lexeme.new(ident, MatchRef.new(input_string, 4..7)),
        Lexeme.new(ident, MatchRef.new(input_string, 5..7)),
        Lexeme.new(ident, MatchRef.new(input_string, 6..7)),
        Lexeme.new(ident, MatchRef.new(input_string, 7..7)),
        Lexeme.new(ident, MatchRef.new(input_string, 0..8)),
        Lexeme.new(ident, MatchRef.new(input_string, 1..8)),
        Lexeme.new(ident, MatchRef.new(input_string, 2..8)),
        Lexeme.new(ident, MatchRef.new(input_string, 3..8)),
        Lexeme.new(ident, MatchRef.new(input_string, 4..8)),
        Lexeme.new(ident, MatchRef.new(input_string, 5..8)),
        Lexeme.new(ident, MatchRef.new(input_string, 6..8)),
        Lexeme.new(ident, MatchRef.new(input_string, 7..8)),
        Lexeme.new(ident, MatchRef.new(input_string, 8..8))
      ])
    end
  end
end

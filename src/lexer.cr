require "./kleene.cr"
require "./multi_match_dfa.cr"

module Kleene
  class Token
    property name : String
    property pattern : NFA

    def initialize(@name, @pattern)
    end

    def ==(other : Token)
      @name == other.name &&
      @pattern == other.pattern
    end
    
    def eql?(other : Token)
      self == other
    end

    def to_s
      "Token(name=#{name}, pattern=NFA@#{pattern.object_id})"
    end
  end

  class Lexeme
    property token : Token
    property match : MatchRef
    
    def initialize(@token, @match)
    end

    def text
      match.text
    end

    def ==(other : Lexeme)
      @token == other.token &&
      @match == other.match
    end
    
    def eql?(other : Lexeme)
      self == other
    end

    def to_s
      "Lexeme(token=#{token.name}, match=#{match.range})"
    end
  end

  module LexerDSL
    include DSL

    def alpha
      plus(union(range('a', 'z'), range('A', 'Z')))
    end

    def numeric
      plus(range('0', '9'))
    end

    def letter
      plus(union(range('a', 'z'), range('A', 'Z'), literal("_")))
    end

    def alphanumeric
      plus(union(range('a', 'z'), range('A', 'Z'), range('0', '9')))
    end
  end

  class Lexer
    property mmdfa : MultiMatchDFA
    @nfa_to_token : Hash(NFA, Token)

    def initialize(tokens : Array(Token))
      nfas = tokens.map(&.pattern)
      @nfa_to_token = nfas.zip(tokens).to_h

      @mmdfa = MultiMatchDFA.new(nfas)
    end

    def tokenize(input : String) : Array(Lexeme)
      matches = mmdfa.matches(input)
      matches.reduce(Array(Lexeme).new) do |memo, nfa_match_refs_pair|
        nfa, match_refs = nfa_match_refs_pair
        lexemes = match_refs.map {|match_ref| Lexeme.new(@nfa_to_token[nfa], match_ref) }
        memo.concat(lexemes)
      end
    end

  end
end

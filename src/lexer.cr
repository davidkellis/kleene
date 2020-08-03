require "./kleene.cr"
require "./multi_match_dfa.cr"

module Kleene
  class Token
    property name : String
    property pattern : NFA

    def initialize(@name, @pattern)
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

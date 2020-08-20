require "./spec_helper"

include Kleene
include DSL

describe "MultiMatchDFA" do
  it "matches /a.|.b/" do
    alphabet = Kleene::DEFAULT_ALPHABET   # Set{'a', 'b', 'z'}
    a_dot = seq(literal("a", alphabet), dot(alphabet))   # /a./
    dot_b = seq(dot(alphabet), literal("b", alphabet))   # /.b/
    mmdfa = MultiMatchDFA.new([a_dot, dot_b])

    input_string = "abzbazaaabzbzbbbb"

    mt = mmdfa.match_tracker(input_string)
    mt.candidate_match_start_positions.should eq({
      mmdfa.nfas_with_err_state[0] => [0, 4, 6, 7, 8],                                              # mmdfa.nfas_with_err_state[0] is just a_dot with a dead end error state
      mmdfa.nfas_with_err_state[1] => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]    # mmdfa.nfas_with_err_state[1] is just dot_b with a dead end error state
    })
    mt.match_end_positions.should eq({
      mmdfa.nfas_with_err_state[0] => [1, 5, 7, 8, 9],                   # mmdfa.nfas_with_err_state[0] is just a_dot with a dead end error state
      mmdfa.nfas_with_err_state[1] => [1, 3, 9, 11, 13, 14, 15, 16]      # mmdfa.nfas_with_err_state[1] is just dot_b with a dead end error state
    })

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

  it "matches /a*/" do
    alphabet = Set{'a', 'b', 'z'}
    a_star = kleene(literal("a", alphabet))
    mmdfa = MultiMatchDFA.new([a_star])

    input_string = "abaabaaa"

    mt = mmdfa.match_tracker(input_string)
    mt.candidate_match_start_positions.should eq({
      mmdfa.nfas_with_err_state[0] => [0, 1, 2, 3, 4, 5, 6, 7]           # mmdfa.nfas_with_err_state[0] is just a_star with a dead end error state
    })
    mt.match_end_positions.should eq({
      mmdfa.nfas_with_err_state[0] => [0, 1, 2, 3, 4, 5, 6, 7]           # mmdfa.nfas_with_err_state[0] is just a_star with a dead end error state
    })

    mmdfa.matches(input_string).should eq({
      a_star => [
        MatchRef.new(input_string, 0...0),
        MatchRef.new(input_string, 1...1),
        MatchRef.new(input_string, 2...2),
        MatchRef.new(input_string, 3...3),
        MatchRef.new(input_string, 4...4),
        MatchRef.new(input_string, 5...5),
        MatchRef.new(input_string, 6...6),
        MatchRef.new(input_string, 7...7),
        MatchRef.new(input_string, 0..0),
        MatchRef.new(input_string, 2..2),
        MatchRef.new(input_string, 2..3),
        MatchRef.new(input_string, 3..3),
        MatchRef.new(input_string, 5..5),
        MatchRef.new(input_string, 5..6),
        MatchRef.new(input_string, 6..6),
        MatchRef.new(input_string, 5..7),
        MatchRef.new(input_string, 6..7),
        MatchRef.new(input_string, 7..7)
      ]
    })
  end
end

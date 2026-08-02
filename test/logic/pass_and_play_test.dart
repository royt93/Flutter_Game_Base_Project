import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/pass_and_play.dart';

void main() {
  test('duelOutcome identifies player 1 win', () {
    expect(duelOutcome(100, 90), DuelOutcome.player1);
  });

  test('duelOutcome identifies player 2 win', () {
    expect(duelOutcome(90, 100), DuelOutcome.player2);
  });

  test('duelOutcome identifies a draw', () {
    expect(duelOutcome(100, 100), DuelOutcome.draw);
  });

  test('first turn stores score and advances to player 2', () {
    final result = recordDuelTurn(
      currentPlayer: 1,
      score: 120,
      player1Score: 0,
      player2Score: 0,
    );
    expect(result.player1Score, 120);
    expect(result.nextPlayer, 2);
    expect(result.completed, isFalse);
  });

  test('second turn stores score and completes duel', () {
    final result = recordDuelTurn(
      currentPlayer: 2,
      score: 90,
      player1Score: 120,
      player2Score: 0,
    );
    expect(result.player2Score, 90);
    expect(result.completed, isTrue);
  });
}

enum DuelOutcome { player1, player2, draw }

class DuelTurnResult {
  const DuelTurnResult({
    required this.player1Score,
    required this.player2Score,
    required this.nextPlayer,
    required this.completed,
  });
  final int player1Score;
  final int player2Score;
  final int nextPlayer;
  final bool completed;
}

DuelTurnResult recordDuelTurn({
  required int currentPlayer,
  required int score,
  required int player1Score,
  required int player2Score,
}) => currentPlayer == 1
    ? DuelTurnResult(
        player1Score: score,
        player2Score: player2Score,
        nextPlayer: 2,
        completed: false,
      )
    : DuelTurnResult(
        player1Score: player1Score,
        player2Score: score,
        nextPlayer: 2,
        completed: true,
      );

DuelOutcome duelOutcome(int player1Score, int player2Score) {
  if (player1Score > player2Score) return DuelOutcome.player1;
  if (player2Score > player1Score) return DuelOutcome.player2;
  return DuelOutcome.draw;
}

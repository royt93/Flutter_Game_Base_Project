import 'package:get/get.dart';

import '../../logic/pass_and_play.dart';
import 'game_controller.dart';

/// I59: orchestration của hai ván độc lập trên cùng một seed/bàn gốc.
class PassAndPlayController extends GetxController {
  PassAndPlayController(this.gameCtrl);

  final GameController gameCtrl;
  final currentPlayer = 1.obs;
  final player1Score = 0.obs;
  final player2Score = 0.obs;
  final awaitingHandoff = false.obs;
  final completed = false.obs;
  Worker? _endWorker;

  DuelOutcome get outcome =>
      duelOutcome(player1Score.value, player2Score.value);

  @override
  void onInit() {
    super.onInit();
    _endWorker = ever(gameCtrl.ended, _onEnded);
  }

  void startDuel() {
    currentPlayer.value = 1;
    player1Score.value = 0;
    player2Score.value = 0;
    awaitingHandoff.value = false;
    completed.value = false;
    gameCtrl.startPassAndPlayDuel();
  }

  void _onEnded(bool ended) {
    if (!ended || gameCtrl.mode.value != GameMode.passAndPlay) return;
    final result = recordDuelTurn(
      currentPlayer: currentPlayer.value,
      score: gameCtrl.score.value,
      player1Score: player1Score.value,
      player2Score: player2Score.value,
    );
    player1Score.value = result.player1Score;
    player2Score.value = result.player2Score;
    if (!result.completed) {
      awaitingHandoff.value = true;
    } else {
      completed.value = true;
    }
  }

  void beginPlayer2() {
    if (!awaitingHandoff.value) return;
    awaitingHandoff.value = false;
    currentPlayer.value = 2;
    gameCtrl.startPassAndPlayTurn();
  }

  @override
  void onClose() {
    _endWorker?.dispose();
    super.onClose();
  }
}

import 'package:get/get.dart';

import 'game_controller.dart';

class TreasureMapController extends GetxController {
  TreasureMapController(this.gameCtrl);
  final GameController gameCtrl;
  final stageIndex = 1.obs;
  final awaitingNextStage = false.obs;
  final failed = false.obs;
  final completed = false.obs;
  Worker? _endWorker;

  @override
  void onInit() {
    super.onInit();
    _endWorker = ever(gameCtrl.ended, _onEnded);
  }

  bool startExpedition() {
    if (!gameCtrl.consumeTreasureMap()) return false;
    stageIndex.value = 1;
    awaitingNextStage.value = false;
    failed.value = false;
    completed.value = false;
    gameCtrl.startTreasureMapStage(1);
    return true;
  }

  void _onEnded(bool ended) {
    if (!ended || gameCtrl.mode.value != GameMode.treasureMap) return;
    if (gameCtrl.score.value < gameCtrl.currentLevel.targetScore) {
      failed.value = true;
      return;
    }
    if (stageIndex.value == 5) {
      completed.value = true;
      gameCtrl.completeTreasureMap();
    } else {
      awaitingNextStage.value = true;
    }
  }

  void nextStage() {
    if (!awaitingNextStage.value) return;
    stageIndex.value++;
    awaitingNextStage.value = false;
    gameCtrl.startTreasureMapStage(stageIndex.value);
  }

  @override
  void onClose() {
    _endWorker?.dispose();
    super.onClose();
  }
}

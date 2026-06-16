import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/storage_service.dart';
import '../../data/levels.dart';
import '../../data/story.dart';
import '../../game/neon_jewel_game.dart';
import 'battle_pass_controller.dart';
import 'game_controller.dart';
import 'season_controller.dart';
import 'story_controller.dart';

/// Trạng thái UI của màn chơi (thay cho setState).
enum GameUi { playing, quit, win, lose }

/// Controller GetX cho màn chơi: vòng đời (wakelock), instance game, overlay.
class GameScreenController extends GetxController {
  final GameController gameCtrl;
  GameScreenController(this.gameCtrl);

  final Rx<GameUi> ui = GameUi.playing.obs;
  final RxInt gameVersion = 0.obs; // tăng để Obx dựng lại GameWidget
  final Rx<BoosterMode> armed = BoosterMode.none.obs; // booster đang chọn
  final RxInt coinShake = 0.obs; // tăng để rung chip xu khi thiếu xu

  // --- Tutorial lần đầu (chỉ màn 1) ---
  static const int tutorialSteps = 3;
  final RxBool tutorialOpen = false.obs;
  final RxInt tutorialStep = 0.obs;

  NeonJewelGame? _game;
  NeonJewelGame get game => _game!;

  @override
  void onInit() {
    super.onInit();
    WakelockPlus.enable(); // giữ màn sáng khi chơi
    _newGame();
    // Hoãn các mutation Rx (booster pre-game + mở tutorial) sang sau frame đầu
    // — tránh markNeedsBuild trong lúc GameScreen đang build.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _applyPregameBoosters();
      // Tutorial chỉ ở màn 1 thường — KHÔNG hiện ở chế độ phụ (Endless/Boss/Trọng lực),
      // vì các chế độ đó giữ nguyên currentLevel (mặc định 1 khi mới cài).
      if (!gameCtrl.isEndless.value &&
          !gameCtrl.isBoss.value &&
          !gameCtrl.isGravity.value &&
          gameCtrl.currentLevel.value == 1 &&
          StorageService.to.getInt(StorageKeys.tutorialSeen, def: 0) == 0) {
        tutorialOpen.value = true;
      }
    });
  }

  /// Áp booster đã chọn ở pre-game panel (1 lần, đầu màn).
  void _applyPregameBoosters() {
    if (gameCtrl.pendingMovesBoost) {
      gameCtrl.pendingMovesBoost = false;
      if (gameCtrl.boosterMoves.value > 0) gameCtrl.useMovesBooster();
    }
    if (gameCtrl.pendingArmHammer) {
      gameCtrl.pendingArmHammer = false;
      if (gameCtrl.boosterHammer.value > 0) {
        game.armBooster(BoosterMode.hammer);
        armed.value = BoosterMode.hammer;
      }
    }
  }

  void tutorialNext() {
    if (tutorialStep.value < tutorialSteps - 1) {
      tutorialStep.value++;
    } else {
      _endTutorial();
    }
  }

  /// Vuốt phải → lùi bước (không lùi quá bước đầu).
  void tutorialPrev() {
    if (tutorialStep.value > 0) tutorialStep.value--;
  }

  void tutorialSkip() => _endTutorial();

  void _endTutorial() {
    tutorialOpen.value = false;
    StorageService.to.setInt(StorageKeys.tutorialSeen, 1);
  }

  @override
  void onClose() {
    WakelockPlus.disable();
    super.onClose();
  }

  void _newGame() {
    final lv = gameCtrl.level;
    _game = NeonJewelGame(
      controller: gameCtrl,
      rows: lv.rows,
      cols: lv.cols,
      colorCount: lv.colorCount,
      onGameEnd: _onGameEnd,
      onBoosterUsed: _onBoosterUsed,
      // Thử thách ngày: seed theo NGÀY → mọi người cùng bàn (các mode khác null).
      boardSeed: gameCtrl.boardSeed,
    );
    gameVersion.value++;
  }

  int _countOf(BoosterMode m) {
    switch (m) {
      case BoosterMode.hammer:
        return gameCtrl.boosterHammer.value;
      case BoosterMode.swap:
        return gameCtrl.boosterSwap.value;
      case BoosterMode.bomb:
        return gameCtrl.boosterBomb.value;
      case BoosterMode.colorBlast:
        return gameCtrl.boosterColor.value;
      case BoosterMode.joker:
        return gameCtrl.boosterJoker.value;
      case BoosterMode.none:
        return 0;
    }
  }

  /// Chọn booster cần chạm bàn (hammer/swap/bomb/colorBlast).
  /// Bấm lại booster đang chọn → bỏ chọn.
  void toggleArm(BoosterMode m) {
    if (armed.value == m) {
      game.disarmBooster();
      armed.value = BoosterMode.none;
    } else if (_countOf(m) > 0) {
      game.armBooster(m);
      armed.value = m;
    }
  }

  void _onBoosterUsed(BoosterMode m) {
    switch (m) {
      case BoosterMode.hammer:
        gameCtrl.useHammer();
        break;
      case BoosterMode.swap:
        gameCtrl.useSwap();
        break;
      case BoosterMode.bomb:
        gameCtrl.useBomb();
        break;
      case BoosterMode.colorBlast:
        gameCtrl.useColor();
        break;
      case BoosterMode.joker:
        gameCtrl.useJoker();
        break;
      case BoosterMode.none:
        break;
    }
    armed.value = BoosterMode.none;
  }

  void _onGameEnd(String result) {
    // Endless, Boss & Thử thách ngày là chế độ phụ — thua KHÔNG trừ mạng.
    if (result == 'lose' &&
        !gameCtrl.isEndless.value &&
        !gameCtrl.isBoss.value &&
        !gameCtrl.isDaily.value) {
      gameCtrl.consumeLife();
    }
    // Battle Pass + Sự kiện mùa: ghi tiến trình (chỉ màn thường, không chế độ phụ).
    if (!gameCtrl.isEndless.value &&
        !gameCtrl.isBoss.value &&
        !gameCtrl.isDaily.value) {
      BattlePassController.maybe?.recordLevelEnd(
        win: result == 'win',
        stars: gameCtrl.lastStars,
        coins: gameCtrl.lastCoinReward,
        combo: gameCtrl.runMaxCombo.value,
      );
      if (result == 'win') {
        SeasonController.maybe?.addWin(gameCtrl.lastStars);
      }
    }
    Future.delayed(const Duration(milliseconds: 350), () {
      ui.value = result == 'win' ? GameUi.win : GameUi.lose;
    });
  }

  // --- điều khiển overlay ---
  void confirmQuit() {
    if (ui.value == GameUi.playing) ui.value = GameUi.quit;
  }

  void closeOverlay() {
    if (ui.value == GameUi.quit) ui.value = GameUi.playing;
  }

  void quit() {
    WakelockPlus.disable();
    Get.delete<GameScreenController>();
    Get.back(); // rời màn chơi
  }

  void again() {
    if (gameCtrl.isEndless.value) {
      // Endless: chơi lại không cần mạng.
      gameCtrl.startEndless();
      ui.value = GameUi.playing;
      _newGame();
      return;
    }
    if (gameCtrl.isBoss.value) {
      // Boss: đánh lại cùng stage, không cần mạng.
      gameCtrl.startBoss(gameCtrl.bossStage.value);
      ui.value = GameUi.playing;
      _newGame();
      return;
    }
    if (gameCtrl.isRhythm.value) {
      // Rhythm: chơi lại không cần mạng.
      gameCtrl.startRhythm();
      ui.value = GameUi.playing;
      _newGame();
      return;
    }
    if (gameCtrl.isDaily.value) {
      // Thử thách ngày: chơi lại CÙNG bàn (seed theo ngày), không cần mạng,
      // không thưởng lại (checkEnd tự chặn nếu đã hoàn thành hôm nay).
      gameCtrl.startDaily();
      ui.value = GameUi.playing;
      _newGame();
      return;
    }
    // hết mạng → không cho chơi lại (tránh lách cổng mạng); về Level Select.
    if (!gameCtrl.hasLife) {
      quit();
      return;
    }
    gameCtrl.startLevel(gameCtrl.currentLevel.value);
    ui.value = GameUi.playing;
    _newGame();
  }

  void next() {
    gameCtrl.startLevel(gameCtrl.currentLevel.value + 1);
    ui.value = GameUi.playing;
    _newGame();
  }

  /// Sau khi thắng: nếu vừa hoàn thành màn cuối thế giới → hiện outro cốt
  /// truyện trước, rồi mới đi tiếp (màn kế) hoặc về Home (màn cuối game).
  void proceedNextOrHome() {
    final lv = gameCtrl.currentLevel.value;
    final goNext = lv < kLevels.length;
    void go() => goNext ? next() : quit();
    if (!gameCtrl.isEndless.value && lv == worldOfLevel(lv).endLevel) {
      if (StoryController.to.maybeShow(
          StoryTrigger.outro, worldOfLevel(lv).index,
          onComplete: go)) {
        return;
      }
    }
    go();
  }
}

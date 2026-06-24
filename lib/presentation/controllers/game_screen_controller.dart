import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/neon_theme.dart';
import '../../core/storage_service.dart';
import '../../data/levels.dart';
import '../../data/side_mode_records.dart';
import '../../data/story.dart';
import '../../game/neon_jewel_game.dart';
import 'battle_pass_controller.dart';
import 'challenge_card_controller.dart';
import 'collection_controller.dart';
import 'game_controller.dart';
import 'piggy_controller.dart';
import 'progression_tree_controller.dart';
import 'season_league_controller.dart';
import 'side_mode_record_controller.dart';
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
      // Tutorial chỉ ở MÀN 1 THƯỜNG — KHÔNG hiện ở mọi chế độ phụ (Endless/Boss/
      // Gravity/Rhythm/Color Rush/Daily/Versus), vì các chế độ đó giữ nguyên
      // currentLevel (mặc định 1 khi mới cài) → trước đây tutorial bật nhầm ở
      // Rhythm/Color Rush/Daily. Dùng isSideMode (1 nguồn) — xem side-mode-isolation.
      if (!gameCtrl.isSideMode &&
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
    // Chế độ phụ (Endless/Boss/Gravity/Rhythm/Daily) — thua KHÔNG trừ mạng.
    if (result == 'lose' && !gameCtrl.isSideMode) {
      gameCtrl.consumeLife();
    }
    // Battle Pass + Sự kiện mùa: ghi tiến trình (chỉ màn thường, không chế độ phụ).
    if (!gameCtrl.isSideMode) {
      BattlePassController.maybe?.recordLevelEnd(
        win: result == 'win',
        stars: gameCtrl.lastStars,
        coins: gameCtrl.lastCoinReward,
        combo: gameCtrl.runMaxCombo.value,
      );
      if (result == 'win') {
        // W18.1: Mùa giải (gộp Mùa + Giải đấu) — 1 điểm/thắng nuôi cả 2 trục.
        SeasonLeagueController.maybe?.addWin(gameCtrl.lastStars);
        // Wave 14 — meta giữ chân: album sưu tập + heo đất. Chỉ first-clear.
        if (gameCtrl.lastFirstClear) {
          CollectionController.maybe?.addWin(gameCtrl.lastStars);
          PiggyController.maybe?.addWin(gameCtrl.lastStars);
        }
        // W20.3 — Challenge Card campaign win + Progression Tree.
        ChallengeCardController.maybe?.onCampaignWin();
        ChallengeCardController.maybe?.refreshCoins();
        ProgressionTreeController.maybe?.checkAndUnlock();
      }
    } else {
      // W20.3 — Side mode play count cho Challenge Card.
      final modeKey = _sideModeKey(gameCtrl);
      if (modeKey != null) {
        ChallengeCardController.maybe?.onSideModePlayed(modeKey);
      }
      // W19.1 — kỷ lục chế độ phụ (Endless/Boss/Rhythm/Gravity/Soda/ColorRush/
      // Survival/Labyrinth). Daily/Versus trả null → bỏ qua. Banner ăn mừng nếu
      // phá kỷ lục / mở mốc (game còn sống trong 350ms trước overlay).
      final outcome = SideModeRecordController.maybe?.recordResult(
        won: result == 'win',
      );
      if (outcome != null && outcome.hasCelebration && _game != null) {
        if (outcome.newTier != RecordTier.none) {
          final tierName = 'rec_tier_${outcome.newTier.name}'.tr;
          game.showBanner(
            'rec_milestone'.tr.replaceFirst('@t', tierName),
            NeonTheme.yellow,
          );
        } else if (outcome.newBest) {
          game.showBanner('rec_new_best'.tr, NeonTheme.cyan);
        }
      }
    }
    Future.delayed(const Duration(milliseconds: 350), () {
      ui.value = result == 'win' ? GameUi.win : GameUi.lose;
    });
  }

  /// Trả về i18n key mode phụ để Challenge Card nhận biết (hoặc null).
  static String? _sideModeKey(GameController g) {
    if (g.isEndless.value) return 'endless_short';
    if (g.isBoss.value) return 'boss_short';
    if (g.isRhythm.value) return 'rhythm_short';
    if (g.isGravity.value) return 'gravity_short';
    if (g.isSoda.value) return 'soda_short';
    if (g.isColorRush.value) return 'color_rush_short';
    if (g.isRush.value) return 'rush_short';
    return null; // Daily/Survival/Labyrinth/Puzzle/Versus không track
  }

  // --- điều khiển overlay ---
  void confirmQuit() {
    if (ui.value == GameUi.playing) ui.value = GameUi.quit;
  }

  void closeOverlay() {
    if (ui.value == GameUi.quit) ui.value = GameUi.playing;
  }

  bool _zenResultShown = false;

  void quit() {
    // Zen Mode: lần đầu quit → lưu kỷ lục + hiện result panel thay vì về Home ngay.
    if (gameCtrl.isZen.value && !_zenResultShown) {
      gameCtrl.endZenSession();
      _zenResultShown = true;
      ui.value = GameUi.lose; // dùng lose panel cho Zen result
      return;
    }
    _leaveGame();
  }

  void _leaveGame() {
    WakelockPlus.disable();
    Get.delete<GameScreenController>();
    Get.back();
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
    if (gameCtrl.isGravity.value) {
      // Trọng lực động: chơi lại không cần mạng (chế độ phụ).
      gameCtrl.startGravity();
      ui.value = GameUi.playing;
      _newGame();
      return;
    }
    if (gameCtrl.isColorRush.value) {
      // Color Rush: chơi lại không cần mạng (chế độ phụ).
      gameCtrl.startColorRush();
      ui.value = GameUi.playing;
      _newGame();
      return;
    }
    if (gameCtrl.isSoda.value) {
      // Soda: chơi lại không cần mạng (chế độ phụ).
      gameCtrl.startSoda();
      ui.value = GameUi.playing;
      _newGame();
      return;
    }
    if (gameCtrl.isSurvival.value) {
      // Sinh tồn: chơi lại không cần mạng (chế độ phụ).
      gameCtrl.startSurvival();
      ui.value = GameUi.playing;
      _newGame();
      return;
    }
    if (gameCtrl.isZen.value) {
      // Zen Mode: chơi lại không cần mạng.
      _zenResultShown = false;
      gameCtrl.startZen();
      ui.value = GameUi.playing;
      _newGame();
      return;
    }
    if (gameCtrl.isLabyrinth.value) {
      // Mê cung: chơi lại không cần mạng (chế độ phụ).
      gameCtrl.startLabyrinth();
      ui.value = GameUi.playing;
      _newGame();
      return;
    }
    if (gameCtrl.isRush.value) {
      // Rush: chơi lại không cần mạng (chế độ phụ).
      gameCtrl.startRush();
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
        StoryTrigger.outro,
        worldOfLevel(lv).index,
        onComplete: go,
      )) {
        return;
      }
    }
    go();
  }
}

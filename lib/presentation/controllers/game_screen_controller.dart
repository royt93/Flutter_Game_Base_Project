import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/share_helper.dart';
import '../../core/storage_service.dart';
import '../../data/levels.dart';
import '../../data/mirror_board.dart';
import '../../game/pop_star_game.dart';
import '../../logic/challenge_code.dart';
import '../../logic/replay.dart';
import 'game_controller.dart';
import 'pass_and_play_controller.dart';
import 'treasure_map_controller.dart';

/// Trạng thái UI của màn chơi (thay cho setState).
enum GameUi { playing, quit, win, lose }

enum BoosterMode { none, bomb, rainbow, swap }

/// Controller GetX cho màn chơi: vòng đời, instance game, overlay.
/// Campaign + 2 side-mode (F8 Time-attack/Zen), phân biệt qua [GameController.mode].
class GameScreenController extends GetxController {
  final GameController gameCtrl;

  GameScreenController(this.gameCtrl);

  final Rx<GameUi> ui = GameUi.playing.obs;
  final RxInt gameVersion = 0.obs; // tăng để Obx dựng lại GameWidget
  final Rx<BoosterMode> armed = BoosterMode.none.obs;

  /// X1: overlay "chạm để nổ" — chỉ hiện lần mở app đầu tiên trên level 1.
  final RxBool showFtue = false.obs;

  /// F8 Time-attack: đếm ngược 60s, hết giờ → kết thúc ván.
  static const int timeAttackSeconds = 60;
  final RxInt remainingSeconds = timeAttackSeconds.obs;
  Timer? _countdown;

  PopStarGame? _game;
  Worker? _endWorker;

  /// F10: ô đầu tiên đã chọn khi arm Swap — null nếu chưa chọn ô nào.
  Point<int>? _swapFirst;

  /// F15: key của `RepaintBoundary` bọc bàn chơi, dùng để chụp ảnh chia sẻ.
  final GlobalKey boardKey = GlobalKey();
  final GlobalKey challengeCardKey = GlobalKey();

  PopStarGame get game => _game!;

  /// F15: chụp ảnh bàn chơi + text level/điểm/ngày rồi mở share sheet.
  Future<void> shareBoard() async {
    final date = DateTime.now().toIso8601String().split('T').first;
    final text = 'share_board_text'.trParams({
      'level': '${gameCtrl.currentLevel.id}',
      'score': '${gameCtrl.score.value}',
      'date': date,
    });
    await shareBoardImage(boundaryKey: boardKey, text: text);
  }

  /// I28: mã hoá lượt chơi hiện tại (nếu đã bật ghi + chưa dùng hành động
  /// không tái tạo được) thành mã text rồi mở share sheet, để bạn bè dán mã
  /// vào `GhostReplayScreen` xem lại y hệt ván chơi.
  Future<void> shareReplay() async {
    final g = _game;
    if (g == null || !g.recordingEnabled || !g.recordingValid) return;
    final code = encodeReplay(
      ReplayData(
        levelId: gameCtrl.currentLevel.id,
        seed: g.seed,
        taps: g.recordedTaps,
      ),
    );
    await shareText('share_replay_text'.trParams({'code': code}));
  }

  /// I28: có thể chia sẻ replay ván hiện tại không — dùng để ẩn/hiện nút chia
  /// sẻ replay ở overlay thắng màn.
  bool get canShareReplay {
    final g = _game;
    return g != null &&
        g.recordingEnabled &&
        g.recordingValid &&
        g.recordedTaps.isNotEmpty;
  }

  /// I37: mã hoá điểm vừa đạt ở level hiện tại thành mã "thách đấu" rồi mở
  /// share sheet, để bạn bè dán mã vào `GhostReplayScreen` chơi lại đúng level
  /// đó và so điểm — không kèm replay đầy đủ như [shareReplay].
  Future<void> shareChallenge() async {
    final seeded = gameCtrl.activeSeedChallenge.value;
    if (seeded != null) {
      final code = encodeChallengeSeedCode(
        ChallengeSeedCode(
          levelId: seeded.levelId,
          seed: seeded.seed,
          score: gameCtrl.score.value,
          senderName: gameCtrl.playerName.value,
        ),
      );
      await shareBoardImage(
        boundaryKey: challengeCardKey,
        text: 'seed_challenge_share_text'.trParams({'code': code}),
      );
      return;
    }
    final code = encodeChallengeCode(
      ChallengeCode(
        levelId: gameCtrl.currentLevel.id,
        score: gameCtrl.score.value,
        senderName: gameCtrl.playerName.value,
      ),
    );
    await shareText('share_challenge_text'.trParams({'code': code}));
  }

  Widget buildChallengeQrCard() {
    final seeded = gameCtrl.activeSeedChallenge.value!;
    final code = encodeChallengeSeedCode(
      ChallengeSeedCode(
        levelId: seeded.levelId,
        seed: seeded.seed,
        score: gameCtrl.score.value,
        senderName: gameCtrl.playerName.value,
      ),
    );
    return RepaintBoundary(
      key: challengeCardKey,
      child: ColoredBox(
        color: const Color(0xFFFFFFFF),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(data: code, size: 132),
              Text(
                'seed_challenge_card_score'.trParams({
                  'score': '${gameCtrl.score.value}',
                }),
              ),
              SelectableText(code, style: const TextStyle(fontSize: 7)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void onInit() {
    super.onInit();
    // Kết thúc màn đến BẤT ĐỒNG BỘ (sau animation pop/rơi) → lắng nghe reactive
    // thay vì kiểm tra ngay sau tap.
    _endWorker = ever(gameCtrl.ended, _onEndChanged);
    _newGame();
    if (gameCtrl.mode.value == GameMode.timeAttack) _startCountdown();
  }

  @override
  void onClose() {
    _countdown?.cancel();
    _endWorker?.dispose();
    super.onClose();
  }

  void _startCountdown() {
    remainingSeconds.value = timeAttackSeconds;
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      remainingSeconds.value--;
      if (remainingSeconds.value <= 0) {
        _countdown?.cancel();
        gameCtrl.checkEnd(false);
      }
    });
  }

  void _onEndChanged(bool ended) {
    if (!ended || ui.value != GameUi.playing) return;
    if (gameCtrl.mode.value == GameMode.passAndPlay) return;
    final result = gameCtrl.starsEarned.value > 0 ? GameUi.win : GameUi.lose;
    Future.delayed(const Duration(milliseconds: 350), () {
      if (ui.value == GameUi.playing) ui.value = result;
    });
  }

  void _newGame() {
    // X1: level 1 campaign, cài đặt app chưa từng thấy FTUE → ép gợi ý ngay
    // khi board sẵn sàng (xem [PopStarGame.startWithFtueHint]), không chờ
    // idle timer như I4 bình thường.
    final ftue =
        gameCtrl.mode.value == GameMode.campaign &&
        gameCtrl.currentLevel.id == 1 &&
        !StorageService.to.getBool(StorageKeys.hasSeenFtue);
    _game = PopStarGame(
      gameCtrl,
      refillEnabled: gameCtrl.mode.value == GameMode.zen,
      startWithFtueHint: ftue,
      presetGrid: switch (gameCtrl.mode.value) {
        GameMode.dailyChallenge => gameCtrl.dailyChallengeGrid,
        GameMode.gauntlet => gameCtrl.gauntletGrid,
        GameMode.puzzleLab => gameCtrl.puzzleLabGrid,
        GameMode.passAndPlay => gameCtrl.passAndPlayGrid,
        GameMode.treasureMap => gameCtrl.puzzleLabGrid,
        // I47 Mirror Mode: bàn đầu đối xứng gương, seed ngẫu nhiên (khác
        // dailyChallenge — không cần seed cố định cho mode này).
        GameMode.mirrorMode => generateMirrorBoard(
          gameCtrl.currentLevel.rows,
          gameCtrl.currentLevel.cols,
          gameCtrl.currentLevel.colorCount,
          Random(),
        ),
        _ => null,
      },
      // I28: chỉ ghi replay ở campaign — zen/endless không có bàn cố định,
      // dailyChallenge dùng presetGrid riêng mà replay (chỉ seed+levelId)
      // không tái tạo được.
      recordingEnabled:
          gameCtrl.mode.value == GameMode.campaign &&
          StorageService.to.getBool(StorageKeys.recordReplay),
    );
    gameVersion.value++;
    showFtue.value = ftue;
  }

  /// X1: tap đầu tiên (đúng hay sai nhóm) đều tắt overlay FTUE — không để
  /// overlay "kẹt" khi hint đã bị [PopStarGame.clearHint] xoá theo mọi tap.
  void _dismissFtueIfNeeded() {
    if (!showFtue.value) return;
    showFtue.value = false;
    StorageService.to.setBool(StorageKeys.hasSeenFtue, true);
  }

  void toggleBombArm() {
    armed.value = armed.value == BoosterMode.bomb
        ? BoosterMode.none
        : BoosterMode.bomb;
  }

  void toggleRainbowArm() {
    armed.value = armed.value == BoosterMode.rainbow
        ? BoosterMode.none
        : BoosterMode.rainbow;
  }

  void toggleSwapArm() {
    _swapFirst = null;
    armed.value = armed.value == BoosterMode.swap
        ? BoosterMode.none
        : BoosterMode.swap;
  }

  /// Giữ/kéo trên bàn → preview nhóm cùng màu + điểm dự kiến (không khi arm booster).
  void previewBoardTap(Vector2 pos) {
    if (armed.value != BoosterMode.none) return;
    game.previewGroup(pos);
  }

  /// Thả tay: theo booster đang arm (bomb/rainbow), ngược lại nổ nhóm đang preview.
  void handleBoardTap(Vector2 pos) {
    game.clearHint(); // I4: bất kỳ tap nào cũng tắt gợi ý + reset timer rảnh tay.
    game.clearPreview();
    _dismissFtueIfNeeded();
    if (armed.value == BoosterMode.bomb) {
      final cell = game.cellAt(pos);
      if (cell != null) {
        gameCtrl.useBomb(cell.x, cell.y);
        armed.value = BoosterMode.none;
      }
      // tap ngoài bàn: giữ nguyên bomb đang arm, không tiêu phí
    } else if (armed.value == BoosterMode.rainbow) {
      final cell = game.cellAt(pos);
      if (cell != null) {
        gameCtrl.useRainbow(cell.x, cell.y);
        armed.value = BoosterMode.none;
      }
    } else if (armed.value == BoosterMode.swap) {
      final cell = game.cellAt(pos);
      if (cell == null) {
        // tap ngoài bàn: giữ nguyên swap đang arm, không tiêu phí
      } else if (_swapFirst == null) {
        _swapFirst = cell;
      } else if (cell == _swapFirst) {
        _swapFirst = null; // tap lại đúng ô đầu: bỏ chọn
      } else {
        gameCtrl.useSwap(_swapFirst!.x, _swapFirst!.y, cell.x, cell.y);
        _swapFirst = null;
        armed.value = BoosterMode.none;
      }
    } else {
      game.handleTap(pos);
    }
    // Kết thúc màn được xử lý qua _onEndChanged (lắng nghe gameCtrl.ended).
  }

  void useShuffle() {
    gameCtrl.useShuffle();
  }

  void useUndo() {
    gameCtrl.useUndo();
  }

  void useFreeze() {
    gameCtrl.useFreeze();
  }

  void useHint() {
    gameCtrl.useHint();
  }

  // --- điều khiển overlay ---
  void confirmQuit() {
    if (ui.value == GameUi.playing) ui.value = GameUi.quit;
  }

  void closeOverlay() {
    if (ui.value == GameUi.quit) ui.value = GameUi.playing;
  }

  void quit() {
    if (Get.isRegistered<PassAndPlayController>()) {
      Get.delete<PassAndPlayController>();
    }
    if (Get.isRegistered<TreasureMapController>()) {
      Get.delete<TreasureMapController>();
    }
    Get.delete<GameScreenController>();
    Get.back();
  }

  void beginPlayer2() {
    final duel = Get.find<PassAndPlayController>();
    duel.beginPlayer2();
    armed.value = BoosterMode.none;
    _swapFirst = null;
    ui.value = GameUi.playing;
    _newGame();
  }

  void beginNextTreasureStage() {
    Get.find<TreasureMapController>().nextStage();
    armed.value = BoosterMode.none;
    _swapFirst = null;
    ui.value = GameUi.playing;
    _newGame();
  }

  void again() {
    final mode = gameCtrl.mode.value;
    if (mode == GameMode.campaign) {
      gameCtrl.startLevel(gameCtrl.currentLevel.id);
    } else if (mode == GameMode.endless) {
      // F12: startSideMode mặc định kZenLevel cho mọi mode khác timeAttack —
      // endless cần reset về bàn index 0 riêng, không dùng nhánh đó.
      gameCtrl.startEndless();
    } else if (mode == GameMode.dailyChallenge) {
      // F13: cùng ngày → sinh lại đúng bàn cũ (seed = ngày), không đè điểm
      // đã ghi nếu đã ghi lần đầu (xem `canRecordDailyChallengeScore`).
      gameCtrl.startDailyChallenge();
    } else if (mode == GameMode.puzzleLab) {
      // I42: KHÔNG rơi vào startSideMode — phải giữ đúng puzzleLabGrid đã vẽ.
      final seeded = gameCtrl.activeSeedChallenge.value;
      if (seeded != null) {
        gameCtrl.startSeedChallenge(seeded);
      } else {
        gameCtrl.startPuzzleLevel(gameCtrl.puzzleLabGrid!);
      }
    } else if (mode == GameMode.gauntlet) {
      // I33: cùng ngày → cùng modifier + cùng bàn (seed = ngày), không đè
      // điểm đã ghi nếu đã ghi lần đầu (xem `canRecordGauntletScore`).
      gameCtrl.startGauntlet();
    } else if (mode == GameMode.passAndPlay) {
      Get.find<PassAndPlayController>().startDuel();
    } else if (mode == GameMode.treasureMap) {
      // A failed run cannot retry without consuming another map from Home.
      quit();
      return;
    } else {
      gameCtrl.startSideMode(mode);
    }
    armed.value = BoosterMode.none;
    _swapFirst = null;
    ui.value = GameUi.playing;
    _newGame();
    if (mode == GameMode.timeAttack) _startCountdown();
  }

  void next() {
    final nextId = gameCtrl.currentLevel.id + 1;
    if (nextId > kLevelCount) {
      quit();
      return;
    }
    gameCtrl.startLevel(nextId);
    armed.value = BoosterMode.none;
    _swapFirst = null;
    ui.value = GameUi.playing;
    _newGame();
  }
}

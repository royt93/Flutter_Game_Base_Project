import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/share_helper.dart';
import '../../core/storage_service.dart';
import '../../data/levels.dart';
import '../../game/pop_star_game.dart';
import 'game_controller.dart';

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

  PopStarGame get game => _game!;

  /// F15: chụp ảnh bàn chơi + text level/điểm/ngày rồi mở share sheet.
  Future<void> shareBoard() async {
    final date = DateTime.now().toIso8601String().split('T').first;
    final text =
        'Pop Star Blast — Level ${gameCtrl.currentLevel.id} — '
        'Score ${gameCtrl.score.value} — $date';
    await shareBoardImage(boundaryKey: boardKey, text: text);
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
      presetGrid: gameCtrl.mode.value == GameMode.dailyChallenge
          ? gameCtrl.dailyChallengeGrid
          : null,
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

  // --- điều khiển overlay ---
  void confirmQuit() {
    if (ui.value == GameUi.playing) ui.value = GameUi.quit;
  }

  void closeOverlay() {
    if (ui.value == GameUi.quit) ui.value = GameUi.playing;
  }

  void quit() {
    Get.delete<GameScreenController>();
    Get.back();
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

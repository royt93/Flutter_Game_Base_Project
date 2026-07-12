import 'dart:async';

import 'package:flame/game.dart';
import 'package:get/get.dart';

import '../../data/levels.dart';
import '../../game/pop_star_game.dart';
import 'game_controller.dart';

/// Trạng thái UI của màn chơi (thay cho setState).
enum GameUi { playing, quit, win, lose }

enum BoosterMode { none, bomb, rainbow }

/// Controller GetX cho màn chơi: vòng đời, instance game, overlay.
/// Campaign + 2 side-mode (F8 Time-attack/Zen), phân biệt qua [GameController.mode].
class GameScreenController extends GetxController {
  final GameController gameCtrl;

  GameScreenController(this.gameCtrl);

  final Rx<GameUi> ui = GameUi.playing.obs;
  final RxInt gameVersion = 0.obs; // tăng để Obx dựng lại GameWidget
  final Rx<BoosterMode> armed = BoosterMode.none.obs;

  /// F8 Time-attack: đếm ngược 60s, hết giờ → kết thúc ván.
  static const int timeAttackSeconds = 60;
  final RxInt remainingSeconds = timeAttackSeconds.obs;
  Timer? _countdown;

  PopStarGame? _game;
  Worker? _endWorker;

  PopStarGame get game => _game!;

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
    _game = PopStarGame(
      gameCtrl,
      refillEnabled: gameCtrl.mode.value == GameMode.zen,
    );
    gameVersion.value++;
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

  /// Giữ/kéo trên bàn → preview nhóm cùng màu + điểm dự kiến (không khi arm booster).
  void previewBoardTap(Vector2 pos) {
    if (armed.value != BoosterMode.none) return;
    game.previewGroup(pos);
  }

  /// Thả tay: theo booster đang arm (bomb/rainbow), ngược lại nổ nhóm đang preview.
  void handleBoardTap(Vector2 pos) {
    game.clearPreview();
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
    } else {
      gameCtrl.startSideMode(mode);
    }
    armed.value = BoosterMode.none;
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
    ui.value = GameUi.playing;
    _newGame();
  }
}

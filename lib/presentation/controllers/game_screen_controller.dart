import 'package:flame/game.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/levels.dart';
import '../../game/pop_star_game.dart';
import 'game_controller.dart';

/// Trạng thái UI của màn chơi (thay cho setState).
enum GameUi { playing, quit, win, lose }

enum BoosterMode { none, bomb }

/// Controller GetX cho màn chơi: vòng đời (wakelock), instance game, overlay.
/// 1 mode duy nhất (campaign) — không còn side-mode/ghost/tutorial cũ.
class GameScreenController extends GetxController {
  final GameController gameCtrl;

  GameScreenController(this.gameCtrl);

  final Rx<GameUi> ui = GameUi.playing.obs;
  final RxInt gameVersion = 0.obs; // tăng để Obx dựng lại GameWidget
  final Rx<BoosterMode> armed = BoosterMode.none.obs;

  PopStarGame? _game;
  Worker? _endWorker;

  PopStarGame get game => _game!;

  @override
  void onInit() {
    super.onInit();
    WakelockPlus.enable();
    // Kết thúc màn đến BẤT ĐỒNG BỘ (sau animation pop/rơi) → lắng nghe reactive
    // thay vì kiểm tra ngay sau tap.
    _endWorker = ever(gameCtrl.ended, _onEndChanged);
    _newGame();
  }

  @override
  void onClose() {
    _endWorker?.dispose();
    WakelockPlus.disable();
    super.onClose();
  }

  void _onEndChanged(bool ended) {
    if (!ended || ui.value != GameUi.playing) return;
    final result = gameCtrl.starsEarned.value > 0 ? GameUi.win : GameUi.lose;
    Future.delayed(const Duration(milliseconds: 350), () {
      if (ui.value == GameUi.playing) ui.value = result;
    });
  }

  void _newGame() {
    _game = PopStarGame(gameCtrl);
    gameVersion.value++;
  }

  void toggleBombArm() {
    armed.value = armed.value == BoosterMode.bomb
        ? BoosterMode.none
        : BoosterMode.bomb;
  }

  /// Giữ/kéo trên bàn → preview nhóm cùng màu + điểm dự kiến (không khi arm bomb).
  void previewBoardTap(Vector2 pos) {
    if (armed.value == BoosterMode.bomb) return;
    game.previewGroup(pos);
  }

  /// Thả tay: nếu arm bomb → nổ 3x3, ngược lại nổ nhóm đang preview.
  void handleBoardTap(Vector2 pos) {
    game.clearPreview();
    if (armed.value == BoosterMode.bomb) {
      final cell = game.cellAt(pos);
      if (cell != null) {
        gameCtrl.useBomb(cell.x, cell.y);
        armed.value = BoosterMode.none;
      }
      // tap ngoài bàn: giữ nguyên bomb đang arm, không tiêu phí
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
    WakelockPlus.disable();
    Get.delete<GameScreenController>();
    Get.back();
  }

  void again() {
    gameCtrl.startLevel(gameCtrl.currentLevel.id);
    armed.value = BoosterMode.none;
    ui.value = GameUi.playing;
    _newGame();
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

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

  PopStarGame get game => _game!;

  @override
  void onInit() {
    super.onInit();
    WakelockPlus.enable();
    _newGame();
  }

  @override
  void onClose() {
    WakelockPlus.disable();
    super.onClose();
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

  /// Tap lên bàn: nếu đang arm bomb → nổ 3x3 tại ô đó, ngược lại nổ nhóm thường.
  void handleBoardTap(Vector2 pos) {
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
    _checkEnded();
  }

  void useShuffle() {
    gameCtrl.useShuffle();
    _checkEnded();
  }

  void useUndo() {
    gameCtrl.useUndo();
    _checkEnded();
  }

  void _checkEnded() {
    if (!gameCtrl.ended.value || ui.value != GameUi.playing) return;
    final result = gameCtrl.starsEarned.value > 0 ? GameUi.win : GameUi.lose;
    Future.delayed(const Duration(milliseconds: 350), () {
      ui.value = result;
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

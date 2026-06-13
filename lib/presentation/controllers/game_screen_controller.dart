import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../game/neon_jewel_game.dart';
import 'game_controller.dart';

/// Trạng thái UI của màn chơi (thay cho setState).
enum GameUi { playing, quit, win, lose }

/// Controller GetX cho màn chơi: vòng đời (wakelock), instance game, overlay.
class GameScreenController extends GetxController {
  final GameController gameCtrl;
  GameScreenController(this.gameCtrl);

  final Rx<GameUi> ui = GameUi.playing.obs;
  final RxInt gameVersion = 0.obs; // tăng để Obx dựng lại GameWidget
  NeonJewelGame? _game;
  NeonJewelGame get game => _game!;

  @override
  void onInit() {
    super.onInit();
    WakelockPlus.enable(); // giữ màn sáng khi chơi
    _newGame();
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
      onHammerUsed: gameCtrl.useHammer,
    );
    gameVersion.value++;
  }

  void _onGameEnd(String result) {
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
    gameCtrl.startLevel(gameCtrl.currentLevel.value);
    ui.value = GameUi.playing;
    _newGame();
  }

  void next() {
    gameCtrl.startLevel(gameCtrl.currentLevel.value + 1);
    ui.value = GameUi.playing;
    _newGame();
  }
}

import 'package:get/get.dart';
import 'game_controller.dart';

/// Pre-game booster panel: chọn booster khởi đầu trước khi vào màn.
/// Chỉ hiện khi người chơi SỞ HỮU booster phù hợp (moves / hammer).
class PregameController extends GetxController {
  final GameController g;
  PregameController(this.g);

  final RxBool open = false.obs;
  final RxInt level = 0.obs;
  final RxBool useMoves = false.obs; // tiêu 1 booster +10 lượt khi vào
  final RxBool armHammer = false.obs; // vào màn với búa sẵn sàng

  /// Có booster nào để chọn không (nếu không → bỏ qua panel, vào thẳng).
  bool get hasAny => g.boosterMoves.value > 0 || g.boosterHammer.value > 0;

  void openFor(int index) {
    level.value = index;
    useMoves.value = false;
    armHammer.value = false;
    open.value = true;
  }

  void close() => open.value = false;

  void toggleMoves() {
    if (g.boosterMoves.value > 0) useMoves.value = !useMoves.value;
  }

  void toggleHammer() {
    if (g.boosterHammer.value > 0) armHammer.value = !armHammer.value;
  }

  /// Vào màn với lựa chọn đã set (ghi cờ pending cho GameScreenController).
  void start() {
    open.value = false;
    g.pendingMovesBoost = useMoves.value;
    g.pendingArmHammer = armHammer.value;
  }
}

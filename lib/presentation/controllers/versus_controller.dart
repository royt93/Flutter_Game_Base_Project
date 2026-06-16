import 'dart:async';

import 'package:get/get.dart';

import '../../data/levels.dart';
import '../../game/neon_jewel_game.dart';
import 'game_controller.dart';

/// Chế độ chơi 2 người cục bộ.
enum VersusMode { versus, coop }

/// Kết cục ván 2 người.
enum VersusOutcome { none, p1, p2, draw, coopWin, coopLose }

/// Điều phối ván 2 người 1 máy (Wave 8.7 — chạy ENGINE Flame như mode thường,
/// nên có đầy đủ juice: particle nổ, gem rơi, cascade, special gem).
///
/// Mỗi người 1 [GameController] versus (KHÔNG đụng tiến trình/xu/mạng) + 1
/// [NeonJewelGame] riêng. Điểm đua trong [roundSeconds] giây; Co-op cộng điểm
/// đạt [coopGoal]. Đồng hồ quyết định kết thúc (engine không tự end).
class VersusController extends GetxController {
  static const int roundSeconds = 60;
  static const int coopGoal = 3000;

  final VersusMode mode;
  VersusController(this.mode);

  late final GameController g1;
  late final GameController g2;
  late final NeonJewelGame game1;
  late final NeonJewelGame game2;

  final RxInt timeLeft = roundSeconds.obs;
  final RxBool running = false.obs;
  final RxBool finished = false.obs;
  final Rx<VersusOutcome> outcome = VersusOutcome.none.obs;

  Timer? _timer;

  /// Combo tối thiểu để bắt đầu gửi rác; combo 3 → 1 hàng, 4 → 2 hàng…
  static const int _junkThreshold = 3;

  @override
  void onInit() {
    super.onInit();
    // CÙNG 1 seed cho 2 bàn → khởi đầu layout y hệt (mirror, công bằng: bỏ may
    // rủi mở bàn). Sau vài nước 2 bàn vẫn rẽ nhánh vì lấp đầy phụ thuộc nước đi.
    final seed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
    g1 = Get.put(GameController(versus: true), tag: 'vp1');
    g2 = Get.put(GameController(versus: true), tag: 'vp2');
    game1 = _build(g1, 1, seed);
    game2 = _build(g2, 2, seed);
    // đóng băng tới khi đếm ngược xong
    game1.setInputFrozen(true);
    game2.setInputFrozen(true);
  }

  NeonJewelGame _build(GameController g, int player, int seed) {
    final cfg = buildVersusLevel();
    return NeonJewelGame(
      controller: g,
      rows: cfg.rows,
      cols: cfg.cols,
      colorCount: cfg.colorCount,
      onGameEnd: (_) {}, // versus không kết thúc qua engine
      muteSfx: true, // tắt SFX 2 bàn → không chồng âm (giữ juice hình)
      onMoveResolved: (combo) => _onCombo(player, combo),
      boardSeed: seed, // 2 bàn chung seed → mirror mở bàn
    );
  }

  /// Người [player] vừa ghép xong combo: combo lớn (Versus) → gửi rác sang đối thủ.
  void _onCombo(int player, int combo) {
    if (mode != VersusMode.versus) return; // Co-op không tấn công nhau
    if (!running.value || combo < _junkThreshold) return;
    final n = combo - _junkThreshold + 1;
    (player == 1 ? game2 : game1).receiveJunk(n);
  }

  int get score1 => g1.score.value;
  int get score2 => g2.score.value;
  int get combinedScore => score1 + score2;

  /// Bắt đầu ván: mở input 2 bàn + khởi động đồng hồ.
  void start() {
    running.value = true;
    finished.value = false;
    outcome.value = VersusOutcome.none;
    timeLeft.value = roundSeconds;
    game1.setInputFrozen(false);
    game2.setInputFrozen(false);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tickSecond());
  }

  /// 1 nhịp giây (Timer gọi; test gọi trực tiếp).
  void tickSecond() {
    if (!running.value) return;
    if (mode == VersusMode.coop && combinedScore >= coopGoal) {
      outcome.value = VersusOutcome.coopWin;
      finish();
      return;
    }
    if (timeLeft.value > 0) timeLeft.value--;
    if (timeLeft.value <= 0) finish();
  }

  /// Kết thúc ván: đóng băng input + xác định kết cục.
  void finish() {
    if (finished.value) return;
    running.value = false;
    finished.value = true;
    _timer?.cancel();
    game1.setInputFrozen(true);
    game2.setInputFrozen(true);
    if (outcome.value == VersusOutcome.none) {
      if (mode == VersusMode.coop) {
        outcome.value = combinedScore >= coopGoal
            ? VersusOutcome.coopWin
            : VersusOutcome.coopLose;
      } else if (score1 > score2) {
        outcome.value = VersusOutcome.p1;
      } else if (score2 > score1) {
        outcome.value = VersusOutcome.p2;
      } else {
        outcome.value = VersusOutcome.draw;
      }
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    if (Get.isRegistered<GameController>(tag: 'vp1')) {
      Get.delete<GameController>(tag: 'vp1');
    }
    if (Get.isRegistered<GameController>(tag: 'vp2')) {
      Get.delete<GameController>(tag: 'vp2');
    }
    super.onClose();
  }
}

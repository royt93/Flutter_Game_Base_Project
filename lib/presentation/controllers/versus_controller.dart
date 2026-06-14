import 'dart:async';
import 'dart:math';

import 'package:get/get.dart';

import '../../logic/gem_data.dart';
import '../../logic/versus_board.dart';

/// Chế độ chơi 2 người cục bộ.
enum VersusMode { versus, coop }

/// Kết cục ván 2 người.
enum VersusOutcome { none, p1, p2, draw, coopWin, coopLose }

/// Điều phối ván 2 người 1 máy (Wave 8 — signature, OFFLINE thuần).
/// - Versus: 2 bàn độc lập đua điểm trong [roundSeconds] giây; combo lớn → "gửi
///   rác" sang đối thủ.
/// - Co-op: 2 bàn góp điểm vào mục tiêu chung [coopGoal] trước khi hết giờ.
///
/// KHÔNG đụng tới [GameController]/tiến trình (không tốn mạng/xu/save) — hoàn
/// toàn tách biệt. Logic (điểm/rác/winner) test được không cần Timer thật.
class VersusController extends GetxController {
  static const int roundSeconds = 60;
  static const int coopGoal = 3000;

  final VersusMode mode;
  final VersusBoard p1;
  final VersusBoard p2;

  final RxInt score1 = 0.obs;
  final RxInt score2 = 0.obs;
  final RxInt timeLeft = roundSeconds.obs;
  final RxInt moveTick = 0.obs; // bump → board view vẽ lại
  final RxInt junkFlash1 = 0.obs; // báo P1 vừa nhận rác (cho hiệu ứng)
  final RxInt junkFlash2 = 0.obs;
  final RxBool running = false.obs;
  final RxBool finished = false.obs;
  final Rx<VersusOutcome> outcome = VersusOutcome.none.obs;

  Timer? _timer;

  VersusController(this.mode, {Random? rnd1, Random? rnd2})
      : p1 = VersusBoard(rnd: rnd1),
        p2 = VersusBoard(rnd: rnd2);

  int get combinedScore => score1.value + score2.value;

  /// Bắt đầu ván + khởi động đồng hồ thực (1 giây/tick).
  void start() {
    running.value = true;
    finished.value = false;
    outcome.value = VersusOutcome.none;
    timeLeft.value = roundSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tickSecond());
  }

  /// 1 nhịp giây (Timer gọi; test gọi trực tiếp để khỏi cần đồng hồ thật).
  void tickSecond() {
    if (!running.value) return;
    if (timeLeft.value > 0) timeLeft.value--;
    if (timeLeft.value <= 0) finish();
  }

  /// Người chơi [player] (1|2) swap 2 ô kề. Trả về true nếu hợp lệ.
  bool playerSwap(int player, Cell a, Cell b) {
    if (!running.value) return false;
    final me = player == 1 ? p1 : p2;
    final foe = player == 1 ? p2 : p1;
    final res = me.swap(a, b);
    if (!res.valid) return false;
    if (player == 1) {
      score1.value = me.score;
    } else {
      score2.value = me.score;
    }
    if (mode == VersusMode.versus && res.junkToSend > 0) {
      foe.receiveJunk(res.junkToSend);
      if (player == 1) {
        junkFlash2.value += res.junkToSend;
      } else {
        junkFlash1.value += res.junkToSend;
      }
    }
    if (mode == VersusMode.coop && combinedScore >= coopGoal) {
      outcome.value = VersusOutcome.coopWin;
      finish();
    }
    moveTick.value++;
    return true;
  }

  /// Kết thúc ván + xác định kết cục (nếu chưa đặt).
  void finish() {
    if (finished.value) return;
    running.value = false;
    finished.value = true;
    _timer?.cancel();
    if (outcome.value == VersusOutcome.none) {
      if (mode == VersusMode.coop) {
        outcome.value = combinedScore >= coopGoal
            ? VersusOutcome.coopWin
            : VersusOutcome.coopLose;
      } else if (score1.value > score2.value) {
        outcome.value = VersusOutcome.p1;
      } else if (score2.value > score1.value) {
        outcome.value = VersusOutcome.p2;
      } else {
        outcome.value = VersusOutcome.draw;
      }
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}

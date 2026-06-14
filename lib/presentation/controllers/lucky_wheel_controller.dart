import 'dart:async';
import 'dart:math';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
import '../../data/wheel.dart';
import 'game_controller.dart';

/// Vòng quay may mắn — quay miễn phí 1 lần/ngày (offline).
class LuckyWheelController extends GetxController {
  final GameController g;
  LuckyWheelController(this.g);

  final StorageService _store = StorageService.to;

  final RxBool open = false.obs;
  final RxBool spinning = false.obs;
  final RxInt resultIndex = (-1).obs; // ô trúng (-1 = chưa quay)

  /// Bộ sinh ngẫu nhiên — inject được để test xác định.
  Random rng = Random();

  /// Còn lượt quay miễn phí hôm nay?
  bool get canSpin =>
      _store.getInt(StorageKeys.wheelLastSpin, def: -1) != g.todayEpochDay;

  void openWheel() {
    resultIndex.value = -1;
    open.value = true;
  }

  void closeWheel() => open.value = false;

  /// Quay: chọn ô, tiêu lượt ngày, trao thưởng ngay. Trả về index ô trúng
  /// (-1 nếu không quay được).
  int spin() {
    if (!canSpin || spinning.value) return -1;
    final idx = rng.nextInt(kWheel.length);
    resultIndex.value = idx;
    spinning.value = true;
    // Ghi mốc "đã quay hôm nay" TRƯỚC khi trao thưởng → chặn quay lại exploit.
    unawaited(_store.setInt(StorageKeys.wheelLastSpin, g.todayEpochDay));
    _applyReward(kWheel[idx]);
    return idx;
  }

  void _applyReward(WheelSlice s) {
    switch (s.kind) {
      case WheelKind.coins:
        g.addCoins(s.amount);
        break;
      case WheelKind.hammer:
        g.grantHammer(s.amount);
        break;
      case WheelKind.moves:
        g.grantMovesBooster(s.amount);
        break;
      case WheelKind.bomb:
        g.grantBomb(s.amount);
        break;
      case WheelKind.swap:
        g.grantSwap(s.amount);
        break;
    }
  }

  /// View gọi khi animation xoay xong (chỉ tắt cờ spinning — thưởng đã trao).
  void finishSpin() => spinning.value = false;
}

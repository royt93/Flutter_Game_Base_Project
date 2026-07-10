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

  static LuckyWheelController? get maybe =>
      Get.isRegistered<LuckyWheelController>()
      ? Get.find<LuckyWheelController>()
      : null;

  /// W28.3 — pity chống chuỗi vận đen: liên tiếp ra "xu" đủ ngưỡng → lần quay
  /// kế được đảm bảo booster. Streak tính XUYÊN NGÀY (persisted), chỉ reset
  /// khi ra booster. Silent — không UI báo trước (giống DDA campaign).
  static const int kWheelPityStreak = 3;
  final RxInt coinStreak = 0.obs;

  @override
  void onInit() {
    super.onInit();
    coinStreak.value = _store.getInt(StorageKeys.wheelCoinStreak, def: 0);
  }

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
    final forceBooster = coinStreak.value >= kWheelPityStreak;
    final idx = forceBooster ? _pickBoosterIndex() : rng.nextInt(kWheel.length);
    resultIndex.value = idx;
    spinning.value = true;
    // Ghi mốc "đã quay hôm nay" TRƯỚC khi trao thưởng → chặn quay lại exploit.
    unawaited(_store.setInt(StorageKeys.wheelLastSpin, g.todayEpochDay));
    coinStreak.value = kWheel[idx].isCoins ? coinStreak.value + 1 : 0;
    unawaited(_store.setInt(StorageKeys.wheelCoinStreak, coinStreak.value));
    _applyReward(kWheel[idx]);
    return idx;
  }

  int _pickBoosterIndex() {
    final boosterIdxs = [
      for (var i = 0; i < kWheel.length; i++)
        if (!kWheel[i].isCoins) i,
    ];
    return boosterIdxs[rng.nextInt(boosterIdxs.length)];
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

  /// Xoá state in-memory khi reset tiến trình (đĩa đã được xoá riêng).
  void resetState() {
    coinStreak.value = 0;
    open.value = false;
    spinning.value = false;
    resultIndex.value = -1;
  }
}

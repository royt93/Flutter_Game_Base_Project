import 'dart:async';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
import 'game_controller.dart';

/// Heo đất (Wave 14) — mỗi màn thắng bỏ ống 1 ít xu (cap [kPiggyCap]); khi đạt
/// [kPiggyMin] có thể đập nhận toàn bộ. Coin-sink/giữ chân (hook IAP sau).
class PiggyController extends GetxController {
  final GameController g;
  PiggyController(this.g);

  final StorageService _store = StorageService.to;

  /// Trần ống heo (đầy thì thôi tích).
  static const int kPiggyCap = 600;

  /// Tối thiểu để được đập.
  static const int kPiggyMin = 120;

  final RxInt saved = 0.obs;

  static PiggyController? get maybe =>
      Get.isRegistered<PiggyController>() ? Get.find<PiggyController>() : null;

  @override
  void onInit() {
    super.onInit();
    saved.value = _store.getInt(StorageKeys.piggySaved, def: 0);
  }

  /// Xu bỏ ống khi thắng 1 màn: nền 6 + 4 mỗi sao.
  static int depositForWin(int stars) => 6 + stars * 4;

  bool get isFull => saved.value >= kPiggyCap;
  bool get canSmash => saved.value >= kPiggyMin;
  double get progress => (saved.value / kPiggyCap).clamp(0.0, 1.0);

  /// Bỏ ống khi thắng (gọi từ GameScreenController; clamp ở cap).
  void addWin(int stars) {
    if (isFull) return;
    saved.value = (saved.value + depositForWin(stars)).clamp(0, kPiggyCap);
    unawaited(_store.setInt(StorageKeys.piggySaved, saved.value));
  }

  void resetState() {
    saved.value = 0;
  }

  /// Đập heo → cộng toàn bộ xu đang tích vào ví, làm rỗng ống. Trả về số xu nhận.
  /// Đập lúc ống ĐẦY (isFull) thưởng thêm 10% (khuyến khích chờ đầy mới đập).
  int smash() {
    if (!canSmash) return 0;
    final base = saved.value;
    final bonus = isFull ? (base * 0.10).round() : 0;
    final amount = base + bonus;
    saved.value = 0;
    unawaited(_store.setInt(StorageKeys.piggySaved, 0));
    g.addCoins(amount);
    return amount;
  }
}

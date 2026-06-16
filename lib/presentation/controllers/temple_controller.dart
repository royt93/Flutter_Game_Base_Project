import 'dart:async';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
import '../../data/temple.dart';
import 'game_controller.dart';

/// Quản lý tiến trình xây "Đền Neon" (Wave 7 — meta ngoài lưới).
class TempleController extends GetxController {
  final GameController g;
  TempleController(this.g);

  final StorageService _store = StorageService.to;

  /// id hạng mục → tier đã xây (0 = chưa xây). Reactive cho UI.
  final RxMap<String, int> builtTier = <String, int>{}.obs;

  /// Hạng mục đang chọn trên màn đền (rỗng = chưa chọn).
  final RxString selectedId = ''.obs;

  static TempleController? get maybe =>
      Get.isRegistered<TempleController>() ? Get.find<TempleController>() : null;

  void select(String id) => selectedId.value = id;

  /// Đặt lại tier đã xây in-memory về 0 khi reset tiến trình (controller permanent).
  void resetState() {
    selectedId.value = '';
    for (final n in kTempleNodes) {
      builtTier[n.id] = 0;
    }
  }

  @override
  void onInit() {
    super.onInit();
    for (final n in kTempleNodes) {
      builtTier[n.id] = _store.getInt(StorageKeys.templeTier(n.id), def: 0);
    }
  }

  int tierOf(TempleNode n) => builtTier[n.id] ?? 0;

  bool isMaxed(TempleNode n) => tierOf(n) >= n.maxTier;

  /// Tier kế tiếp cần xây (null nếu đã max).
  TempleTier? nextTier(TempleNode n) {
    final t = tierOf(n);
    return t < n.maxTier ? n.tiers[t] : null;
  }

  /// Đủ xu để xây tier kế? (Wave 9: gộp tiền tệ — Đền Neon nay tiêu xu.)
  bool canBuild(TempleNode n) {
    final t = nextTier(n);
    return t != null && g.coins.value >= t.cost;
  }

  /// Tổng số tier đã xây / tổng tier (cho thanh tiến trình toàn đền).
  int get builtCount =>
      kTempleNodes.fold(0, (s, n) => s + tierOf(n));
  int get totalCount =>
      kTempleNodes.fold(0, (s, n) => s + n.maxTier);

  double get progress => totalCount == 0 ? 0 : builtCount / totalCount;

  /// Xây tier kế của hạng mục. Trả về true nếu thành công (đã trừ xu + thưởng xu).
  bool build(TempleNode n) {
    final t = nextTier(n);
    if (t == null) return false; // đã max
    if (!g.spendCoins(t.cost)) return false; // thiếu xu
    final newTier = tierOf(n) + 1;
    builtTier[n.id] = newTier;
    unawaited(_store.setInt(StorageKeys.templeTier(n.id), newTier));
    // Thưởng xu mốc xây xong (vòng lặp: chơi → xu → xây → có thêm xu).
    if (t.rewardCoins > 0) g.addCoins(t.rewardCoins);
    return true;
  }
}

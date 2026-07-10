import 'dart:async';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
import '../../data/puzzles.dart';
import 'game_controller.dart';

/// W19.2 — Tiến trình Cấu đố: sao tốt nhất từng cấu đố + mở khoá tuần tự +
/// hoàn thành toàn bộ (badge). Permanent controller → RAM tự clear khi reset
/// (xem [[reset-permanent-controllers]]). KHÔNG đụng tiến trình campaign.
class PuzzleController extends GetxController {
  final GameController g;
  PuzzleController(this.g);

  final StorageService _store = StorageService.to;

  /// id cấu đố → sao tốt nhất (1..3).
  final RxMap<int, int> stars = <int, int>{}.obs;

  /// id cấu đố cao nhất đã MỞ KHOÁ (1-based). Mặc định 1 (cấu đố đầu luôn mở).
  final RxInt unlocked = 1.obs;

  /// W28.1 — Bật/tắt biến thể khó cho cấu đố cuối (id 8). KHÔNG persist —
  /// chọn lại mỗi ván, giống cách chọn trước khi bắt đầu.
  final RxBool hardVariantOn = false.obs;

  /// Biến thể khó chỉ mở khi đã đạt 3 sao ở cấu đố cuối (id 8).
  bool get hardVariantUnlocked => (stars[kPuzzles.length] ?? 0) >= 3;

  static PuzzleController? get maybe => Get.isRegistered<PuzzleController>()
      ? Get.find<PuzzleController>()
      : null;

  @override
  void onInit() {
    super.onInit();
    _loadFromStore();
  }

  void _loadFromStore() {
    for (final p in kPuzzles) {
      final s = _store.getInt(StorageKeys.puzzleStars(p.id), def: 0);
      if (s > 0) stars[p.id] = s;
    }
    unlocked.value = _store
        .getInt(StorageKeys.puzzleUnlocked, def: 1)
        .clamp(1, kPuzzles.length);
  }

  void resetState() {
    stars.clear();
    unlocked.value = 1;
  }

  bool isUnlocked(int id) => id <= unlocked.value;
  int starsOf(int id) => stars[id] ?? 0;
  bool isSolved(int id) => starsOf(id) > 0;

  /// Số cấu đố đã giải.
  int get solvedCount => kPuzzles.where((p) => isSolved(p.id)).length;

  /// Đã giải HẾT (badge "Nhà chiến lược").
  bool get allSolved => solvedCount == kPuzzles.length;

  /// Ghi nhận THẮNG cấu đố [id] với [starsEarned]: lưu sao tốt nhất + mở khoá kế.
  void recordWin(int id, int starsEarned) {
    final prev = stars[id] ?? 0;
    if (starsEarned > prev) {
      stars[id] = starsEarned;
      unawaited(_store.setInt(StorageKeys.puzzleStars(id), starsEarned));
    }
    // Mở khoá cấu đố kế tiếp (chỉ khi vừa giải cái đang ở mép mở khoá).
    if (id == unlocked.value && id < kPuzzles.length) {
      unlocked.value = id + 1;
      unawaited(_store.setInt(StorageKeys.puzzleUnlocked, unlocked.value));
    }
  }
}

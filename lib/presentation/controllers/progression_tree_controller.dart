import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/cosmetics.dart';
import 'package:neon_jewels/data/progression_tree.dart';
import 'package:neon_jewels/data/side_mode_records.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/side_mode_record_controller.dart';

/// Wave 20.3 — Cây tiến trình meta (Progression Tree).
/// Đọc tổng sao + số Gold Milestone để mở khoá nodes.
class ProgressionTreeController extends GetxController {
  final GameController _g;
  ProgressionTreeController(this._g);

  static ProgressionTreeController? get maybe =>
      Get.isRegistered<ProgressionTreeController>()
      ? Get.find<ProgressionTreeController>()
      : null;

  final RxSet<String> unlockedNodes = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    final store = StorageService.to;
    for (final n in kPtNodes) {
      if (store.getInt(StorageKeys.ptUnlocked(n.id)) == 1) {
        unlockedNodes.add(n.id);
      }
    }
    _applyEffects();
  }

  bool isUnlocked(String nodeId) => unlockedNodes.contains(nodeId);

  /// Gọi sau mỗi ván kết thúc — kiểm tra node mới có mở khoá không.
  void checkAndUnlock() {
    final stars = _g.totalStars;
    final goldCount = goldMilestonesCount();
    final platinumCount = platinumMilestonesCount();

    bool newUnlock = false;
    final store = StorageService.to;
    for (final n in kPtNodes) {
      if (unlockedNodes.contains(n.id)) continue;
      final met = n.starCost > 0
          ? stars >= n.starCost
          : n.platinumCost > 0
          ? platinumCount >= n.platinumCost
          : goldCount >= n.goldCost;
      if (met) {
        unlockedNodes.add(n.id);
        store.setInt(StorageKeys.ptUnlocked(n.id), 1);
        newUnlock = true;
      }
    }
    if (newUnlock) _applyEffects();
  }

  /// Áp hiệu ứng visual theo nodes đã mở khoá.
  void _applyEffects() {
    if (unlockedNodes.contains('ascendant')) {
      ActiveCosmetics.particleBurstMultiplier = 2.5;
    } else if (unlockedNodes.contains('blazing')) {
      ActiveCosmetics.particleBurstMultiplier = 2.0;
    } else if (unlockedNodes.contains('radiant')) {
      ActiveCosmetics.particleBurstMultiplier = 1.5;
    } else {
      ActiveCosmetics.particleBurstMultiplier = 1.0;
    }
    if (unlockedNodes.contains('prestige')) {
      ActiveCosmetics.prestigeUnlocked = true;
    }
  }

  void resetState() {
    unlockedNodes.clear();
    ActiveCosmetics.particleBurstMultiplier = 1.0;
    ActiveCosmetics.prestigeUnlocked = false;
    final store = StorageService.to;
    for (final n in kPtNodes) {
      store.remove(StorageKeys.ptUnlocked(n.id));
    }
  }

  int get totalStars => _g.totalStars;

  int goldMilestonesCount() {
    final recCtrl = SideModeRecordController.maybe;
    if (recCtrl == null) return 0;
    return recCtrl.claimedTier.values
        .where((t) => t >= RecordTier.gold.index)
        .length;
  }

  /// W25.3 — số mode phụ đã đạt mốc Platinum (mở node `ascendant`).
  int platinumMilestonesCount() {
    final recCtrl = SideModeRecordController.maybe;
    if (recCtrl == null) return 0;
    return recCtrl.claimedTier.values
        .where((t) => t >= RecordTier.platinum.index)
        .length;
  }
}

import 'dart:async';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
import '../../data/collection.dart';
import 'game_controller.dart';

/// Album sưu tập (Wave 14, đổi vai W18.2) — điểm tích luỹ VĨNH VIỄN; mở ô khi
/// đạt mốc. W18.2: sticker là VẬT SƯU TẬP (claim = "thu thập", KHÔNG thưởng xu);
/// hoàn tất CẢ BỘ → thưởng LỚN 1 lần (skin gem độc quyền + xu).
/// Permanent controller (không tự mất khi reset đĩa → cần [resetState]).
class CollectionController extends GetxController {
  final GameController g;
  CollectionController(this.g);

  final StorageService _store = StorageService.to;

  final RxInt points = 0.obs;
  final RxSet<String> claimed = <String>{}.obs; // id sticker đã thu thập
  final RxBool setRewardClaimed = false.obs; // đã nhận thưởng hoàn tất bộ chưa

  /// Mốc thưởng giữa chừng (W28.3): 25/50/75% số sticker → xu nhỏ, tạo động
  /// lực dù chưa hoàn tất cả bộ.
  static const List<int> kCollectionMilestoneCounts = [3, 6, 9];
  static const List<int> kCollectionMilestoneCoins = [40, 80, 120];
  final RxSet<int> milestonesClaimed = <int>{}.obs; // tier 0/1/2

  static CollectionController? get maybe =>
      Get.isRegistered<CollectionController>()
      ? Get.find<CollectionController>()
      : null;

  @override
  void onInit() {
    super.onInit();
    points.value = _store.getInt(StorageKeys.collectionPoints, def: 0);
    claimed.clear();
    for (final it in kCollectionItems) {
      if (_store.getInt(StorageKeys.collectionClaimed(it.id)) == 1) {
        claimed.add(it.id);
      }
    }
    setRewardClaimed.value =
        _store.getInt(StorageKeys.collectionSetClaimed) == 1;
    milestonesClaimed.clear();
    for (var t = 0; t < kCollectionMilestoneCounts.length; t++) {
      if (_store.getInt(StorageKeys.collectionMilestoneClaimed(t)) == 1) {
        milestonesClaimed.add(t);
      }
    }
  }

  bool isReached(int i) => points.value >= kCollectionItems[i].threshold;
  bool isClaimed(int i) => claimed.contains(kCollectionItems[i].id);
  bool canClaim(int i) => isReached(i) && !isClaimed(i);

  int get unlockedCount => claimed.length;
  int get totalCount => kCollectionItems.length;

  /// Đã thu thập HẾT sticker.
  bool get allCollected => claimed.length == kCollectionItems.length;

  /// Có thể nhận thưởng hoàn tất bộ (đủ sticker + chưa nhận).
  bool get canClaimSet => allCollected && !setRewardClaimed.value;

  /// Badge Home: còn sticker thu được, còn mốc/thưởng bộ chưa nhận.
  bool get hasClaimable =>
      Iterable<int>.generate(kCollectionItems.length).any(canClaim) ||
      canClaimSet ||
      Iterable<int>.generate(
        kCollectionMilestoneCounts.length,
      ).any(canClaimMilestone);

  /// Cộng điểm album khi thắng (gọi từ GameScreenController; chỉ màn thường).
  void addWin(int stars) {
    points.value += collectionPointsForWin(stars);
    unawaited(_store.setInt(StorageKeys.collectionPoints, points.value));
  }

  /// Xoá state in-memory khi reset tiến trình (đĩa đã được xoá riêng).
  void resetState() {
    points.value = 0;
    claimed.clear();
    setRewardClaimed.value = false;
    milestonesClaimed.clear();
  }

  bool canClaimMilestone(int tier) =>
      unlockedCount >= kCollectionMilestoneCounts[tier] &&
      !milestonesClaimed.contains(tier);

  /// Nhận thưởng mốc giữa chừng (W28.3): xu nhỏ theo tier 0/1/2.
  bool claimMilestone(int tier) {
    if (!canClaimMilestone(tier)) return false;
    milestonesClaimed.add(tier);
    unawaited(_store.setInt(StorageKeys.collectionMilestoneClaimed(tier), 1));
    g.addCoins(kCollectionMilestoneCoins[tier]);
    return true;
  }

  /// Thu thập sticker (W18.2: KHÔNG thưởng xu — vật sưu tập thuần).
  bool claim(int i) {
    if (!canClaim(i)) return false;
    final it = kCollectionItems[i];
    claimed.add(it.id);
    unawaited(_store.setInt(StorageKeys.collectionClaimed(it.id), 1));
    return true;
  }

  /// Nhận thưởng HOÀN TẤT BỘ (1 lần): mở skin gem độc quyền + xu.
  /// Nếu skin đã sở hữu từ Shop → bù đắp [kCollectionSetSkinPrice] xu thay thế.
  /// Ghi cờ TRƯỚC khi trao (anti-double).
  bool claimSetReward() {
    if (!canClaimSet) return false;
    setRewardClaimed.value = true;
    unawaited(_store.setInt(StorageKeys.collectionSetClaimed, 1));
    if (g.isSkinOwned(kCollectionSetSkin)) {
      // Đã mua skin từ Shop → cộng xu bù (bằng giá skin) thay vì silent-skip.
      g.addCoins(kCollectionSetSkinPrice);
    } else {
      g.grantSkin(kCollectionSetSkin);
      g.addCoins(kCollectionSetCoins);
    }
    return true;
  }
}

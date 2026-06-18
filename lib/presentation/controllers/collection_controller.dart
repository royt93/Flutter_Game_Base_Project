import 'dart:async';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
import '../../data/battle_pass.dart' show RewardKind;
import '../../data/collection.dart';
import 'game_controller.dart';

/// Album sưu tập (Wave 14) — điểm tích luỹ VĨNH VIỄN; mở ô khi đạt mốc.
/// Permanent controller (không tự mất khi reset đĩa → cần [resetState]).
class CollectionController extends GetxController {
  final GameController g;
  CollectionController(this.g);

  final StorageService _store = StorageService.to;

  final RxInt points = 0.obs;
  final RxSet<String> claimed = <String>{}.obs; // id sticker đã mở

  static CollectionController? get maybe => Get.isRegistered<CollectionController>()
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
  }

  bool isReached(int i) => points.value >= kCollectionItems[i].threshold;
  bool isClaimed(int i) => claimed.contains(kCollectionItems[i].id);
  bool canClaim(int i) => isReached(i) && !isClaimed(i);
  bool get hasClaimable =>
      List.generate(kCollectionItems.length, (i) => i).any(canClaim);

  int get unlockedCount => claimed.length;
  int get totalCount => kCollectionItems.length;

  /// Cộng điểm album khi thắng (gọi từ GameScreenController; chỉ màn thường).
  void addWin(int stars) {
    points.value += collectionPointsForWin(stars);
    unawaited(_store.setInt(StorageKeys.collectionPoints, points.value));
  }

  /// Xoá state in-memory khi reset tiến trình (đĩa đã được xoá riêng).
  void resetState() {
    points.value = 0;
    claimed.clear();
  }

  bool claim(int i) {
    if (!canClaim(i)) return false;
    final it = kCollectionItems[i];
    claimed.add(it.id);
    unawaited(_store.setInt(StorageKeys.collectionClaimed(it.id), 1));
    switch (it.kind) {
      case RewardKind.coins:
        g.addCoins(it.amount);
        break;
      case RewardKind.hammer:
        g.grantHammer(it.amount);
        break;
      case RewardKind.moves:
        g.grantMovesBooster(it.amount);
        break;
      case RewardKind.color:
        g.grantColor(it.amount);
        break;
      case RewardKind.joker:
        g.grantJoker(it.amount);
        break;
      case RewardKind.lightning:
        g.grantLightning(it.amount);
        break;
      case RewardKind.royal:
        g.grantRoyal(it.amount);
        break;
      case RewardKind.gravity:
        g.grantGravity(it.amount);
        break;
    }
    return true;
  }
}

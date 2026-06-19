import 'dart:async';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
import '../../core/utils/format.dart';
import '../../data/battle_pass.dart' show RewardKind;
import '../../data/season.dart';
import 'game_controller.dart';

/// Sự kiện theo mùa (Wave 7, offline). Tích điểm khi thắng → mở mốc thưởng.
/// Điểm reset khi sang mùa mới; cờ đã-nhận keyed tuyệt đối theo (mùa, mốc).
class SeasonController extends GetxController {
  final GameController g;
  SeasonController(this.g);

  final StorageService _store = StorageService.to;

  final RxInt points = 0.obs;
  final RxSet<String> claimed = <String>{}.obs; // "idx_m"

  static SeasonController? get maybe =>
      Get.isRegistered<SeasonController>() ? Get.find<SeasonController>() : null;

  @override
  void onInit() {
    super.onInit();
    _refresh();
  }

  int get idx => seasonIndex(g.todayEpochDay);

  /// Đồng bộ điểm với mùa hiện tại (reset khi đổi mùa) + nạp cờ đã nhận.
  void _refresh() {
    final cur = idx;
    final storedIdx = _store.getInt(StorageKeys.seasonIdx, def: -1);
    if (storedIdx != cur) {
      points.value = 0;
      unawaited(_store.setInt(StorageKeys.seasonPoints, 0));
      unawaited(_store.setInt(StorageKeys.seasonIdx, cur));
    } else {
      points.value = _store.getInt(StorageKeys.seasonPoints, def: 0);
    }
    claimed.clear();
    for (int m = 0; m < kSeasonMilestones.length; m++) {
      if (_store.getInt(StorageKeys.seasonClaimed(cur, m)) == 1) {
        claimed.add('${cur}_$m');
      }
    }
  }

  String seasonName() => seasonNameKey(idx).tr;
  int get worldAccent => seasonWorldAccent(idx);

  /// Thời gian còn lại tới khi hết mùa (mốc = nửa đêm giờ máy, không lệch múi
  /// giờ — xem [durationToLocalMidnight]).
  Duration get timeToEnd {
    final today = g.todayEpochDay;
    final daysLeft = seasonEndDay(today) - today;
    return durationToLocalMidnight(g.clock(), daysLeft);
  }

  bool isReached(int m) => points.value >= kSeasonMilestones[m].points;
  bool isClaimed(int m) => claimed.contains('${idx}_$m');
  bool canClaim(int m) => isReached(m) && !isClaimed(m);
  bool get hasClaimable =>
      List.generate(kSeasonMilestones.length, (m) => m).any(canClaim);

  /// Cộng điểm mùa khi thắng (gọi từ GameScreenController; Endless không tính).
  void addWin(int stars) {
    _ensureSeason();
    points.value += seasonPointsForWin(stars);
    unawaited(_store.setInt(StorageKeys.seasonPoints, points.value));
  }

  void _ensureSeason() {
    if (_store.getInt(StorageKeys.seasonIdx, def: -1) != idx) _refresh();
  }

  /// Xoá sạch state in-memory khi reset tiến trình (xem [BattlePassController.resetState]).
  void resetState() {
    points.value = 0;
    claimed.clear();
    _refresh(); // đĩa đã trống → đặt lại mùa hiện tại từ 0 điểm
  }

  bool claim(int m) {
    if (!canClaim(m)) return false;
    claimed.add('${idx}_$m');
    unawaited(_store.setInt(StorageKeys.seasonClaimed(idx, m), 1));
    final ms = kSeasonMilestones[m];
    switch (ms.kind) {
      case RewardKind.coins:
        g.addCoins(ms.amount);
        break;
      case RewardKind.hammer:
        g.grantHammer(ms.amount);
        break;
      case RewardKind.moves:
        g.grantMovesBooster(ms.amount);
        break;
      case RewardKind.color:
        g.grantColor(ms.amount);
        break;
      case RewardKind.joker:
        g.grantJoker(ms.amount);
        break;
      case RewardKind.lightning:
        g.grantLightning(ms.amount);
        break;
      case RewardKind.royal:
        g.grantRoyal(ms.amount);
        break;
      case RewardKind.gravity:
        g.grantGravity(ms.amount);
        break;
    }
    return true;
  }
}

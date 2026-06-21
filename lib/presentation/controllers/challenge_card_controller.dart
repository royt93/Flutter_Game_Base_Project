import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/challenge_cards.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';

/// Wave 20.3 — Challenge Card: 3 thử thách tất định mỗi tuần.
class ChallengeCardController extends GetxController {
  final GameController _g;
  ChallengeCardController(this._g);

  static ChallengeCardController? get maybe =>
      Get.isRegistered<ChallengeCardController>()
          ? Get.find<ChallengeCardController>()
          : null;

  late int _weekIdx;
  late List<ChallengeCard> challenges;

  final RxList<int> progress = <int>[0, 0, 0].obs;
  final RxList<bool> claimed = <bool>[false, false, false].obs;

  /// Số thử thách chưa claim có thể claim.
  bool get hasClaimable => List.generate(3, (i) =>
    !claimed[i] && progress[i] >= challenges[i].target).any((b) => b);

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    final today = _g.todayEpochDay;
    _weekIdx = today ~/ 7;
    challenges = buildWeeklyChallenges(_weekIdx);

    final store = StorageService.to;
    final savedWeek = store.getInt(StorageKeys.ccWeekIdx, def: -1);
    if (savedWeek != _weekIdx) {
      // Tuần mới — reset tiến trình
      _resetDisk();
    } else {
      for (int i = 0; i < 3; i++) {
        progress[i] = store.getInt(StorageKeys.ccProgress(i));
        claimed[i] = store.getInt(StorageKeys.ccClaimed(i)) == 1;
      }
    }
  }

  void _resetDisk() {
    final store = StorageService.to;
    store.setInt(StorageKeys.ccWeekIdx, _weekIdx);
    for (int i = 0; i < 3; i++) {
      progress[i] = 0;
      claimed[i] = false;
      store.setInt(StorageKeys.ccProgress(i), 0);
      store.setInt(StorageKeys.ccClaimed(i), 0);
    }
    // Ghi lại coinsBudget để track "xu kiếm tuần này"
    _store.setInt(StorageKeys.ccCoinsStart, _g.coinsEarnedTotal.value);
  }

  StorageService get _store => StorageService.to;

  /// Gọi sau mỗi win màn campaign thường.
  void onCampaignWin() {
    _refresh();
    for (int i = 0; i < 3; i++) {
      if (claimed[i]) continue;
      if (challenges[i].type == ChallengeType.winCampaign) {
        final newVal = (progress[i] + 1).clamp(0, challenges[i].target);
        if (newVal != progress[i]) {
          progress[i] = newVal;
          _store.setInt(StorageKeys.ccProgress(i), newVal);
        }
      }
    }
  }

  /// Gọi sau mỗi ván side mode kết thúc (dù win/lose).
  void onSideModePlayed(String modeKey) {
    _refresh();
    for (int i = 0; i < 3; i++) {
      if (claimed[i]) continue;
      if (challenges[i].type == ChallengeType.playMode &&
          challenges[i].modeKey == modeKey) {
        final newVal = (progress[i] + 1).clamp(0, challenges[i].target);
        if (newVal != progress[i]) {
          progress[i] = newVal;
          _store.setInt(StorageKeys.ccProgress(i), newVal);
        }
      }
    }
  }

  /// Cập nhật tiến trình earnCoins (so với coins đầu tuần).
  void refreshCoins() {
    _refresh();
    final start = _store.getInt(StorageKeys.ccCoinsStart);
    final earned = (_g.coinsEarnedTotal.value - start).clamp(0, 99999);
    for (int i = 0; i < 3; i++) {
      if (claimed[i]) continue;
      if (challenges[i].type == ChallengeType.earnCoins) {
        final capped = earned.clamp(0, challenges[i].target);
        if (capped != progress[i]) {
          progress[i] = capped;
          _store.setInt(StorageKeys.ccProgress(i), capped);
        }
      }
    }
  }

  /// Đổi sang tuần mới nếu cần (gọi khi mở screen).
  void _refresh() {
    final today = _g.todayEpochDay;
    final currentWeek = today ~/ 7;
    if (currentWeek != _weekIdx) {
      _weekIdx = currentWeek;
      challenges = buildWeeklyChallenges(_weekIdx);
      _resetDisk();
    }
  }

  void claimReward(int i) {
    if (i < 0 || i >= 3) return;
    if (claimed[i]) return;
    if (progress[i] < challenges[i].target) return;
    claimed[i] = true;
    _store.setInt(StorageKeys.ccClaimed(i), 1);
    _g.addCoins(challenges[i].reward);
  }

  void resetState() {
    progress.assignAll([0, 0, 0]);
    claimed.assignAll([false, false, false]);
    final store = StorageService.to;
    store.remove(StorageKeys.ccWeekIdx);
    for (int i = 0; i < 3; i++) {
      store.remove(StorageKeys.ccProgress(i));
      store.remove(StorageKeys.ccClaimed(i));
    }
    store.remove(StorageKeys.ccCoinsStart);
  }
}

import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/challenge_cards.dart';
import 'package:neon_jewels/presentation/controllers/battle_pass_controller.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/side_mode_record_controller.dart';

/// Wave 20.3 — Challenge Card: 3 thử thách tất định mỗi tuần.
/// W25.3 — thêm trục điểm side-mode/tuần + quest kỹ năng `reachRecordTier`.
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

  /// W25.3 — điểm side-mode tích luỹ TUẦN NÀY (mọi side-mode, không riêng
  /// mode có record) + bậc mốc đã nhận (0..3, xem [kSideWeeklyGoals]).
  final RxInt sideWeeklyPoints = 0.obs;
  final RxInt sideMilestoneClaimed = 0.obs;

  /// Số thử thách chưa claim có thể claim.
  bool get hasClaimable => List.generate(
    3,
    (i) => !claimed[i] && progress[i] >= challenges[i].target,
  ).any((b) => b);

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
      sideWeeklyPoints.value = store.getInt(StorageKeys.ccSideWeekPoints);
      sideMilestoneClaimed.value = store.getInt(StorageKeys.ccSideMilestone);
    }
    _refreshRecordTierChallenges();
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
    sideWeeklyPoints.value = 0;
    sideMilestoneClaimed.value = 0;
    store.setInt(StorageKeys.ccSideWeekPoints, 0);
    store.setInt(StorageKeys.ccSideMilestone, 0);
    // Ghi lại coinsBudget để track "xu kiếm tuần này"
    _store.setInt(StorageKeys.ccCoinsStart, _g.coinsEarnedTotal.value);
  }

  /// W25.3 — quest kỹ năng "đạt mốc kỷ lục X ở mode Y": dựa LIFETIME record
  /// (không phải thành tích riêng trong tuần) nên tự "done" ngay khi đủ
  /// trình, không cần chơi lại trong tuần.
  void _refreshRecordTierChallenges() {
    final rec = SideModeRecordController.maybe;
    if (rec == null) return;
    for (int i = 0; i < 3; i++) {
      if (claimed[i]) continue;
      final c = challenges[i];
      if (c.type != ChallengeType.reachRecordTier) continue;
      final met = rec.tierOf(c.recordKind!).index >= c.recordTier!.index;
      final newVal = met ? 1 : 0;
      if (newVal != progress[i]) {
        progress[i] = newVal;
        _store.setInt(StorageKeys.ccProgress(i), newVal);
      }
    }
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

  /// W25.3 — điểm side-mode/tuần: gọi cho MỌI side-mode kết thúc (không chỉ
  /// mode có modeKey/record) — trục nuôi tách biệt campaign, KHÔNG đụng
  /// win-streak/unlock/lives.
  void addSideModePoints({
    required bool won,
    bool reachedNewMilestone = false,
  }) {
    _refresh();
    _refreshRecordTierChallenges();
    if (!won) return;
    var pts = kSideWeeklyPointsPerWin;
    if (reachedNewMilestone) pts += kSideWeeklyPointsPerMilestoneUnlock;
    sideWeeklyPoints.value += pts;
    _store.setInt(StorageKeys.ccSideWeekPoints, sideWeeklyPoints.value);
  }

  int get sideWeeklyGoal =>
      kSideWeeklyGoals[sideMilestoneClaimed.value.clamp(
        0,
        kSideWeeklyGoals.length - 1,
      )];

  bool get sideMilestoneClaimable =>
      sideMilestoneClaimed.value < kSideWeeklyGoals.length &&
      sideWeeklyPoints.value >= sideWeeklyGoal;

  /// Nhận thưởng mốc điểm side-mode/tuần (tối đa 3 mốc/tuần). Ghi guard-key
  /// TRƯỚC khi cộng xu (anti-double, mẫu clan_controller.dart). Kèm bonus XP
  /// nhỏ cho Battle Pass — tách biệt hoàn toàn khỏi gate campaign-only.
  int claimSideMilestone() {
    if (!sideMilestoneClaimable) return 0;
    final reward = kSideWeeklyRewards[sideMilestoneClaimed.value];
    sideMilestoneClaimed.value += 1;
    _store.setInt(StorageKeys.ccSideMilestone, sideMilestoneClaimed.value);
    _g.addCoins(reward);
    BattlePassController.maybe?.grantBonusXp(kSideMilestoneBpBonusXp);
    return reward;
  }

  void resetState() {
    progress.assignAll([0, 0, 0]);
    claimed.assignAll([false, false, false]);
    sideWeeklyPoints.value = 0;
    sideMilestoneClaimed.value = 0;
    final store = StorageService.to;
    store.remove(StorageKeys.ccWeekIdx);
    for (int i = 0; i < 3; i++) {
      store.remove(StorageKeys.ccProgress(i));
      store.remove(StorageKeys.ccClaimed(i));
    }
    store.remove(StorageKeys.ccCoinsStart);
    store.remove(StorageKeys.ccSideWeekPoints);
    store.remove(StorageKeys.ccSideMilestone);
  }
}

import 'dart:async';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
import '../../core/utils/format.dart';
import '../../data/season.dart';
import '../../data/tournament.dart';
import 'game_controller.dart';

/// W18.1 — "Mùa giải" (Season League): GỘP Sự kiện mùa + Giải đấu tuần.
///
/// Trước đây 2 hệ trùng ~70% (cùng earn khi thắng, cùng reset 7 ngày, cùng khuôn
/// claim-mốc). Nay 1 ĐƯỜNG ĐIỂM duy nhất/tuần nuôi 2 TRỤC thưởng KHÔNG trùng:
/// - **Trục MỐC** (track): đạt ngưỡng điểm → mở thưởng theo bậc (vai trò cũ Season).
/// - **Trục HẠNG** (leaderboard): so 7 bot tất định → thưởng hạng (vai trò cũ Tournament).
///
/// Mùa = Tuần = epochDay~/7 (seasonIndex == tournamentWeek). Dùng LẠI key cũ để
/// migrate AN TOÀN (cờ đã-nhận cũ được tôn trọng → chống nhận-lại-thưởng).
class SeasonLeagueController extends GetxController {
  final GameController g;
  SeasonLeagueController(this.g);

  final StorageService _store = StorageService.to;

  final RxInt points = 0.obs; // 1 pool điểm/tuần (dùng key seasonPoints)
  final RxSet<String> claimedMilestones = <String>{}.obs; // "idx_m"
  final RxBool claimedRankThisWeek = false.obs;

  static SeasonLeagueController? get maybe =>
      Get.isRegistered<SeasonLeagueController>()
          ? Get.find<SeasonLeagueController>()
          : null;

  @override
  void onInit() {
    super.onInit();
    _maybeMigrate();
    _refresh();
  }

  /// Mùa/tuần hiện tại (cùng công thức epochDay~/7 cho cả 2 hệ cũ).
  int get idx => seasonIndex(g.todayEpochDay);

  /// Gộp 1 LẦN dữ liệu cũ: pool = max(điểm mùa, điểm giải) của ĐÚNG kỳ hiện tại.
  /// Tôn trọng kỳ cũ (chỉ lấy điểm thuộc kỳ này → không kéo điểm tuần cũ vào).
  void _maybeMigrate() {
    if (_store.getInt(StorageKeys.leagueMigrated, def: 0) == 1) return;
    final cur = idx;
    final sIdxOld = _store.getInt(StorageKeys.seasonIdx, def: -1);
    final tWeekOld = _store.getInt(StorageKeys.tournamentWeek, def: -1);
    var pool = (sIdxOld == cur) ? _store.getInt(StorageKeys.seasonPoints) : 0;
    if (tWeekOld == cur) {
      final tp = _store.getInt(StorageKeys.tournamentPoints);
      if (tp > pool) pool = tp;
    }
    unawaited(_store.setInt(StorageKeys.seasonPoints, pool));
    unawaited(_store.setInt(StorageKeys.seasonIdx, cur));
    unawaited(_store.setInt(StorageKeys.leagueMigrated, 1));
  }

  /// Đồng bộ pool với kỳ hiện tại (reset khi đổi kỳ) + nạp cờ đã nhận (mốc + hạng).
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
    claimedMilestones.clear();
    for (int m = 0; m < kSeasonMilestones.length; m++) {
      if (_store.getInt(StorageKeys.seasonClaimed(cur, m)) == 1) {
        claimedMilestones.add('${cur}_$m');
      }
    }
    claimedRankThisWeek.value =
        _store.getInt(StorageKeys.tournamentClaimedWeek, def: -1) == cur;
  }

  void _ensureKy() {
    if (_store.getInt(StorageKeys.seasonIdx, def: -1) != idx) _refresh();
  }

  String seasonName() => seasonNameKey(idx).tr;
  int get worldAccent => seasonWorldAccent(idx);

  /// Thời gian còn lại tới hết kỳ (nửa đêm giờ máy).
  Duration get timeToEnd {
    final today = g.todayEpochDay;
    final daysLeft = seasonEndDay(today) - today;
    return durationToLocalMidnight(g.clock(), daysLeft);
  }

  /// Cộng điểm khi THẮNG (mọi thắng — như Season cũ). 1 addWin → 1 pool điểm.
  void addWin(int stars) {
    _ensureKy();
    points.value += seasonPointsForWin(stars);
    unawaited(_store.setInt(StorageKeys.seasonPoints, points.value));
  }

  // ─── Trục MỐC (track) ───────────────────────────────────────────────────
  bool isReached(int m) => points.value >= kSeasonMilestones[m].points;
  bool isClaimed(int m) => claimedMilestones.contains('${idx}_$m');
  bool canClaimMilestone(int m) => isReached(m) && !isClaimed(m);

  bool claimMilestone(int m) {
    if (!canClaimMilestone(m)) return false;
    claimedMilestones.add('${idx}_$m');
    unawaited(_store.setInt(StorageKeys.seasonClaimed(idx, m), 1));
    final ms = kSeasonMilestones[m];
    g.grantReward(ms.kind, ms.amount);
    return true;
  }

  // ─── Trục HẠNG (leaderboard) ────────────────────────────────────────────
  int botScoreNow(int i) => botScore(idx, i, kTournamentDays - 1);

  /// Hạng người chơi (1-based): 1 + số bot điểm cao hơn.
  int get playerRank {
    var higher = 0;
    for (int i = 0; i < kTournamentBots.length; i++) {
      if (botScoreNow(i) > points.value) higher++;
    }
    return higher + 1;
  }

  TournamentReward get pendingRankReward => tournamentRewardFor(playerRank);

  /// Nhận thưởng hạng (1 lần/tuần, cần ≥1 điểm).
  bool get canClaimRank => points.value > 0 && !claimedRankThisWeek.value;

  TournamentReward? claimRank() {
    if (!canClaimRank) return null;
    final r = pendingRankReward;
    claimedRankThisWeek.value = true;
    unawaited(_store.setInt(StorageKeys.tournamentClaimedWeek, idx));
    g.grantReward(r.kind, r.amount);
    return r;
  }

  // ─── Tổng hợp (cho badge Home) ──────────────────────────────────────────
  bool get hasClaimable {
    for (int m = 0; m < kSeasonMilestones.length; m++) {
      if (canClaimMilestone(m)) return true;
    }
    return canClaimRank;
  }

  /// Xoá state in-memory khi reset (đĩa đã xoá ở resetProgress TRƯỚC) → KHÔNG
  /// _refresh để khỏi đọc lại; đặt pool 0 + cờ trống cho kỳ hiện tại.
  void resetState() {
    points.value = 0;
    claimedMilestones.clear();
    claimedRankThisWeek.value = false;
  }
}

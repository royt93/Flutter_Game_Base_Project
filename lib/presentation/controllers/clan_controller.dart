import 'dart:async';
import 'package:get/get.dart';
import '../../core/clan_engine.dart';
import '../../core/storage_service.dart';
import '../../data/tournament.dart' show tournamentWeek;
import 'game_controller.dart';

/// Clan/Friends offline (Wave 23). Người chơi + 9 bot (đóng góp tuần tất định).
/// Cả clan góp điểm → đạt [kClanWeeklyGoal] thì mở thưởng (1 lần/tuần, anti-farm).
/// W24.4 — đóng góp người chơi đến từ CẢ campaign (thắng màn, theo sao) LẪN
/// side-mode (thắng, điểm cố định) — hai nguồn cộng chung 1 bộ đếm tuần/lifetime.
/// Permanent controller → cần [resetState] khi resetProgress (chống nhận lại thưởng).
class ClanController extends GetxController {
  final GameController g;
  ClanController(this.g);

  final StorageService _store = StorageService.to;

  static ClanController? get maybe =>
      Get.isRegistered<ClanController>() ? Get.find<ClanController>() : null;

  /// Đóng góp tuần của người chơi (Rx để UI rebuild).
  final RxInt contributionRx = 0.obs;

  /// Tuần đã nhận thưởng mục tiêu (Rx).
  final RxInt rewardWeekRx = (-1).obs;

  int get _week => tournamentWeek(g.todayEpochDay);

  @override
  void onInit() {
    super.onInit();
    contributionRx.value = _loadContribution();
    rewardWeekRx.value = _store.getInt(StorageKeys.clanRewardWeek, def: -1);
    leagueRewardWeekRx.value = _store.getInt(
      StorageKeys.clanLeagueRewardWeek,
      def: -1,
    );
  }

  /// Đọc đóng góp tuần HIỆN TẠI (`'<week>|<pts>'`); tuần cũ → 0.
  int _loadContribution() {
    final raw = _store.getString(StorageKeys.clanPointsWeek);
    if (raw == null) return 0;
    final parts = raw.split('|');
    if (parts.length == 2 && int.tryParse(parts[0]) == _week) {
      return int.tryParse(parts[1]) ?? 0;
    }
    return 0;
  }

  int get playerContribution => contributionRx.value;

  /// Cộng đóng góp clan khi thắng campaign. Đổi tuần → reset nền về 0 trước khi cộng.
  void addContribution(int stars) => _addPoints(clanPointsForWin(stars));

  /// W24.4 — Cộng đóng góp clan khi THẮNG side-mode (Endless/Boss/Survival/...).
  /// Dùng chung bộ đếm tuần + lifetime với [addContribution] (campaign) — chỉ khác
  /// mức điểm cố định (không có sao). KHÔNG đụng win-streak/level-unlock/lives:
  /// gọi độc lập từ nhánh side-mode của `_onGameEnd`, chỉ ghi vào clan.
  void addSideModeContribution() => _addPoints(kClanPointsForSideModeWin);

  void _addPoints(int add) {
    final pts = _loadContribution() + add;
    contributionRx.value = pts;
    unawaited(_store.setString(StorageKeys.clanPointsWeek, '$_week|$pts'));
    // W23 — tích luỹ lifetime cho thành tựu (không reset theo tuần).
    g.clanContribLifetime.value += add;
    unawaited(
      _store.setInt(
        StorageKeys.clanContribLifetime,
        g.clanContribLifetime.value,
      ),
    );
  }

  List<ClanMember> roster() => buildClanRoster(playerContribution, _week);
  int total() => clanTotal(roster());

  /// W23 (sâu hơn) — BXH Clan: clan người chơi (tổng [total]) đấu clan bot tuần này.
  List<ClanStanding> clanLeague() => buildClanLeague(total(), _week);
  int leagueRank() => clanLeagueRank(clanLeague());

  /// Tuần đã nhận thưởng xếp hạng Clan-vs-Clan (Rx).
  final RxInt leagueRewardWeekRx = (-1).obs;

  bool get leagueRewardClaimed => leagueRewardWeekRx.value == _week;

  /// Đủ điều kiện nhận: clan top 3 tuần này + chưa nhận.
  bool get leagueRewardClaimable =>
      clanLeagueRewardFor(leagueRank()) > 0 && !leagueRewardClaimed;

  /// Nhận thưởng xếp hạng (1 lần/tuần). Ghi mốc tuần TRƯỚC (idempotent, anti-cheat
  /// qua todayEpochDay). Trả xu thưởng (0 nếu ngoài top 3 / đã nhận).
  int claimLeagueReward() {
    if (!leagueRewardClaimable) return 0;
    final reward = clanLeagueRewardFor(leagueRank());
    leagueRewardWeekRx.value = _week;
    unawaited(_store.setInt(StorageKeys.clanLeagueRewardWeek, _week));
    g.addCoins(reward);
    return reward;
  }

  bool get weeklyRewardClaimed => rewardWeekRx.value == _week;
  bool get weeklyRewardClaimable =>
      total() >= kClanWeeklyGoal && !weeklyRewardClaimed;

  /// Nhận thưởng mục tiêu tuần (1 lần/tuần). Ghi mốc tuần TRƯỚC (idempotent,
  /// dùng todayEpochDay anti-cheat). Trả xu thưởng (0 nếu chưa đủ ĐK).
  int claimWeeklyReward() {
    if (!weeklyRewardClaimable) return 0;
    rewardWeekRx.value = _week;
    unawaited(_store.setInt(StorageKeys.clanRewardWeek, _week));
    g.addCoins(kClanWeeklyReward);
    return kClanWeeklyReward;
  }

  /// Gọi sau resetProgress (đĩa đã xoá) → về fresh in-memory.
  void resetState() {
    contributionRx.value = 0;
    rewardWeekRx.value = -1;
    leagueRewardWeekRx.value = -1;
  }
}

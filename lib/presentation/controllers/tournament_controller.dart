import 'dart:async';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
import '../../data/battle_pass.dart' show RewardKind;
import '../../data/tournament.dart';
import 'game_controller.dart';

/// Giải đấu tuần (Wave 14) — tích điểm khi thắng, đua hạng với 7 bot tất định.
/// Điểm reset khi sang tuần mới; thưởng theo hạng hiện tại, nhận 1 lần/tuần.
class TournamentController extends GetxController {
  final GameController g;
  TournamentController(this.g);

  final StorageService _store = StorageService.to;

  final RxInt points = 0.obs;
  final RxBool claimedThisWeek = false.obs;

  static TournamentController? get maybe => Get.isRegistered<TournamentController>()
      ? Get.find<TournamentController>()
      : null;

  @override
  void onInit() {
    super.onInit();
    _refresh();
  }

  int get week => tournamentWeek(g.todayEpochDay);

  /// Đồng bộ điểm với tuần hiện tại (reset khi đổi tuần) + nạp cờ đã nhận.
  void _refresh() {
    final cur = week;
    final storedWeek = _store.getInt(StorageKeys.tournamentWeek, def: -1);
    if (storedWeek != cur) {
      points.value = 0;
      unawaited(_store.setInt(StorageKeys.tournamentPoints, 0));
      unawaited(_store.setInt(StorageKeys.tournamentWeek, cur));
    } else {
      points.value = _store.getInt(StorageKeys.tournamentPoints, def: 0);
    }
    claimedThisWeek.value =
        _store.getInt(StorageKeys.tournamentClaimedWeek, def: -1) == cur;
  }

  void _ensureWeek() {
    if (_store.getInt(StorageKeys.tournamentWeek, def: -1) != week) _refresh();
  }

  /// Thời gian còn lại tới khi hết tuần giải.
  Duration get timeToEnd {
    final now = g.clock();
    final endDay = tournamentWeekEnd(g.todayEpochDay);
    final end = DateTime.fromMillisecondsSinceEpoch(endDay * 86400000);
    final ms = end.millisecondsSinceEpoch - now.millisecondsSinceEpoch;
    return ms <= 0 ? Duration.zero : Duration(milliseconds: ms);
  }

  /// Điểm "mục tiêu tuần" của bot [i] — dùng điểm CUỐI TUẦN (cố định cả tuần) làm
  /// thước đo xếp hạng. Wave 14 fix M1: trước đây dùng `dayIntoWeek` → đầu tuần bot
  /// yếu ⇒ ăn hạng 1 + 300 xu quá dễ. Nay bot mạnh full từ ngày 1 (thanh chắn cố
  /// định), người chơi phải đua thật mới lên hạng — đúng tinh thần "thưởng cuối tuần".
  int botScoreNow(int i) => botScore(week, i, kTournamentDays - 1);

  /// Hạng người chơi (1-based): 1 + số bot điểm CAO HƠN người chơi.
  int get playerRank {
    var higher = 0;
    for (int i = 0; i < kTournamentBots.length; i++) {
      if (botScoreNow(i) > points.value) higher++;
    }
    return higher + 1;
  }

  /// Thưởng dự kiến theo hạng hiện tại.
  TournamentReward get pendingReward => tournamentRewardFor(playerRank);

  /// Có thể nhận thưởng tuần này? (đã chơi ít nhất 1 thắng + chưa nhận tuần này)
  bool get canClaim => points.value > 0 && !claimedThisWeek.value;
  bool get hasClaimable => canClaim;

  /// Cộng điểm giải khi thắng (gọi từ GameScreenController; chỉ màn thường).
  void addWin(int stars) {
    _ensureWeek();
    points.value += tournamentPointsForWin(stars);
    unawaited(_store.setInt(StorageKeys.tournamentPoints, points.value));
  }

  /// Xoá state in-memory khi reset tiến trình (đĩa đã được resetProgress xoá
  /// riêng TRƯỚC khi gọi → KHÔNG _refresh để khỏi đọc lại giá trị cũ).
  void resetState() {
    points.value = 0;
    claimedThisWeek.value = false;
  }

  /// Nhận thưởng theo hạng hiện tại (1 lần/tuần). Trả về reward đã trao hoặc null.
  TournamentReward? claim() {
    if (!canClaim) return null;
    final r = pendingReward;
    claimedThisWeek.value = true;
    unawaited(_store.setInt(StorageKeys.tournamentClaimedWeek, week));
    switch (r.kind) {
      case RewardKind.coins:
        g.addCoins(r.amount);
        break;
      case RewardKind.hammer:
        g.grantHammer(r.amount);
        break;
      case RewardKind.moves:
        g.grantMovesBooster(r.amount);
        break;
      case RewardKind.color:
        g.grantColor(r.amount);
        break;
      case RewardKind.joker:
        g.grantJoker(r.amount);
        break;
      case RewardKind.lightning:
        g.grantLightning(r.amount);
        break;
      case RewardKind.royal:
        g.grantRoyal(r.amount);
        break;
      case RewardKind.gravity:
        g.grantGravity(r.amount);
        break;
    }
    return r;
  }
}

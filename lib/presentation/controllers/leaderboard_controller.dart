import 'package:get/get.dart';
import '../../core/leaderboard_engine.dart';
import '../../data/levels.dart';
import '../../data/tournament.dart' show tournamentWeek;
import 'game_controller.dart';

/// Bảng xếp hạng offline (Wave 21.6). Route-scoped (permanent:false) — không
/// persist gì; bot score compute on-the-fly mỗi lần đọc qua [LeaderboardEngine].
/// Tab 0 = Campaign (chọn màn, điểm thật từ [GameController.highScores], chu kỳ tuần),
/// Tab 1 = Daily (seed theo ngày; người chơi ẩn tới khi có cơ chế điểm daily — xem plan).
class LeaderboardController extends GetxController {
  final GameController g;
  LeaderboardController(this.g);

  /// Tab đang xem: 0 = Campaign, 1 = Daily.
  final RxInt tab = 0.obs;

  /// Màn đang xem ở tab Campaign (1-based).
  final RxInt selectedLevel = 1.obs;

  static LeaderboardController? get maybe =>
      Get.isRegistered<LeaderboardController>()
      ? Get.find<LeaderboardController>()
      : null;

  int get maxLevel => kLevelCount;

  void setLevel(int lv) => selectedLevel.value = lv.clamp(1, kLevelCount);

  /// Điểm target của màn [level] (đọc trực tiếp config, không tính lại).
  int _targetOf(int level) =>
      kLevels[(level - 1).clamp(0, kLevelCount - 1)].targetScore;

  /// Bảng Campaign cho [selectedLevel]: 9 bot (seed = tuần) + người chơi
  /// (điểm thật = highScores, chưa chơi → 0). Chu kỳ tuần → đổi mỗi tuần.
  List<LbEntry> campaignBoard() {
    final lv = selectedLevel.value;
    final target = _targetOf(lv);
    final player = g.highScores[lv] ?? 0;
    final week = tournamentWeek(g.todayEpochDay);
    // +lv vào period để mỗi màn có bảng riêng (không 200 màn chung 1 bảng bot).
    return buildLeaderboard(target, player, week * 211 + lv);
  }

  /// Bảng Daily: bot seed theo NGÀY. Người chơi ẩn (chưa có cơ chế điểm daily
  /// riêng — xem doc/tasks/todo/w21-6 mục "Nguồn điểm người chơi daily").
  List<LbEntry> dailyBoard() {
    final day = g.todayEpochDay;
    // baseTarget biến thiên theo ngày để bảng daily không trùng campaign.
    final target = _targetOf((day % kLevelCount) + 1);
    return buildLeaderboard(target, -1, day, includePlayer: false);
  }
}

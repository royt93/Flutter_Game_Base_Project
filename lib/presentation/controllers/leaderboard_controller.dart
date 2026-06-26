import 'package:get/get.dart';
import '../../core/leaderboard_engine.dart';
import '../../core/storage_service.dart';
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

  /// Điểm Daily của người chơi HÔM NAY (`'<day>|<score>'`); -1 nếu chưa hoàn thành.
  int dailyPlayerScore() {
    final day = g.todayEpochDay;
    final raw = StorageService.to.getString(StorageKeys.dailyBestScore);
    if (raw == null) return -1;
    final parts = raw.split('|');
    if (parts.length == 2 && int.tryParse(parts[0]) == day) {
      return int.tryParse(parts[1]) ?? -1;
    }
    return -1;
  }

  /// Bảng Daily: bot seed theo NGÀY + người chơi (nếu đã hoàn thành Daily hôm nay,
  /// điểm từ [StorageKeys.dailyBestScore] — W22.4A).
  List<LbEntry> dailyBoard() {
    final day = g.todayEpochDay;
    // baseTarget biến thiên theo ngày để bảng daily không trùng campaign.
    final target = _targetOf((day % kLevelCount) + 1);
    final player = dailyPlayerScore();
    return buildLeaderboard(target, player, day, includePlayer: player >= 0);
  }
}

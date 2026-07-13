/// I9 — Leaderboard bạn bè (offline giả lập). KHÔNG có backend/network nào:
/// [kLeaderboardBots] là danh sách "bot" tĩnh, người chơi được chèn vào đúng
/// vị trí theo tổng sao ([GameController.totalStars]) rồi sort giảm dần.
class LeaderboardEntry {
  final String name;
  final int stars;
  final bool isPlayer;

  const LeaderboardEntry(this.name, this.stars, {this.isPlayer = false});
}

/// Chèn người chơi ([playerStars]) vào [bots], sort theo sao giảm dần.
/// Bằng sao thì bot đứng trước người chơi (ổn định, dễ test).
List<LeaderboardEntry> buildLeaderboard(
  List<LeaderboardEntry> bots,
  int playerStars,
) {
  final entries = [
    ...bots,
    LeaderboardEntry('__player__', playerStars, isPlayer: true),
  ];
  entries.sort((a, b) {
    final cmp = b.stars.compareTo(a.stars);
    if (cmp != 0) return cmp;
    if (a.isPlayer) return 1;
    if (b.isPlayer) return -1;
    return 0;
  });
  return entries;
}

/// Hạng 1-indexed của người chơi trong [entries] (kết quả [buildLeaderboard]).
int playerRank(List<LeaderboardEntry> entries) =>
    entries.indexWhere((e) => e.isPlayer) + 1;

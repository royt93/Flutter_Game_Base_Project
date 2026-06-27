/// Offline Leaderboard engine (Wave 21.6) — bot score TẤT ĐỊNH (KHÔNG Random
/// runtime, mirror style hash của `data/tournament.dart`). Bảng top 10 = 9 bot AI +
/// người chơi. `period` = epoch-week (Campaign) hoặc epoch-day (Daily) → bảng đổi
/// theo chu kỳ tạo cảm giác đua hạng. Pure Dart → unit-test cô lập, offline thuần.
library;

/// Pool tên neon (proper noun — KHÔNG dịch). ≥10 để top-10 không trùng tên.
const List<String> kLeaderboardNames = [
  'Nova',
  'Zyra',
  'Echo',
  'Lumen',
  'Pyx',
  'Vortex',
  'Glint',
  'Aster',
  'Quark',
  'Ion',
  'Riff',
  'Myst',
  'Flux',
  'Onyx',
];

/// Số bot AI mỗi bảng (top 10 = 9 bot + người chơi).
const int kLbBotCount = 9;

/// 1 dòng bảng xếp hạng. [isPlayer] → render highlight + nhãn "BẠN".
class LbEntry {
  final String name;
  final int score;
  final bool isPlayer;
  const LbEntry(this.name, this.score, {this.isPlayer = false});
}

/// Điểm bot [rank] (0-based) cho màn có [baseTarget], seed [period]. TẤT ĐỊNH:
/// trộn hash (period, rank) → dải ~0.75–1.30× target, giảm dần theo rank.
int lbBotScore(int baseTarget, int rank, int period) {
  final t = baseTarget <= 0 ? 1000 : baseTarget;
  final mix = (period * 2654435761 + rank * 40503 + 12345) & 0x7fffffff;
  final pct = 0.75 + (mix % 56) / 100.0; // 0.75..1.30
  final falloff = (1.0 - rank * 0.05).clamp(
    0.4,
    1.0,
  ); // hạng thấp điểm giảm dần
  return (t * pct * falloff).round();
}

/// Tên bot [rank] cho [period] — distinct trong cùng bảng (rank < pool size).
String lbBotName(int rank, int period) {
  final start = (period * 31) & 0x7fffffff;
  return kLeaderboardNames[(start + rank) % kLeaderboardNames.length];
}

/// Top 10 (điểm giảm dần). [playerScore] < 0 hoặc [includePlayer]=false → chỉ bot
/// (người chơi chưa có điểm — Daily chưa hoàn thành). Người chơi mang [isPlayer]=true.
List<LbEntry> buildLeaderboard(
  int baseTarget,
  int playerScore,
  int period, {
  bool includePlayer = true,
}) {
  // distinct tên bot trong cùng bảng phụ thuộc rank < số tên trong pool.
  assert(
    kLbBotCount <= kLeaderboardNames.length,
    'kLbBotCount phải <= số tên trong kLeaderboardNames để tên không trùng',
  );
  final list = <LbEntry>[
    for (var r = 0; r < kLbBotCount; r++)
      LbEntry(lbBotName(r, period), lbBotScore(baseTarget, r, period)),
  ];
  if (includePlayer && playerScore >= 0) {
    list.add(LbEntry('', playerScore, isPlayer: true));
  }
  // Sort giảm dần; tie-break: người chơi xếp TRÊN bot cùng điểm (ưu ái nhẹ).
  list.sort((a, b) {
    final c = b.score.compareTo(a.score);
    if (c != 0) return c;
    if (a.isPlayer) return -1;
    if (b.isPlayer) return 1;
    return 0;
  });
  return list.length > 10 ? list.sublist(0, 10) : list;
}

/// Hạng (1-based) của người chơi trong [board]; 0 nếu không có dòng người chơi.
int playerRank(List<LbEntry> board) {
  for (var i = 0; i < board.length; i++) {
    if (board[i].isPlayer) return i + 1;
  }
  return 0;
}

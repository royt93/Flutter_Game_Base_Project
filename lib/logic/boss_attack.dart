/// Boss attack pattern selector (Wave 23.2B) — PURE Dart, test cô lập.
/// Chọn KIỂU đòn theo phase boss; tầng engine sẽ ánh xạ ra hiệu ứng thật
/// (block = trừ lượt — đã có; shuffle/meteor = engine, wire khi verify device).
library;

/// Kiểu đòn của boss.
enum BossAttack {
  /// Trừ lượt người chơi (đã hiện thực ở W21).
  block,

  /// Xáo lại bàn (engine `_doShuffle`) — leo thang ở phase cao.
  shuffle,

  /// Phá 1 vùng nhỏ (engine clear-cell) — để dành (cần callback engine).
  meteor,
}

/// Chọn kiểu đòn theo [phase] (0/1/2). Leo thang:
/// - phase 0-1: block (trừ lượt)
/// - phase 2 (boss nổi giận): shuffle (xáo bàn)
/// Meteor để dành cho bản engine sau (chưa trả về để tránh hiệu ứng chưa wire).
BossAttack bossAttackPatternFor(int phase) {
  if (phase >= 2) return BossAttack.shuffle;
  return BossAttack.block;
}

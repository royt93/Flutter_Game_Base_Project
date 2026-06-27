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

/// Chọn kiểu đòn theo [phase] (0/1/2). Leo thang độ khó:
/// - phase 0 (100-66% HP): block (chỉ trừ lượt)
/// - phase 1 (65-33%): shuffle (xáo bàn — phá nước đi)
/// - phase 2 (32-0%, nổi giận): meteor (scramble màu 1 vùng — phá bố cục, KHÔNG ghi điểm)
BossAttack bossAttackPatternFor(int phase) {
  if (phase >= 2) return BossAttack.meteor;
  if (phase == 1) return BossAttack.shuffle;
  return BossAttack.block;
}

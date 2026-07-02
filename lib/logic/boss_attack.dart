/// Boss attack pattern selector (Wave 23.2B, mở rộng W25.1) — PURE Dart, test cô lập.
/// Chọn KIỂU đòn theo phase + LOẠI boss; tầng engine ánh xạ ra hiệu ứng thật
/// (block = trừ lượt; shuffle = xáo bàn; meteor = clear-cell + telegraph).
library;

import 'dart:math';

/// Kiểu đòn của boss.
enum BossAttack {
  /// Trừ lượt người chơi (đã hiện thực ở W21) — tức thì, không telegraph.
  block,

  /// Xáo lại bàn (engine `_doShuffle`) — tức thì.
  shuffle,

  /// Phá 1 vùng nhỏ (engine clear-cell) — TELEGRAPH 1 lượt rồi rơi (đọc-và-né).
  meteor,
}

/// Loại boss (W25.1) — khác PROFILE đòn theo phase, dùng chung primitive engine.
enum BossType {
  /// Xung Kích — leo thang cổ điển: block → shuffle → meteor.
  pulse,

  /// Hắc Ám — hung hãn, dồn phá bố cục sớm: shuffle → meteor → meteor.
  voidType,
}

/// Chọn kiểu đòn theo [phase] (0/1/2) và [type]. Leo thang độ khó:
/// - pulse:    phase 0 = block · 1 = shuffle · 2 = meteor.
/// - voidType: phase 0 = shuffle · 1 = shuffle · 2 = meteor.
/// voidType khác pulse ở chỗ bỏ "block" mở màn (thay bằng shuffle hung hãn hơn),
/// NHƯNG meteor vẫn CHỈ ở phase 2 như pulse — không dồn phá bố cục sớm để tránh
/// spike độ khó cho content boss đã tune (review #4).
BossAttack bossAttackPatternFor(int phase, [BossType type = BossType.pulse]) {
  switch (type) {
    case BossType.voidType:
      if (phase >= 2) return BossAttack.meteor;
      return BossAttack.shuffle;
    case BossType.pulse:
      if (phase >= 2) return BossAttack.meteor;
      if (phase == 1) return BossAttack.shuffle;
      return BossAttack.block;
  }
}

/// Chọn vùng 3×3 quanh 1 tâm ngẫu nhiên cho đòn meteor — PURE, test được.
///
/// [isTarget] trả true cho ô hợp lệ để đánh (ô play CÓ gem, không wall/noDrop).
/// Tâm được chọn ngẫu nhiên trong các ô target; trả về danh sách ô (r,c) thuộc
/// vùng 3×3 quanh tâm mà [isTarget] cho true (tối đa 9 ô). Rỗng nếu không có ô nào.
List<(int, int)> pickMeteorRegion(
  int rows,
  int cols,
  bool Function(int r, int c) isTarget,
  Random rnd,
) {
  final candidates = <(int, int)>[];
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      if (isTarget(r, c)) candidates.add((r, c));
    }
  }
  if (candidates.isEmpty) return const [];
  final (cr, cc) = candidates[rnd.nextInt(candidates.length)];
  final region = <(int, int)>[];
  for (int dr = -1; dr <= 1; dr++) {
    for (int dc = -1; dc <= 1; dc++) {
      final r = cr + dr, c = cc + dc;
      if (r >= 0 && r < rows && c >= 0 && c < cols && isTarget(r, c)) {
        region.add((r, c));
      }
    }
  }
  return region;
}

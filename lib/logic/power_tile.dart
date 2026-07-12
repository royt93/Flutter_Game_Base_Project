import 'dart:math';

/// F5: loại tile đặc biệt sinh ra khi nổ nhóm đủ lớn, nằm lại trên bàn tới
/// khi được tap để kích hoạt. 5a: line-clear (hàng/cột). 5b: bomb (5x5).
/// 5c: rainbow (xoá toàn bộ 1 màu).
enum PowerTileKind { lineRow, lineCol, bomb, rainbow }

/// Nhóm vừa nổ đạt ngưỡng mới sinh tile: 5-6 ô → line (ngẫu nhiên hàng/cột),
/// 7-8 ô → bomb, ≥9 ô → rainbow.
PowerTileKind? powerTileKindForGroupSize(int size, Random rng) {
  if (size < 5) return null;
  if (size >= 9) return PowerTileKind.rainbow;
  if (size >= 7) return PowerTileKind.bomb;
  return rng.nextBool() ? PowerTileKind.lineRow : PowerTileKind.lineCol;
}

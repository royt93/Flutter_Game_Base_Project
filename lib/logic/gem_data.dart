// Dữ liệu thuần (pure Dart) mô tả viên gem — không phụ thuộc Flutter/Flame.
// Tách riêng để dễ unit-test phần logic match-3.

/// Màu gem, ánh xạ sang màu neon thật ở tầng render.
enum GemColor { cyan, magenta, lime, yellow, orange, purple }

/// Loại gem.
/// - normal: gem thường
/// - stripedH / stripedV: nổ cả hàng / cả cột (tạo từ match 4)
/// - bomb: nổ vùng 3x3 xung quanh (tạo từ match hình T/L)
/// - rainbow: xóa toàn bộ gem cùng 1 màu (tạo từ match 5)
/// - diagonal: nổ 2 đường chéo (hình X) qua ô (tạo từ match 6+) — Wave 9
enum GemType { normal, stripedH, stripedV, bomb, rainbow, diagonal }

/// Vị trí 1 ô trên lưới.
class Cell {
  final int row;
  final int col;
  const Cell(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is Cell && other.row == row && other.col == col;

  @override
  int get hashCode => row * 1000 + col;

  @override
  String toString() => '($row,$col)';
}

/// Một cụm match được phát hiện: các ô liên quan + loại special nên tạo ra.
class MatchGroup {
  final List<Cell> cells;
  final GemColor color;

  /// true = run ngang, false = run dọc (dùng để phát hiện giao điểm T/L → bomb).
  final bool horizontal;

  /// Special nên tạo (normal nghĩa là không tạo special).
  final GemType special;

  /// Ô được chọn để biến thành gem special (nếu có).
  final Cell? specialAt;

  const MatchGroup({
    required this.cells,
    required this.color,
    required this.horizontal,
    this.special = GemType.normal,
    this.specialAt,
  });
}

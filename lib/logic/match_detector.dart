import 'gem_data.dart';

/// Bộ phát hiện match-3 thuần Dart (testable).
///
/// Đầu vào là lưới màu (null = ô trống). Trả về danh sách [MatchGroup]:
/// - run dài 3: match thường
/// - run dài 4: tạo gem striped (ngang/dọc tùy hướng run)
/// - run dài 5: tạo gem rainbow
/// - run dài >=6: tạo gem diagonal (nổ 2 đường chéo) — Wave 9
///
/// Lưu ý: T/L shape (tạo bomb) thuộc phạm vi mở rộng — chưa xử lý ở MVP.
class MatchDetector {
  /// Tìm tất cả các run ngang & dọc có độ dài >= 3.
  static List<MatchGroup> findMatches(List<List<GemColor?>> grid) {
    final rows = grid.length;
    if (rows == 0) return const [];
    final cols = grid[0].length;
    final groups = <MatchGroup>[];

    // --- Quét hàng ngang ---
    for (int r = 0; r < rows; r++) {
      int runStart = 0;
      for (int c = 1; c <= cols; c++) {
        final atEnd = c == cols;
        final same = !atEnd &&
            grid[r][c] != null &&
            grid[r][c] == grid[r][runStart];
        if (!same) {
          final len = c - runStart;
          if (grid[r][runStart] != null && len >= 3) {
            final cells = [for (int k = runStart; k < c; k++) Cell(r, k)];
            groups.add(_buildGroup(cells, grid[r][runStart]!, len, horizontal: true));
          }
          runStart = c;
        }
      }
    }

    // --- Quét cột dọc ---
    for (int c = 0; c < cols; c++) {
      int runStart = 0;
      for (int r = 1; r <= rows; r++) {
        final atEnd = r == rows;
        final same = !atEnd &&
            grid[r][c] != null &&
            grid[r][c] == grid[runStart][c];
        if (!same) {
          final len = r - runStart;
          if (grid[runStart][c] != null && len >= 3) {
            final cells = [for (int k = runStart; k < r; k++) Cell(k, c)];
            groups.add(_buildGroup(cells, grid[runStart][c]!, len, horizontal: false));
          }
          runStart = r;
        }
      }
    }

    return groups;
  }

  static MatchGroup _buildGroup(
    List<Cell> cells,
    GemColor color,
    int len, {
    required bool horizontal,
  }) {
    GemType special = GemType.normal;
    if (len == 4) {
      // Striped: nổ theo chiều vuông góc với run cho cảm giác "phá rộng".
      special = horizontal ? GemType.stripedV : GemType.stripedH;
    } else if (len == 5) {
      special = GemType.rainbow;
    } else if (len == 6) {
      // Match 6 → Diagonal: nổ 2 đường chéo (X) qua ô — phủ chéo "phá toang".
      special = GemType.diagonal;
    } else if (len >= 7) {
      // Match 7+ → Light Ball (Wave 10): quả cầu sáng — toả tia HÀNG + CỘT +
      // 2 CHÉO (hình sao 8 hướng). Tầng cao nhất, hiếm gặp = "jackpot".
      special = GemType.lightBall;
    }
    final specialAt = special == GemType.normal ? null : cells[cells.length ~/ 2];
    return MatchGroup(
      cells: cells,
      color: color,
      horizontal: horizontal,
      special: special,
      specialAt: specialAt,
    );
  }

  /// Các ô là giao điểm của 1 run ngang & 1 run dọc (hình T / L / +) → tạo bomb.
  static Set<Cell> bombCells(List<MatchGroup> groups) {
    final inH = <Cell>{};
    final inV = <Cell>{};
    for (final g in groups) {
      for (final c in g.cells) {
        (g.horizontal ? inH : inV).add(c);
      }
    }
    return inH.intersection(inV);
  }

  /// Các ô nằm trên 2 đường chéo (hình X) đi qua [center] trong lưới
  /// [rows]×[cols] — dùng cho diagonal gem (Wave 9). [thickness] > 0 → chéo dày
  /// thêm ±thickness ô (combo mạnh). Pure → unit-test được.
  static Set<Cell> diagonalCells(int rows, int cols, Cell center,
      {int thickness = 0}) {
    final out = <Cell>{};
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final main = (r - center.row) - (c - center.col); // lệch chéo ↘
        final anti = (r - center.row) + (c - center.col); // lệch chéo ↙↗
        if (main.abs() <= thickness || anti.abs() <= thickness) {
          out.add(Cell(r, c));
        }
      }
    }
    return out;
  }

  /// Các ô của Light Ball (Wave 10): HÀNG + CỘT + 2 CHÉO qua [center] (sao 8
  /// hướng). [thickness] > 0 → dày thêm cho combo. Pure → unit-test được.
  static Set<Cell> lightBallCells(int rows, int cols, Cell center,
      {int thickness = 0}) {
    final out = diagonalCells(rows, cols, center, thickness: thickness);
    for (int c = 0; c < cols; c++) {
      for (int t = -thickness; t <= thickness; t++) {
        final r = center.row + t;
        if (r >= 0 && r < rows) out.add(Cell(r, c)); // hàng (±dày)
      }
    }
    for (int r = 0; r < rows; r++) {
      for (int t = -thickness; t <= thickness; t++) {
        final c = center.col + t;
        if (c >= 0 && c < cols) out.add(Cell(r, c)); // cột (±dày)
      }
    }
    return out;
  }

  /// Tiện ích: gộp tất cả ô của mọi group thành một tập hợp duy nhất.
  static Set<Cell> allCells(List<MatchGroup> groups) {
    final s = <Cell>{};
    for (final g in groups) {
      s.addAll(g.cells);
    }
    return s;
  }

  /// Kiểm tra nhanh: lưới hiện tại có match nào không.
  static bool hasMatch(List<List<GemColor?>> grid) => findMatches(grid).isNotEmpty;
}

import 'gem_data.dart';

/// Bộ phát hiện match-3 thuần Dart (testable).
///
/// Đầu vào là lưới màu (null = ô trống). Trả về danh sách [MatchGroup]:
/// - run dài 3: match thường
/// - run dài 4: tạo gem striped (ngang/dọc tùy hướng run)
/// - run dài >=5: tạo gem rainbow
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
    } else if (len >= 5) {
      special = GemType.rainbow;
    }
    final specialAt = special == GemType.normal ? null : cells[cells.length ~/ 2];
    return MatchGroup(
      cells: cells,
      color: color,
      special: special,
      specialAt: specialAt,
    );
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

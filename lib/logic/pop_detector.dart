import 'dart:math';

import 'wildcard_tile.dart';

/// Tìm nhóm ô cùng màu liền kề (4 hướng) chứa (row, col), dùng flood-fill.
/// Trả về rỗng nếu ô đó là null (đã trống), obstacle (F6a: mã hoá bằng giá
/// trị âm — không thuộc nhóm màu nào, không nổ trực tiếp), hoặc đang bị khoá
/// (I2: `lockGrid[row][col] > 0` — chain tile, không match được cho tới khi
/// mở khoá). Kích thước 1 vẫn được trả về — caller tự quyết định ngưỡng ≥2 để
/// nổ.
///
/// I46: Wildcard (`isWildcardTileValue`) khớp với MỌI màu khi flood-fill tiếp
/// tục, nhưng "màu mục tiêu" của cả nhóm chỉ được xác định 1 lần ngay tại ô
/// bắt đầu — nên wildcard không bao giờ làm cầu nối 2 nhóm màu khác nhau
/// thành 1. Nếu tap trực tiếp vào wildcard: mượn màu của ô màu thường liền kề
/// đầu tiên (thứ tự trên/dưới/trái/phải); nếu không có ô nào, trả về nhóm
/// kích thước 1 (chính ô đó).
Set<Point<int>> findConnectedGroup(
  List<List<int?>> grid,
  int row,
  int col, {
  List<List<int>>? lockGrid,
}) {
  final rows = grid.length;
  final cols = rows == 0 ? 0 : grid[0].length;
  if (lockGrid != null && lockGrid[row][col] > 0) return {};
  var color = grid[row][col];
  if (color == null) return {};
  if (color < 0 && !isWildcardTileValue(color)) return {};

  if (isWildcardTileValue(color)) {
    color = _borrowNeighborColor(grid, rows, cols, row, col);
    if (color == null) return {Point(row, col)};
  }

  final visited = <Point<int>>{};
  final stack = [Point(row, col)];
  while (stack.isNotEmpty) {
    final p = stack.removeLast();
    if (p.x < 0 || p.x >= rows || p.y < 0 || p.y >= cols) continue;
    if (visited.contains(p)) continue;
    final v = grid[p.x][p.y];
    if (v != color && !isWildcardTileValue(v)) continue;
    if (lockGrid != null && lockGrid[p.x][p.y] > 0) continue;
    visited.add(p);
    stack.addAll([
      Point(p.x - 1, p.y),
      Point(p.x + 1, p.y),
      Point(p.x, p.y - 1),
      Point(p.x, p.y + 1),
    ]);
  }
  return visited;
}

/// Ô màu thường (>= 0) liền kề đầu tiên theo thứ tự trên/dưới/trái/phải, bỏ
/// qua ô rỗng/obstacle/wildcard khác. Null nếu wildcard bị cô lập.
int? _borrowNeighborColor(
  List<List<int?>> grid,
  int rows,
  int cols,
  int row,
  int col,
) {
  for (final p in [
    Point(row - 1, col),
    Point(row + 1, col),
    Point(row, col - 1),
    Point(row, col + 1),
  ]) {
    if (p.x < 0 || p.x >= rows || p.y < 0 || p.y >= cols) continue;
    final v = grid[p.x][p.y];
    if (v != null && v >= 0) return v;
  }
  return null;
}

/// I4: nhóm ≥2 ô lớn nhất còn lại trên bàn (dùng cho predictive hint). Rỗng
/// nếu bàn không còn nhóm nào ≥2 (kẹt).
Set<Point<int>> findLargestGroup(
  List<List<int?>> grid, {
  List<List<int>>? lockGrid,
}) {
  final rows = grid.length;
  final cols = rows == 0 ? 0 : grid[0].length;
  final visited = <Point<int>>{};
  var best = const <Point<int>>{};
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (grid[r][c] == null || grid[r][c]! < 0) continue;
      if (lockGrid != null && lockGrid[r][c] > 0) continue;
      final p = Point(r, c);
      if (visited.contains(p)) continue;
      final group = findConnectedGroup(grid, r, c, lockGrid: lockGrid);
      visited.addAll(group);
      if (group.length >= 2 && group.length > best.length) best = group;
    }
  }
  return best;
}

/// Bàn còn nhóm nào ≥2 ô có thể nổ không (dùng để phát hiện bàn "kẹt").
bool hasAnyMovableGroup(List<List<int?>> grid, {List<List<int>>? lockGrid}) {
  final rows = grid.length;
  final cols = rows == 0 ? 0 : grid[0].length;
  final visited = <Point<int>>{};
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (grid[r][c] == null || grid[r][c]! < 0) continue;
      if (lockGrid != null && lockGrid[r][c] > 0) continue;
      final p = Point(r, c);
      if (visited.contains(p)) continue;
      final group = findConnectedGroup(grid, r, c, lockGrid: lockGrid);
      visited.addAll(group);
      if (group.length >= 2) return true;
    }
  }
  return false;
}

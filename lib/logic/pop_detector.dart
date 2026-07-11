import 'dart:math';

/// Tìm nhóm ô cùng màu liền kề (4 hướng) chứa (row, col), dùng flood-fill.
/// Trả về rỗng nếu ô đó là null (đã trống). Kích thước 1 vẫn được trả về —
/// caller tự quyết định ngưỡng ≥2 để nổ.
Set<Point<int>> findConnectedGroup(List<List<int?>> grid, int row, int col) {
  final rows = grid.length;
  final cols = rows == 0 ? 0 : grid[0].length;
  final color = grid[row][col];
  if (color == null) return {};

  final visited = <Point<int>>{};
  final stack = [Point(row, col)];
  while (stack.isNotEmpty) {
    final p = stack.removeLast();
    if (p.x < 0 || p.x >= rows || p.y < 0 || p.y >= cols) continue;
    if (visited.contains(p)) continue;
    if (grid[p.x][p.y] != color) continue;
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

/// Bàn còn nhóm nào ≥2 ô có thể nổ không (dùng để phát hiện bàn "kẹt").
bool hasAnyMovableGroup(List<List<int?>> grid) {
  final rows = grid.length;
  final cols = rows == 0 ? 0 : grid[0].length;
  final visited = <Point<int>>{};
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (grid[r][c] == null) continue;
      final p = Point(r, c);
      if (visited.contains(p)) continue;
      final group = findConnectedGroup(grid, r, c);
      visited.addAll(group);
      if (group.length >= 2) return true;
    }
  }
  return false;
}

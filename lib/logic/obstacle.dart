import 'dart:math';

import 'boss_tile.dart';
import 'gift_tile.dart';

/// F6a: obstacle (ice/crate) mã hoá bằng giá trị âm ngay trong colorGrid —
/// -d nghĩa là còn d độ bền. Không phải màu nên `pop_detector` đã loại nó
/// khỏi mọi flood-fill (không thuộc nhóm màu, không nổ trực tiếp).
/// I1: [giftTileValue] cũng âm nhưng không phải obstacle — loại trừ tường
/// minh, không thì bị chip nhầm thành obstacle rất bền.
/// I29: boss tile id cũng âm ([isBossTileId]) — loại trừ tương tự, không thì
/// bị obstacle-chip mutate `grid[p]! + 1` làm lệch id (vd -2000 → -1999),
/// khiến [isBossTileId] sau đó nhận nhầm cell là không-boss và HP không bao
/// giờ được trừ đúng chỗ.

/// Nhóm vừa nổ tại [poppedCells] chip 1 độ bền mọi obstacle liền kề (4 hướng).
/// Hết độ bền → vỡ thành ô trống (null). Mutates [grid] in place. Trả về vị
/// trí các obstacle vừa vỡ (để caller gộp vào tập ô cần xoá/animate).
Set<Point<int>> chipAdjacentObstacles(
  List<List<int?>> grid,
  Set<Point<int>> poppedCells,
) {
  final rows = grid.length;
  final cols = rows == 0 ? 0 : grid[0].length;
  final hit = <Point<int>>{};
  for (final p in poppedCells) {
    for (final n in [
      Point(p.x - 1, p.y),
      Point(p.x + 1, p.y),
      Point(p.x, p.y - 1),
      Point(p.x, p.y + 1),
    ]) {
      if (n.x < 0 || n.x >= rows || n.y < 0 || n.y >= cols) continue;
      final v = grid[n.x][n.y];
      if (v != null && v < 0 && v != giftTileValue && !isBossTileId(v)) {
        hit.add(n);
      }
    }
  }
  final broken = <Point<int>>{};
  for (final p in hit) {
    final next = grid[p.x][p.y]! + 1;
    if (next >= 0) {
      grid[p.x][p.y] = null;
      broken.add(p);
    } else {
      grid[p.x][p.y] = next;
    }
  }
  return broken;
}

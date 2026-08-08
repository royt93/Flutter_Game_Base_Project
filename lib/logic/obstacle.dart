import 'dart:math';

import 'boss_tile.dart';
import 'countdown_lock_tile.dart';
import 'gift_tile.dart';
import 'ice_tile.dart';
import 'wildcard_tile.dart';

/// F6a: obstacle (ice/crate) mã hoá bằng giá trị âm ngay trong colorGrid —
/// -d nghĩa là còn d độ bền. Không phải màu nên `pop_detector` đã loại nó
/// khỏi mọi flood-fill (không thuộc nhóm màu, không nổ trực tiếp).
/// I1: [giftTileValue] cũng âm nhưng không phải obstacle — loại trừ tường
/// minh, không thì bị chip nhầm thành obstacle rất bền.
/// I29: boss tile id cũng âm ([isBossTileId]) — loại trừ tương tự, không thì
/// bị obstacle-chip mutate `grid[p]! + 1` làm lệch id (vd -2000 → -1999),
/// khiến [isBossTileId] sau đó nhận nhầm cell là không-boss và HP không bao
/// giờ được trừ đúng chỗ.
/// I45: Countdown Lock ([isCountdownLockId]) cũng âm nhưng chỉ giảm theo số
/// lượt tap (xem `countdown_lock_tile.dart`), không theo pop-kề-cạnh — loại
/// trừ tương tự, không thì bị chip nhầm thành obstacle.
/// I46: Wildcard ([isWildcardTileValue]) luôn bị nổ chung nhóm màu liền kề
/// trước khi hàm này chạy (xem `pop_detector.findConnectedGroup`) — loại trừ
/// chỉ để phòng vệ, tránh chip nhầm nếu vì lý do gì đó nó còn sót lại trên
/// bàn sau pop.
/// I76: Ice Tile ([isIceTileId]) chip riêng qua [chipAdjacentIceTiles] (dải ID
/// độc lập, độ bền tính theo lớp băng chứ không phải -d như obstacle) — loại
/// trừ tương tự, không thì bị hàm này chip đè thêm 1 lần nữa trong cùng 1 pop.

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
      if (v != null &&
          v < 0 &&
          v != giftTileValue &&
          !isBossTileId(v) &&
          !isCountdownLockId(v) &&
          !isWildcardTileValue(v) &&
          !isIceTileId(v)) {
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

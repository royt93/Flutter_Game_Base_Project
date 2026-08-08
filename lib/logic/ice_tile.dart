import 'dart:math';

/// I76: obstacle "băng" 2 lớp — dùng riêng 1 dải ID âm (giống pattern
/// `magnetTileIdBase`) thay vì mã hoá độ bền trực tiếp như obstacle thường,
/// để không đụng độ bền obstacle thật. Nằm giữa gift (-1000) và countdown-lock
/// (-1500), không trùng dải nào khác.
const iceTileIdBase = -1400;
const iceTileDurability = 2;

/// Dải hợp lệ (iceTileIdBase - iceTileDurability, iceTileIdBase] — với
/// durability=2 là đúng 2 giá trị: -1401 (2 lớp, mới) và -1400 (1 lớp, sắp
/// vỡ). Dải này không giao với bất kỳ tile đặc biệt nào khác nên
/// [chipAdjacentIceTiles] chỉ cần match đúng hàm này, không cần loại trừ thủ
/// công từng loại tile khác như [chipAdjacentObstacles] ở `obstacle.dart`
/// (hàm đó thiếu check magnet — gap không lặp lại ở đây).
bool isIceTileId(int? v) =>
    v != null && v <= iceTileIdBase && v > iceTileIdBase - iceTileDurability;

/// Số lớp băng còn lại (2 = mới, 1 = đã nứt) — dùng cho render badge, mirror
/// cách Countdown Lock hiển thị số đếm còn lại.
int iceTileRemaining(int v) => iceTileIdBase - v + 1;

/// Nổ nhóm liền kề ô băng → chip 1 lớp; hết lớp thì vỡ (trả về ô vừa vỡ để
/// gộp vào tập xoá). Mirror [chipAdjacentObstacles] ở `obstacle.dart` nhưng
/// quét trực tiếp bằng [isIceTileId] thay vì loại trừ từng tile khác.
Set<Point<int>> chipAdjacentIceTiles(
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
      if (isIceTileId(grid[n.x][n.y])) hit.add(n);
    }
  }
  final broken = <Point<int>>{};
  for (final p in hit) {
    final next = grid[p.x][p.y]! + 1;
    if (next > iceTileIdBase) {
      grid[p.x][p.y] = null;
      broken.add(p);
    } else {
      grid[p.x][p.y] = next;
    }
  }
  return broken;
}

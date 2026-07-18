import 'dart:math';

/// I29: mã âm định danh chung cho boss tile — nối tiếp tiền lệ obstacle (số
/// âm nhỏ = độ bền, `lib/logic/obstacle.dart`) và `giftTileValue` (-1000,
/// `lib/logic/gift_tile.dart`) trong `colorGrid`. Boss tile dùng dải
/// `<= bossTileIdBase` để không đụng 2 dải trên. Khác obstacle: giá trị âm ở
/// đây CHỈ là mã định danh instance của 1 khối boss (nhiều cell cùng mang 1
/// mã) — HP sống trong 1 `Map<int, int>` riêng ngoài grid, KHÔNG mã hoá vào
/// giá trị int của grid. Vị trí từng cell vẫn lấy trực tiếp từ grid (grid là
/// nguồn sự thật duy nhất cho vị trí) — không cần 1 cấu trúc song song thứ 2
/// chỉ để lặp lại thông tin gravity/collapse đã tự cập nhật đúng rồi.
///
/// LƯU Ý: đây là khái niệm hoàn toàn khác `PopLevel.isBoss`/
/// `bossTargetMultiplier` (`lib/data/levels.dart`, chỉ tăng target score,
/// không phải tile trên bàn) — xem `BossTileSpec` bên dưới.
const bossTileIdBase = -2000;

/// [value] có phải mã boss tile không (dùng ở `pop_detector`/`block_component`
/// để phân biệt với obstacle/gift — cả 3 đều âm nhưng ý nghĩa khác nhau).
bool isBossTileId(int? value) => value != null && value <= bossTileIdBase;

/// Cấu hình đặt 1 boss tile tại level milestone: khối chữ nhật góc trên-trái
/// ([row], [col]) kích thước [height] x [width], HP khởi đầu [startHp].
class BossTileSpec {
  const BossTileSpec({
    required this.row,
    required this.col,
    required this.height,
    required this.width,
    required this.startHp,
  });

  final int row;
  final int col;
  final int height;
  final int width;
  final int startHp;

  /// Toạ độ mọi cell thuộc khối.
  Iterable<Point<int>> get cells sync* {
    for (var r = row; r < row + height; r++) {
      for (var c = col; c < col + width; c++) {
        yield Point(r, c);
      }
    }
  }

  /// Khối có nằm gọn trong bàn [rows] x [cols] không — dùng để validate spec
  /// tại nơi sinh level (kích thước bàn thay đổi 8..11 hàng / 6..12 cột theo
  /// world) trước khi đặt.
  bool fitsBoard(int rows, int cols) =>
      row >= 0 && col >= 0 && row + height <= rows && col + width <= cols;
}

/// Đặt boss [id] theo [spec] lên [grid] (mutate in place, mọi cell của khối
/// mang cùng [id]). Trả về HP khởi đầu để caller lưu vào Map HP riêng (không
/// mã hoá HP trong grid).
int placeBossTile(List<List<int?>> grid, BossTileSpec spec, int id) {
  for (final p in spec.cells) {
    grid[p.x][p.y] = id;
  }
  return spec.startHp;
}

/// Nhóm gem thường vừa nổ tại [poppedCells] chip 1 HP mỗi boss tile liền kề
/// (4 hướng) trong [bossHp] — dù boss tile chiếm nhiều cell, cả khối dùng
/// chung 1 HP pool nên chỉ trừ 1 HP/lần pop dù chạm nhiều cạnh cùng lúc (mỗi
/// id chỉ trừ tối đa 1 lần/lệnh gọi). HP về 0 → toàn bộ cell của boss đó
/// thành `null` (để `applyGravityAndCollapse` xử lý rơi/dồn bình thường,
/// không đổi logic gravity/collapse) và bị xoá khỏi [bossHp]. Mutates
/// [grid]/[bossHp] in place. Trả về vị trí mọi cell vừa vỡ (gộp vào tập ô
/// cần xoá/animate).
Set<Point<int>> chipAdjacentBossTiles(
  List<List<int?>> grid,
  Set<Point<int>> poppedCells,
  Map<int, int> bossHp,
) {
  final rows = grid.length;
  final cols = rows == 0 ? 0 : grid[0].length;
  final hitIds = <int>{};
  for (final p in poppedCells) {
    for (final n in [
      Point(p.x - 1, p.y),
      Point(p.x + 1, p.y),
      Point(p.x, p.y - 1),
      Point(p.x, p.y + 1),
    ]) {
      if (n.x < 0 || n.x >= rows || n.y < 0 || n.y >= cols) continue;
      final v = grid[n.x][n.y];
      if (isBossTileId(v)) hitIds.add(v!);
    }
  }
  return _decrementAndBreak(grid, bossHp, hitIds);
}

/// I29: chống kẹt bàn — khi `_checkEnd` phát hiện bàn "stuck" (còn boss tile
/// chưa vỡ nhưng không còn gem thường liền kề pop được), gọi hàm này để tự
/// giảm 1 HP MỌI boss tile hiện có trên bàn thay vì kết thúc màn ngay. Mutates
/// [grid]/[bossHp] in place. Trả về vị trí mọi cell vừa vỡ (nếu có).
Set<Point<int>> decayBossTilesOnStuck(
  List<List<int?>> grid,
  Map<int, int> bossHp,
) {
  return _decrementAndBreak(grid, bossHp, bossHp.keys.toSet());
}

Set<Point<int>> _decrementAndBreak(
  List<List<int?>> grid,
  Map<int, int> bossHp,
  Set<int> ids,
) {
  final broken = <Point<int>>{};
  final rows = grid.length;
  final cols = rows == 0 ? 0 : grid[0].length;
  for (final id in ids) {
    final hp = bossHp[id];
    if (hp == null) continue;
    final next = hp - 1;
    if (next <= 0) {
      bossHp.remove(id);
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          if (grid[r][c] == id) {
            grid[r][c] = null;
            broken.add(Point(r, c));
          }
        }
      }
    } else {
      bossHp[id] = next;
    }
  }
  return broken;
}

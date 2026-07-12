import 'dart:math';

/// I2: chain tile — ô có màu thật (vẫn hiển thị đúng màu, vẫn tham gia flood-
/// fill ngay khi mở khoá) nhưng KHÔNG match được cho tới khi đủ K lần ô cạnh
/// nó bị nổ. Khác obstacle (`lib/logic/obstacle.dart`) — obstacle mã hoá bằng
/// giá trị âm ngay trong colorGrid (không màu); lock sống ở cấu trúc song
/// song riêng (`lockGrid`, 0 = không khoá) vì colorGrid vẫn phải giữ màu
/// dương thật.

/// Nhóm vừa nổ tại [poppedCells] chip 1 lock mọi ô khoá liền kề (4 hướng).
/// Dedup qua Set nên 1 ô cạnh nhiều ô pop cùng lúc chỉ mất đúng 1 lock. Mở
/// khoá không xoá ô (khác obstacle vỡ) nên không cần trả về gì — mutates
/// [lockGrid] in place.
void chipAdjacentLocks(List<List<int>> lockGrid, Set<Point<int>> poppedCells) {
  final rows = lockGrid.length;
  final cols = rows == 0 ? 0 : lockGrid[0].length;
  final hit = <Point<int>>{};
  for (final p in poppedCells) {
    for (final n in [
      Point(p.x - 1, p.y),
      Point(p.x + 1, p.y),
      Point(p.x, p.y - 1),
      Point(p.x, p.y + 1),
    ]) {
      if (n.x < 0 || n.x >= rows || n.y < 0 || n.y >= cols) continue;
      if (lockGrid[n.x][n.y] > 0) hit.add(n);
    }
  }
  for (final p in hit) {
    lockGrid[p.x][p.y]--;
  }
}

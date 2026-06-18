// Logic THUẦN (pure Dart) cho 3 cơ chế Wave 11: băng chuyền / cổng / dispenser.
// Tách khỏi Flame để unit-test không cần khởi tạo game.

import 'gem_data.dart';

/// Cột MỚI của 1 ô trên băng chuyền sau 1 nhịp dịch theo [dir] (cyclic, wrap mép).
/// [dir] = +1 sang phải, -1 sang trái.
int conveyorNewCol(int col, int dir, int cols) => (col + dir + cols) % cols;

/// Xây map đối tác cổng 2 CHIỀU từ danh sách cặp [pairs] (mỗi cặp [A, B]).
Map<Cell, Cell> buildPortalLinks(List<List<Cell>> pairs) {
  final m = <Cell, Cell>{};
  for (final p in pairs) {
    m[p[0]] = p[1];
    m[p[1]] = p[0];
  }
  return m;
}

/// Mở rộng tập ô bị clear bằng các ô ĐỐI TÁC cổng (1 hop — clear 1 đầu cổng thì
/// đầu kia cũng clear). KHÔNG lặp vô hạn (chỉ thêm đối tác của tập gốc).
Set<Cell> expandPortals(Set<Cell> cleared, Map<Cell, Cell> links) {
  if (links.isEmpty) return cleared;
  final out = {...cleared};
  for (final c in cleared) {
    final partner = links[c];
    if (partner != null) out.add(partner);
  }
  return out;
}

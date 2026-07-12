/// Sau khi xoá 1 nhóm ô: (1) mỗi cột rơi ô xuống lấp khoảng trống,
/// (2) dồn các cột rỗng hoàn toàn sang trái. Không refill từ trên
/// (đúng luật PopStar gốc — bàn chỉ vơi dần, không bao giờ đầy lại).
/// Sửa [grid] tại chỗ và trả về chính nó cho tiện chain. I2: nếu truyền
/// [lockGrid] (chain tile lock count, cùng kích thước [grid]), mọi phép hoán
/// vị chỉ số áp dụng lockstep lên nó — ô khoá rơi/dồn cùng cột với ô màu của
/// chính nó thay vì đứng yên.
List<List<int?>> applyGravityAndCollapse(
  List<List<int?>> grid, {
  List<List<int>>? lockGrid,
}) {
  final rows = grid.length;
  final cols = rows == 0 ? 0 : grid[0].length;

  // 1. Rơi theo cột: dồn giá trị non-null xuống đáy, giữ thứ tự tương đối.
  for (var c = 0; c < cols; c++) {
    final srcRows = [
      for (var r = 0; r < rows; r++)
        if (grid[r][c] != null) r,
    ];
    final values = [for (final r in srcRows) grid[r][c]];
    final locks = lockGrid == null
        ? null
        : [for (final r in srcRows) lockGrid[r][c]];
    final pad = rows - values.length;
    for (var r = 0; r < rows; r++) {
      grid[r][c] = r < pad ? null : values[r - pad];
      if (lockGrid != null) lockGrid[r][c] = r < pad ? 0 : locks![r - pad];
    }
  }

  // 2. Dồn cột: cột rỗng hoàn toàn (mọi hàng null) bị đẩy sang trái,
  // cột còn ô giữ nguyên thứ tự tương đối.
  final nonEmptyCols = <int>[];
  for (var c = 0; c < cols; c++) {
    final isEmpty = List.generate(
      rows,
      (r) => grid[r][c],
    ).every((v) => v == null);
    if (!isEmpty) nonEmptyCols.add(c);
  }
  for (var c = 0; c < cols; c++) {
    for (var r = 0; r < rows; r++) {
      grid[r][c] = c < nonEmptyCols.length ? grid[r][nonEmptyCols[c]] : null;
      if (lockGrid != null) {
        lockGrid[r][c] = c < nonEmptyCols.length
            ? lockGrid[r][nonEmptyCols[c]]
            : 0;
      }
    }
  }
  return grid;
}

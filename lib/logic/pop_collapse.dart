/// I3: hướng gravity của 1 màn. Mặc định [down] (luật gốc: rơi xuống, dồn
/// cột trái). `up`/`left`/`right` tái dùng đúng 1 thuật toán lõi (kéo giá trị
/// non-null về 1 phía trong mỗi cột, dồn phần rỗng còn lại về 1 phía khác)
/// bằng cách transpose/lật trục trước khi gọi rồi lật ngược lại — xem
/// [transformForDirection] — không viết 4 bộ logic riêng cho 4 hướng.
enum GravityDirection { down, up, left, right }

/// Sau khi xoá 1 nhóm ô: (1) mỗi cột rơi ô xuống lấp khoảng trống,
/// (2) dồn các cột rỗng hoàn toàn sang trái. Không refill từ trên
/// (đúng luật PopStar gốc — bàn chỉ vơi dần, không bao giờ đầy lại).
/// Sửa [grid] tại chỗ và trả về chính nó cho tiện chain. I2: nếu truyền
/// [lockGrid] (chain tile lock count, cùng kích thước [grid]), mọi phép hoán
/// vị chỉ số áp dụng lockstep lên nó — ô khoá rơi/dồn cùng cột với ô màu của
/// chính nó thay vì đứng yên. I3: [direction] khác [GravityDirection.down]
/// chạy qua [transformForDirection] rồi gọi lại đúng thuật toán down này.
List<List<int?>> applyGravityAndCollapse(
  List<List<int?>> grid, {
  List<List<int>>? lockGrid,
  GravityDirection direction = GravityDirection.down,
}) {
  if (direction == GravityDirection.down) {
    return _collapseDown(grid, lockGrid: lockGrid);
  }
  final workGrid = transformForDirection(grid, direction);
  final workLock = lockGrid == null
      ? null
      : transformForDirection(lockGrid, direction);
  _collapseDown(workGrid, lockGrid: workLock);
  final resultGrid = transformForDirection(workGrid, direction, inverse: true);
  for (var r = 0; r < grid.length; r++) {
    for (var c = 0; c < grid[r].length; c++) {
      grid[r][c] = resultGrid[r][c];
    }
  }
  if (lockGrid != null) {
    final resultLock = transformForDirection(
      workLock!,
      direction,
      inverse: true,
    );
    for (var r = 0; r < lockGrid.length; r++) {
      for (var c = 0; c < lockGrid[r].length; c++) {
        lockGrid[r][c] = resultLock[r][c];
      }
    }
  }
  return grid;
}

List<List<int?>> _collapseDown(
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

/// I3: quy [grid] về không gian mà chạy thuật toán "down" ở đó tương đương
/// gravity [direction] mong muốn ở không gian gốc — generic để dùng chung cho
/// `colorGrid`/`lockGrid` (`int`/`int?`) lẫn `_blocks` bên `pop_star_game.dart`
/// (`BlockComponent?`). `left`/`right` cần transpose (đổi trục hàng/cột) vì
/// thuật toán lõi chỉ kéo theo trục hàng; `up` chỉ cần lật hàng. Truyền
/// [inverse] = true để quy ngược kết quả về không gian gốc sau khi thuật toán
/// lõi chạy xong trên kết quả của lần gọi [inverse] = false trước đó.
List<List<T>> transformForDirection<T>(
  List<List<T>> grid,
  GravityDirection direction, {
  bool inverse = false,
}) {
  switch (direction) {
    case GravityDirection.down:
      return grid;
    case GravityDirection.up:
      return _reverseRows(grid);
    case GravityDirection.right:
      return _transpose(grid);
    case GravityDirection.left:
      return inverse
          ? _reverseCols(_transpose(grid))
          : _transpose(_reverseCols(grid));
  }
}

List<List<T>> _reverseRows<T>(List<List<T>> g) =>
    List.generate(g.length, (r) => List<T>.of(g[g.length - 1 - r]));

List<List<T>> _reverseCols<T>(List<List<T>> g) => [
  for (final row in g) List<T>.of(row.reversed),
];

List<List<T>> _transpose<T>(List<List<T>> g) {
  final rows = g.length;
  final cols = rows == 0 ? 0 : g[0].length;
  return List.generate(cols, (c) => List.generate(rows, (r) => g[r][c]));
}

/// Nén 1 lưới generic (dùng cho `_blocks` bên `pop_star_game.dart`, mỗi ô là
/// `BlockComponent?`): dồn phần tử non-null xuống đáy mỗi cột, rồi dồn cột
/// rỗng hoàn toàn sang trái. Cùng thuật toán 2 bước với [_collapseDown] nhưng
/// không kèm lockGrid lockstep (block đã tự mang lockCount riêng). Sửa [grid]
/// tại chỗ và trả về chính nó.
List<List<T?>> compactNonNullDown<T>(List<List<T?>> grid) {
  final rows = grid.length;
  final cols = rows == 0 ? 0 : grid[0].length;

  for (var c = 0; c < cols; c++) {
    final values = [
      for (var r = 0; r < rows; r++)
        if (grid[r][c] != null) grid[r][c],
    ];
    final pad = rows - values.length;
    for (var r = 0; r < rows; r++) {
      grid[r][c] = r < pad ? null : values[r - pad];
    }
  }

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
    }
  }
  return grid;
}

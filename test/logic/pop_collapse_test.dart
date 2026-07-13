import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/pop_collapse.dart';

void main() {
  group('applyGravityAndCollapse', () {
    test('ô rơi xuống lấp khoảng trống trong cùng cột', () {
      final List<List<int?>> grid = [
        [0, null],
        [null, null],
        [null, 1],
      ];
      applyGravityAndCollapse(grid);
      expect(grid, [
        [null, null],
        [null, null],
        [0, 1],
      ]);
    });

    test('giữ thứ tự tương đối các ô còn lại trong cột khi rơi', () {
      final List<List<int?>> grid = [
        [0],
        [null],
        [1],
        [2],
      ];
      applyGravityAndCollapse(grid);
      expect(grid, [
        [null],
        [0],
        [1],
        [2],
      ]);
    });

    test('cột rỗng hoàn toàn bị dồn sang phải, cột còn ô dồn sang trái', () {
      final List<List<int?>> grid = [
        [0, null, 1],
      ];
      applyGravityAndCollapse(grid);
      expect(grid, [
        [0, 1, null],
      ]);
    });

    test('không refill — bàn chỉ vơi dần', () {
      final List<List<int?>> grid = [
        [null, null],
        [null, null],
      ];
      applyGravityAndCollapse(grid);
      expect(grid, [
        [null, null],
        [null, null],
      ]);
    });

    test('I2: lockGrid rơi lockstep theo cột cùng colorGrid', () {
      final List<List<int?>> grid = [
        [0, null],
        [null, null],
        [null, 1],
      ];
      final lockGrid = [
        [2, 0],
        [0, 0],
        [0, 3],
      ];
      applyGravityAndCollapse(grid, lockGrid: lockGrid);
      expect(grid, [
        [null, null],
        [null, null],
        [0, 1],
      ]);
      expect(lockGrid, [
        [0, 0],
        [0, 0],
        [2, 3],
      ]);
    });

    test('I2: lockGrid dồn lockstep theo cột cùng colorGrid', () {
      final List<List<int?>> grid = [
        [0, null, 1],
      ];
      final lockGrid = [
        [5, 0, 7],
      ];
      applyGravityAndCollapse(grid, lockGrid: lockGrid);
      expect(grid, [
        [0, 1, null],
      ]);
      expect(lockGrid, [
        [5, 7, 0],
      ]);
    });
  });

  group('I3: gravityDirection', () {
    test('up: ô rơi lên đỉnh cột, giữ thứ tự tương đối', () {
      final List<List<int?>> grid = [
        [null],
        [0],
        [1],
      ];
      applyGravityAndCollapse(grid, direction: GravityDirection.up);
      expect(grid, [
        [0],
        [1],
        [null],
      ]);
    });

    test('up: cột rỗng hoàn toàn dồn sang phải sau khi rơi', () {
      final List<List<int?>> grid = [
        [null, null],
        [null, 0],
      ];
      applyGravityAndCollapse(grid, direction: GravityDirection.up);
      expect(grid, [
        [0, null],
        [null, null],
      ]);
    });

    test('right: ô rơi sang phải trong hàng, giữ thứ tự tương đối', () {
      final List<List<int?>> grid = [
        [0, null, 1],
      ];
      applyGravityAndCollapse(grid, direction: GravityDirection.right);
      expect(grid, [
        [null, 0, 1],
      ]);
    });

    test('right: hàng rỗng hoàn toàn dồn xuống dưới sau khi rơi', () {
      final List<List<int?>> grid = [
        [null, null],
        [0, null],
      ];
      applyGravityAndCollapse(grid, direction: GravityDirection.right);
      expect(grid, [
        [null, 0],
        [null, null],
      ]);
    });

    test('left: ô rơi sang trái trong hàng, giữ thứ tự tương đối', () {
      final List<List<int?>> grid = [
        [null, 0, 1],
      ];
      applyGravityAndCollapse(grid, direction: GravityDirection.left);
      expect(grid, [
        [0, 1, null],
      ]);
    });

    test('left: hàng rỗng hoàn toàn dồn xuống dưới sau khi rơi', () {
      final List<List<int?>> grid = [
        [null, null],
        [null, 0],
      ];
      applyGravityAndCollapse(grid, direction: GravityDirection.left);
      expect(grid, [
        [0, null],
        [null, null],
      ]);
    });

    test('up: lockGrid vẫn rơi lockstep theo cột cùng colorGrid', () {
      final List<List<int?>> grid = [
        [null],
        [0],
      ];
      final lockGrid = [
        [0],
        [3],
      ];
      applyGravityAndCollapse(
        grid,
        lockGrid: lockGrid,
        direction: GravityDirection.up,
      );
      expect(grid, [
        [0],
        [null],
      ]);
      expect(lockGrid, [
        [3],
        [0],
      ]);
    });

    test('right cho kết quả đúng như down chạy trên grid đã transpose', () {
      final List<List<int?>> original = [
        [0, null, null],
        [null, 1, null],
      ];

      final transposed = [
        for (var c = 0; c < original[0].length; c++)
          [for (var r = 0; r < original.length; r++) original[r][c]],
      ];
      applyGravityAndCollapse(transposed);
      final expected = [
        for (var r = 0; r < original.length; r++)
          [for (var c = 0; c < original[0].length; c++) transposed[c][r]],
      ];

      applyGravityAndCollapse(original, direction: GravityDirection.right);
      expect(original, expected);
    });
  });
}

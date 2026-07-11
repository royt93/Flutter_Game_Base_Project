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
  });
}

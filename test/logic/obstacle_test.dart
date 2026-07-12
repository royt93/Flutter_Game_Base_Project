import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/obstacle.dart';

void main() {
  group('chipAdjacentObstacles', () {
    test('chip 1 độ bền obstacle liền kề ô vừa nổ', () {
      final grid = [
        [0, -2],
      ];
      final broken = chipAdjacentObstacles(grid, {const Point(0, 0)});
      expect(broken, isEmpty);
      expect(grid[0][1], -1);
    });

    test('hết độ bền thì vỡ thành null và được trả về', () {
      final grid = <List<int?>>[
        [0, -1],
      ];
      final broken = chipAdjacentObstacles(grid, {const Point(0, 0)});
      expect(broken, {const Point(0, 1)});
      expect(grid[0][1], isNull);
    });

    test('obstacle không liền kề ô nổ thì không bị ảnh hưởng', () {
      final grid = [
        [0, 1, -1],
      ];
      final broken = chipAdjacentObstacles(grid, {const Point(0, 0)});
      expect(broken, isEmpty);
      expect(grid[0][2], -1);
    });

    test('1 obstacle liền kề nhiều ô nổ trong cùng đợt chỉ bị chip 1 lần', () {
      final grid = [
        [0, -2, 0],
      ];
      final broken = chipAdjacentObstacles(grid, {
        const Point(0, 0),
        const Point(0, 2),
      });
      expect(broken, isEmpty);
      expect(grid[0][1], -1);
    });
  });
}

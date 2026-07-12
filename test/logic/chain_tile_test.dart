import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/chain_tile.dart';

void main() {
  group('chipAdjacentLocks', () {
    test('chip 1 lock của ô khoá liền kề ô vừa nổ', () {
      final lockGrid = [
        [0, 2],
      ];
      chipAdjacentLocks(lockGrid, {const Point(0, 0)});
      expect(lockGrid[0][1], 1);
    });

    test('ô lock=0 không bị ảnh hưởng', () {
      final lockGrid = [
        [0, 0],
      ];
      chipAdjacentLocks(lockGrid, {const Point(0, 0)});
      expect(lockGrid[0][1], 0);
    });

    test('ô khoá liền kề nhiều ô nổ trong cùng đợt chỉ mất đúng 1 lock', () {
      final lockGrid = [
        [0, 3, 0],
      ];
      chipAdjacentLocks(lockGrid, {const Point(0, 0), const Point(0, 2)});
      expect(lockGrid[0][1], 2);
    });

    test('ô khoá không liền kề ô nổ thì không đổi', () {
      final lockGrid = [
        [0, 0, 2],
      ];
      chipAdjacentLocks(lockGrid, {const Point(0, 0)});
      expect(lockGrid[0][2], 2);
    });
  });
}

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/mirror_board.dart';

void main() {
  group('generateMirrorBoard', () {
    test('is symmetric with even cols', () {
      final grid = generateMirrorBoard(9, 8, 5, Random(42));
      for (final row in grid) {
        for (var c = 0; c < row.length; c++) {
          expect(row[c], row[row.length - 1 - c]);
        }
      }
    });

    test('is symmetric with odd cols', () {
      final grid = generateMirrorBoard(9, 7, 5, Random(7));
      for (final row in grid) {
        for (var c = 0; c < row.length; c++) {
          expect(row[c], row[row.length - 1 - c]);
        }
      }
    });

    test('respects rows/cols/colorCount bounds', () {
      final grid = generateMirrorBoard(9, 8, 5, Random(1));
      expect(grid.length, 9);
      for (final row in grid) {
        expect(row.length, 8);
        for (final v in row) {
          expect(v, greaterThanOrEqualTo(0));
          expect(v, lessThan(5));
        }
      }
    });

    test('is deterministic given identically-seeded Random', () {
      final a = generateMirrorBoard(9, 8, 5, Random(123));
      final b = generateMirrorBoard(9, 8, 5, Random(123));
      expect(a, b);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/logic/gem_data.dart';
import 'package:neon_jewels/logic/match_detector.dart';

/// Diagonal gem (Wave 9): match 6+ → diagonal; hình học 2 đường chéo (X).
void main() {
  // Lưới 1 hàng N cột với run cùng màu ở đầu rồi 2 màu khác (chặn run).
  List<List<GemColor?>> rowRun(int runLen) {
    const c = GemColor.cyan, m = GemColor.magenta, l = GemColor.lime;
    final row = <GemColor?>[
      for (var i = 0; i < runLen; i++) c,
      m,
      l,
    ];
    return [row];
  }

  GemType specialOfRun(int runLen) {
    final g = MatchDetector.findMatches(rowRun(runLen));
    expect(g, isNotEmpty, reason: 'run $runLen phải có match');
    return g.first.special;
  }

  group('MatchDetector — match length → special', () {
    test('match 3 → không special', () {
      expect(specialOfRun(3), GemType.normal);
    });
    test('match 4 → striped (run ngang → stripedV)', () {
      expect(specialOfRun(4), GemType.stripedV);
    });
    test('match 5 → rainbow', () {
      expect(specialOfRun(5), GemType.rainbow);
    });
    test('match 6 → diagonal (MỚI)', () {
      expect(specialOfRun(6), GemType.diagonal);
    });
    test('match 7 → diagonal', () {
      expect(specialOfRun(7), GemType.diagonal);
    });

    test('diagonal đặt ở ô giữa run', () {
      final g = MatchDetector.findMatches(rowRun(6)).first;
      expect(g.special, GemType.diagonal);
      expect(g.specialAt, const Cell(0, 3)); // cells[6~/2]
    });

    test('match dọc 6 → diagonal', () {
      const c = GemColor.cyan, m = GemColor.magenta;
      final grid = <List<GemColor?>>[
        for (var i = 0; i < 6; i++) [c],
        [m],
        [m],
      ];
      final g = MatchDetector.findMatches(grid);
      expect(g.first.special, GemType.diagonal);
    });
  });

  group('diagonalCells — hình học 2 đường chéo (X)', () {
    test('tâm (3,3) trên 8×8, thickness 0 → đúng X (14 ô)', () {
      final cells = MatchDetector.diagonalCells(8, 8, const Cell(3, 3));
      // chéo ↘ r-c==0: (0,0..7,7) = 8 ô; chéo ↙ r+c==6: 7 ô; trùng (3,3) → 14
      expect(cells.length, 14);
      expect(cells.contains(const Cell(0, 0)), isTrue); // ↘
      expect(cells.contains(const Cell(7, 7)), isTrue); // ↘
      expect(cells.contains(const Cell(0, 6)), isTrue); // ↙
      expect(cells.contains(const Cell(6, 0)), isTrue); // ↙
      expect(cells.contains(const Cell(3, 3)), isTrue); // tâm
      expect(cells.contains(const Cell(0, 1)), isFalse); // ngoài chéo
    });

    test('tâm góc (0,0) thickness 0 → chỉ chéo chính (8 ô)', () {
      final cells = MatchDetector.diagonalCells(8, 8, const Cell(0, 0));
      // ↘: (0,0)..(7,7) = 8; ↙ qua góc chỉ có (0,0) → tổng 8
      expect(cells.length, 8);
      expect(cells.contains(const Cell(5, 5)), isTrue);
    });

    test('thickness 1 → X DÀY (nhiều ô hơn thickness 0)', () {
      final thin = MatchDetector.diagonalCells(8, 8, const Cell(3, 3));
      final fat = MatchDetector.diagonalCells(8, 8, const Cell(3, 3),
          thickness: 1);
      expect(fat.length, greaterThan(thin.length));
      // ô kề chéo chính (lệch 1) phải nằm trong X dày
      expect(fat.contains(const Cell(0, 1)), isTrue);
    });

    test('mọi ô trả về đều trong biên lưới', () {
      for (final center in [
        const Cell(0, 0),
        const Cell(7, 7),
        const Cell(2, 5),
        const Cell(4, 1),
      ]) {
        final cells =
            MatchDetector.diagonalCells(8, 8, center, thickness: 1);
        for (final c in cells) {
          expect(c.row, inInclusiveRange(0, 7));
          expect(c.col, inInclusiveRange(0, 7));
        }
      }
    });
  });
}

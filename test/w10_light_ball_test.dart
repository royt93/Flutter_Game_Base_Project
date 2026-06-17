import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/logic/gem_data.dart';
import 'package:neon_jewels/logic/match_detector.dart';

void main() {
  // Tạo run ngang dài [len] cùng màu trên bàn 8×8 (phần còn lại đa dạng để
  // không tạo match phụ) → lấy special của group đầu.
  GemType specialOfRun(int len) {
    // Nền KHÔNG BAO GIỜ dùng cyan (index 0) → run cyan ở hàng 0 đúng độ dài len,
    // không bị nối dài ngoài ý muốn. Lọc group theo màu cyan cho chắc chắn.
    final grid = List.generate(
      8,
      (r) => List.generate(8, (c) => GemColor.values[1 + ((c + r) % 5)]),
    );
    for (var c = 0; c < len; c++) {
      grid[0][c] = GemColor.cyan;
    }
    return MatchDetector.findMatches(grid)
        .firstWhere((g) => g.color == GemColor.cyan)
        .special;
  }

  group('Wave 10 — Light Ball: quy tắc tạo', () {
    test('match 6 vẫn là diagonal (không đổi)', () {
      expect(specialOfRun(6), GemType.diagonal);
    });
    test('match 7 → lightBall', () {
      expect(specialOfRun(7), GemType.lightBall);
    });
    test('match 8 → lightBall', () {
      expect(specialOfRun(8), GemType.lightBall);
    });
  });

  group('Wave 10 — Light Ball: hình học lightBallCells', () {
    test('tâm (3,3) trên 8×8 = hàng + cột + 2 chéo, đúng 28 ô', () {
      final cells = MatchDetector.lightBallCells(8, 8, const Cell(3, 3));
      expect(cells.length, 28);
      // đủ cả hàng 3
      for (var c = 0; c < 8; c++) {
        expect(cells.contains(Cell(3, c)), isTrue, reason: 'hàng (3,$c)');
      }
      // đủ cả cột 3
      for (var r = 0; r < 8; r++) {
        expect(cells.contains(Cell(r, 3)), isTrue, reason: 'cột ($r,3)');
      }
      // góc chéo
      expect(cells.contains(const Cell(0, 0)), isTrue);
      expect(cells.contains(const Cell(7, 7)), isTrue);
      expect(cells.contains(const Cell(6, 0)), isTrue);
    });

    test('là SIÊU TẬP của diagonalCells (mạnh hơn diagonal)', () {
      const center = Cell(2, 5);
      final diag = MatchDetector.diagonalCells(8, 8, center);
      final lb = MatchDetector.lightBallCells(8, 8, center);
      expect(lb.containsAll(diag), isTrue);
      expect(lb.length, greaterThan(diag.length));
    });

    test('thickness > 0 → phủ rộng hơn', () {
      const center = Cell(3, 3);
      final thin = MatchDetector.lightBallCells(8, 8, center);
      final fat = MatchDetector.lightBallCells(8, 8, center, thickness: 1);
      expect(fat.length, greaterThan(thin.length));
      // mọi ô trong biên
      for (final c in fat) {
        expect(c.row, inInclusiveRange(0, 7));
        expect(c.col, inInclusiveRange(0, 7));
      }
    });
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/boss_tile.dart';
import 'package:pop_star_blast/logic/gift_tile.dart';
import 'package:pop_star_blast/logic/puzzle_code.dart';

List<List<int?>> _grid(int rows, int cols, int? Function(int r, int c) fill) =>
    List.generate(rows, (r) => List.generate(cols, (c) => fill(r, c)));

String _b64(String raw) => base64Url.encode(utf8.encode(raw));

void main() {
  group('encodePuzzleGrid / decodePuzzleGrid round-trip', () {
    test('bàn 8x6 toàn màu tuần tự', () {
      final grid = _grid(8, 6, (r, c) => (r + c) % 4);
      final decoded = decodePuzzleGrid(encodePuzzleGrid(grid));
      expect(decoded, grid);
    });

    test('bàn 11x12 toàn màu tuần tự', () {
      final grid = _grid(11, 12, (r, c) => (r * c) % 7);
      final decoded = decodePuzzleGrid(encodePuzzleGrid(grid));
      expect(decoded, grid);
    });

    test('ô null xen kẽ nhiều vị trí', () {
      final grid = _grid(8, 6, (r, c) => (r + c).isEven ? null : (r % 4));
      final decoded = decodePuzzleGrid(encodePuzzleGrid(grid));
      expect(decoded, grid);
    });

    test('obstacle và gift cùng bàn', () {
      final grid = _grid(8, 6, (r, c) {
        if (c == 0) return -1;
        if (c == 1) return -3;
        if (c == 2) return giftTileValue;
        return r % 4;
      });
      final decoded = decodePuzzleGrid(encodePuzzleGrid(grid));
      expect(decoded, grid);
    });

    test('bàn rỗng hoàn toàn (toàn null) round-trip thành công', () {
      final grid = _grid(8, 6, (r, c) => null);
      final decoded = decodePuzzleGrid(encodePuzzleGrid(grid));
      expect(decoded, grid);
      expect(hasAnyGem(decoded!), isFalse);
    });

    test('bàn 0x0 round-trip thành công', () {
      final grid = <List<int?>>[];
      final decoded = decodePuzzleGrid(encodePuzzleGrid(grid));
      expect(decoded, grid);
    });
  });

  group('decodePuzzleGrid — input hỏng', () {
    test('chuỗi rác không phải base64 hợp lệ -> null', () {
      expect(decodePuzzleGrid('!!!not-base64!!!'), isNull);
    });

    test('base64 hợp lệ nhưng thiếu phần | -> null', () {
      expect(decodePuzzleGrid(_b64('8|6')), isNull);
    });

    test(
      'kích thước không khớp: khai báo nhiều hàng hơn dữ liệu thật -> null',
      () {
        // Khai báo rows=4 nhưng chỉ có 3 hàng dữ liệu (2 dấu ';').
        final tampered = _b64('4|2|0,0;0,0;0,0');
        expect(decodePuzzleGrid(tampered), isNull);
      },
    );

    test('kích thước không khớp: 1 hàng có số cột sai -> null', () {
      final tampered = _b64('2|3|0,1,2;0,1');
      expect(decodePuzzleGrid(tampered), isNull);
    });

    test('màu ngoài phạm vi hợp lệ (7, 100) -> null', () {
      expect(decodePuzzleGrid(_b64('1|1|7')), isNull);
      expect(decodePuzzleGrid(_b64('1|1|100')), isNull);
    });

    test('boss tile id (<= -2000) -> null', () {
      expect(decodePuzzleGrid(_b64('1|1|$bossTileIdBase')), isNull);
    });

    test('obstacle âm hợp lệ khác gift/boss (vd -5) được chấp nhận', () {
      final decoded = decodePuzzleGrid(_b64('1|1|-5'));
      expect(decoded, [
        [-5],
      ]);
    });
  });

  group('hasAnyGem', () {
    test('toàn null/obstacle/gift -> false', () {
      final grid = _grid(3, 3, (r, c) {
        if (c == 0) return null;
        if (c == 1) return -1;
        return giftTileValue;
      });
      expect(hasAnyGem(grid), isFalse);
    });

    test('có ít nhất 1 màu >= 0 -> true', () {
      final grid = _grid(3, 3, (r, c) => c == 2 ? 0 : null);
      expect(hasAnyGem(grid), isTrue);
    });
  });

  test('fillEmptyCells: null -> 0, giữ nguyên giá trị khác', () {
    final grid = _grid(2, 2, (r, c) => (r == 0 && c == 0) ? null : -1);
    expect(fillEmptyCells(grid), [
      [0, -1],
      [-1, -1],
    ]);
  });

  group('cyclePuzzleCellValue', () {
    test('full cycle colorCount=4', () {
      int? v;
      final seen = <int?>[v];
      for (var i = 0; i < 6; i++) {
        v = cyclePuzzleCellValue(v, 4);
        seen.add(v);
      }
      expect(seen, [null, 0, 1, 2, 3, -1, giftTileValue]);
      expect(cyclePuzzleCellValue(giftTileValue, 4), isNull);
    });

    test('full cycle colorCount=7', () {
      int? v;
      final seen = <int?>[v];
      for (var i = 0; i < 9; i++) {
        v = cyclePuzzleCellValue(v, 7);
        seen.add(v);
      }
      expect(seen, [null, 0, 1, 2, 3, 4, 5, 6, -1, giftTileValue]);
      expect(cyclePuzzleCellValue(giftTileValue, 7), isNull);
    });
  });
}

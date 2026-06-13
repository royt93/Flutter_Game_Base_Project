import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/logic/gem_data.dart';
import 'package:neon_jewels/logic/match_detector.dart';

// Helper dựng lưới ngắn gọn từ ký tự: c m l y o p, '.' = null.
List<List<GemColor?>> grid(List<String> rows) {
  GemColor? parse(String ch) {
    switch (ch) {
      case 'c':
        return GemColor.cyan;
      case 'm':
        return GemColor.magenta;
      case 'l':
        return GemColor.lime;
      case 'y':
        return GemColor.yellow;
      case 'o':
        return GemColor.orange;
      case 'p':
        return GemColor.purple;
      default:
        return null;
    }
  }

  return rows.map((r) => r.split('').map(parse).toList()).toList();
}

void main() {
  group('MatchDetector — match cơ bản', () {
    test('match 3 ngang', () {
      final g = grid([
        'cccm',
        'ompy',
        'lyol',
        'pmlc',
      ]);
      final matches = MatchDetector.findMatches(g);
      expect(matches.length, 1);
      expect(matches.first.cells.length, 3);
      expect(matches.first.special, GemType.normal);
    });

    test('match 3 dọc', () {
      final g = grid([
        'cmlo',
        'cpyp',
        'colm',
        'pmlc',
      ]);
      final matches = MatchDetector.findMatches(g);
      expect(matches.any((m) => m.cells.length == 3), isTrue);
    });

    test('match 3 ở góc lưới', () {
      final g = grid([
        'ccc',
        'mlo',
        'oml',
      ]);
      final matches = MatchDetector.findMatches(g);
      expect(matches.length, 1);
      expect(matches.first.cells.first, const Cell(0, 0));
    });

    test('lưới không match', () {
      final g = grid([
        'cmlo',
        'ocml',
        'locm',
        'mloc',
      ]);
      expect(MatchDetector.hasMatch(g), isFalse);
      expect(MatchDetector.findMatches(g), isEmpty);
    });

    test('lưới rỗng', () {
      expect(MatchDetector.findMatches(const []), isEmpty);
    });

    test('bỏ qua ô null khi quét', () {
      final g = grid([
        'c.cc',
        'mmpp',
        'lyol',
        'pmlc',
      ]);
      // hàng 0: c . c c -> không phải run 3 liền nhau qua ô null
      final matches = MatchDetector.findMatches(g);
      expect(matches.where((m) => m.cells.contains(const Cell(0, 0))), isEmpty);
    });
  });

  group('MatchDetector — special gems', () {
    test('match 4 ngang tạo striped dọc', () {
      final g = grid([
        'cccc',
        'ompy',
        'lyol',
        'pmyc',
      ]);
      final four = MatchDetector.findMatches(g).firstWhere((m) => m.cells.length == 4);
      expect(four.special, GemType.stripedV);
      expect(four.specialAt, isNotNull);
    });

    test('match 4 dọc tạo striped ngang', () {
      final g = grid([
        'cmlo',
        'cpyp',
        'colm',
        'cmlp',
      ]);
      final four = MatchDetector.findMatches(g).firstWhere((m) => m.cells.length == 4);
      expect(four.special, GemType.stripedH);
    });

    test('match 5 ngang tạo rainbow', () {
      final g = grid([
        'ccccc',
        'ompyo',
        'lyoly',
        'pmycp',
        'oplmo',
      ]);
      final five = MatchDetector.findMatches(g).firstWhere((m) => m.cells.length == 5);
      expect(five.special, GemType.rainbow);
      expect(five.specialAt, isNotNull);
    });

    test('match 3 không tạo special', () {
      final g = grid([
        'cccm',
        'ompy',
        'lyol',
        'pmlc',
      ]);
      expect(MatchDetector.findMatches(g).first.special, GemType.normal);
      expect(MatchDetector.findMatches(g).first.specialAt, isNull);
    });
  });

  group('MatchDetector — nhiều match & gộp', () {
    test('phát hiện nhiều run cùng lúc', () {
      final g = grid([
        'cccm',
        'mmmp',
        'lyol',
        'pmlc',
      ]);
      final matches = MatchDetector.findMatches(g);
      expect(matches.length, 2);
    });

    test('allCells gộp đúng số ô không trùng', () {
      final g = grid([
        'cccm',
        'mmmp',
        'lyol',
        'pmlc',
      ]);
      expect(MatchDetector.allCells(MatchDetector.findMatches(g)).length, 6);
    });

    test('match chữ thập (ngang + dọc giao nhau) — ô giao không bị đếm 2 lần', () {
      // cột giữa và hàng giữa cùng màu c
      final g = grid([
        'mcm',
        'ccc',
        'mcm',
      ]);
      final matches = MatchDetector.findMatches(g);
      // 1 run ngang (3) + 1 run dọc (3), giao tại (1,1)
      expect(matches.length, 2);
      expect(MatchDetector.allCells(matches).length, 5); // 3+3-1
    });
  });
}

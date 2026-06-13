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
  group('MatchDetector', () {
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

    test('match 4 ngang tạo striped', () {
      final g = grid([
        'cccc',
        'ompy',
        'lyol',
        'pmyc',
      ]);
      final matches = MatchDetector.findMatches(g);
      final four = matches.firstWhere((m) => m.cells.length == 4);
      // run ngang dài 4 -> striped dọc
      expect(four.special, GemType.stripedV);
      expect(four.specialAt, isNotNull);
    });

    test('match 5 ngang tạo rainbow', () {
      final g = grid([
        'ccccc',
        'ompyo',
        'lyoly',
        'pmycp',
        'oplmo',
      ]);
      final matches = MatchDetector.findMatches(g);
      final five = matches.firstWhere((m) => m.cells.length == 5);
      expect(five.special, GemType.rainbow);
    });

    test('lưới không match', () {
      final g = grid([
        'cmlo',
        'ocml',
        'locm',
        'mloc',
      ]);
      expect(MatchDetector.hasMatch(g), isFalse);
    });

    test('allCells gộp đúng số ô', () {
      final g = grid([
        'cccm',
        'mmmp',
        'lyol',
        'pmlc',
      ]);
      final matches = MatchDetector.findMatches(g);
      expect(MatchDetector.allCells(matches).length, 6);
    });
  });
}

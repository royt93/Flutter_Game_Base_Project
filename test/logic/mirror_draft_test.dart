import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/mirror_board.dart';
import 'package:pop_star_blast/logic/mirror_draft.dart';

/// F21 Mirror Draft.
///
/// Luật dễ gây tranh cãi nhất, và task yêu cầu chốt rõ + test cả hai nhánh:
/// nhóm gương **chỉ** nổ khi nó cũng hợp lệ ở nửa bên kia. Không hợp lệ thì
/// chỉ nổ bên người tap, và bàn phân kỳ dần — đó là **đặc điểm**, không phải
/// lỗi.
List<List<int?>> _g(List<List<int?>> rows) => rows;

void main() {
  group('trục gương', () {
    test('cột soi đúng sang cột đối diện', () {
      expect(mirrorColumn(0, 8), 7);
      expect(mirrorColumn(3, 8), 4);
      expect(mirrorColumn(7, 8), 0);
    });

    test('nửa của người chơi 1 là nửa trái', () {
      expect(isPlayerOneHalf(0, 8), isTrue);
      expect(isPlayerOneHalf(3, 8), isTrue);
      expect(isPlayerOneHalf(4, 8), isFalse);
    });

    test('cột giữa chỉ tồn tại khi số cột lẻ', () {
      expect(isCenterColumn(2, 5), isTrue);
      expect(isCenterColumn(4, 8), isFalse);
      expect(isCenterColumn(3, 8), isFalse);
    });
  });

  group('nhóm gương HỢP LỆ -> nổ cả hai', () {
    test('bàn đối xứng nguyên vẹn', () {
      final g = _g([
        [0, 0, 1, 1, 0, 0],
        [2, 2, 1, 1, 2, 2],
      ]);
      final r = mirrorDraftCells(g, 0, 0);

      expect(r.isValid, isTrue);
      expect(r.mirroredToo, isTrue);
      expect(r.tappedCells.length, 2);
      expect(r.mirroredCells.length, 2);
      expect(r.allCells.length, 4);
    });

    test('nhóm gương nằm đúng cột đối xứng', () {
      final g = _g([
        [0, 0, 1, 1, 0, 0],
        [2, 2, 1, 1, 2, 2],
      ]);
      final cols = r0(g);
      final r = mirrorDraftCells(g, 0, 0);
      for (final c in r.mirroredCells) {
        expect(c.y, greaterThanOrEqualTo(cols ~/ 2));
      }
    });
  });

  group('nhóm gương KHÔNG hợp lệ -> chỉ nổ bên tap', () {
    test('nửa kia đã phân kỳ, không còn nhóm', () {
      // Nửa phải bị phá đối xứng: cột 4,5 không cùng màu nhau.
      final g = _g([
        [0, 0, 1, 1, 2, 3],
        [2, 2, 1, 1, 3, 2],
      ]);
      final r = mirrorDraftCells(g, 0, 0);

      expect(r.isValid, isTrue);
      expect(
        r.mirroredToo,
        isFalse,
        reason: 'nửa kia không có nhóm hợp lệ thì không được nổ bừa',
      );
      expect(r.allCells, r.tappedCells);
    });

    test('cột giữa (bàn lẻ) -> không có nhóm gương riêng', () {
      final g = _g([
        [0, 1, 2, 1, 0],
        [0, 1, 2, 1, 0],
      ]);
      final r = mirrorDraftCells(g, 0, 2);

      expect(r.isValid, isTrue);
      expect(r.mirroredToo, isFalse, reason: 'cột giữa tự soi vào chính nó');
    });

    test('nhóm chạy NGANG qua trục -> không nhân đôi', () {
      // Tap col 1 gom luôn cả 4 ô giữa; nhóm "gương" chính là nhóm đó.
      final g = _g([
        [2, 1, 1, 1, 1, 2],
        [2, 0, 0, 0, 0, 2],
      ]);
      final r = mirrorDraftCells(g, 0, 1);

      expect(r.isValid, isTrue);
      expect(
        r.mirroredToo,
        isFalse,
        reason: 'hai bên là MỘT nhóm — nổ một lần là đủ',
      );
      expect(r.allCells.length, r.tappedCells.length);
    });
  });

  group('nước đi không hợp lệ', () {
    test('nhóm < 2 -> rỗng', () {
      final g = _g([
        [0, 1, 2, 3],
        [3, 2, 1, 0],
      ]);
      final r = mirrorDraftCells(g, 0, 0);
      expect(r.isValid, isFalse);
      expect(r.allCells, isEmpty);
    });

    test('toạ độ ngoài bàn -> rỗng, không ném', () {
      final g = _g([
        [0, 0],
        [0, 0],
      ]);
      for (final t in [(-1, 0), (0, -1), (99, 0), (0, 99)]) {
        expect(mirrorDraftCells(g, t.$1, t.$2).isValid, isFalse);
      }
    });

    test('bàn rỗng -> rỗng, không ném', () {
      expect(mirrorDraftCells(const [], 0, 0).isValid, isFalse);
      expect(mirrorDraftCells(const [[]], 0, 0).isValid, isFalse);
    });
  });

  group('không sửa bàn', () {
    test('chỉ TÍNH ô cần nổ, không tự xoá', () {
      final g = _g([
        [0, 0, 1, 1, 0, 0],
        [2, 2, 1, 1, 2, 2],
      ]);
      final before = g.map((r) => List<int?>.from(r)).toList();
      mirrorDraftCells(g, 0, 0);
      expect(g, equals(before));
    });
  });

  group('nối với bàn gương thật (I47)', () {
    test('bàn mới sinh: tap hợp lệ luôn nổ được cả hai nửa', () {
      // Bàn vừa sinh còn đối xứng tuyệt đối, nên mọi nhóm hợp lệ ở nửa này
      // đều có nhóm tương ứng ở nửa kia — trừ nhóm chạy ngang trục.
      final board = generateMirrorBoard(9, 8, 5, Random(7));
      final g = board.map((r) => List<int?>.from(r)).toList();

      var checked = 0;
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 4; c++) {
          final res = mirrorDraftCells(g, r, c);
          if (!res.isValid) continue;
          checked++;
          // Hoặc nổ được cả hai, hoặc là nhóm chạy ngang trục (đã gộp).
          final spansAxis = res.tappedCells.any((p) => p.y >= 4);
          expect(
            res.mirroredToo || spansAxis,
            isTrue,
            reason: 'tap ($r,$c) không nổ gương mà cũng không chạy ngang trục',
          );
        }
      }
      expect(checked, greaterThan(0), reason: 'bàn thử không có nước đi nào');
    });
  });
}

int r0(List<List<int?>> g) => g.first.length;

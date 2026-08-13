import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/puzzle_presets.dart';
import 'package:pop_star_blast/logic/gift_tile.dart';
import 'package:pop_star_blast/logic/puzzle_code.dart';
import 'package:pop_star_blast/logic/puzzle_daily.dart';

/// F18 — "Bàn hôm nay".
///
/// Hai thứ đáng khoá nhất:
/// 1. **Tất định theo epoch-day** — cùng ngày mở app bao nhiêu lần cũng ra
///    cùng bàn, và không đọc đồng hồ trong generator.
/// 2. **Bàn không chơi được bị loại** — người chơi tự vẽ bàn, nên bàn rác là
///    trạng thái bình thường chứ không phải ngoại lệ.
List<List<int?>> _grid(List<List<int?>> rows) => rows;

/// Bàn 4x4 một màu: chắc chắn chơi được.
List<List<int?>> _solid(int color) =>
    List.generate(4, (_) => List<int?>.filled(4, color));

/// Bàn xen kẽ hoàn toàn: không có nhóm >= 2 nào.
List<List<int?>> _checker(int side) => List.generate(
  side,
  (r) => List<int?>.generate(side, (c) => (r + c) % 2),
);

void main() {
  group('cận trên điểm', () {
    test('bàn rỗng -> 0', () {
      expect(puzzleMaxPossibleScore(const []), 0);
    });

    test('bỏ qua ô trống và ô đặc biệt (giá trị âm)', () {
      final g = _grid([
        [0, 0, null],
        [-1, 0, giftTileValue],
      ]);
      // Chỉ 3 ô màu 0 được tính.
      expect(puzzleMaxPossibleScore(g), 5 * 3 * 2);
    });

    test('nhiều màu -> cộng dồn từng màu', () {
      final g = _grid([
        [0, 0],
        [1, 1],
      ]);
      expect(puzzleMaxPossibleScore(g), 5 * 2 * 1 * 2);
    });

    test('là CẬN TRÊN: không nhỏ hơn điểm thật của bàn liền một khối', () {
      // Bàn 1 màu liền khối: điểm thật đúng bằng cận trên.
      expect(puzzleMaxPossibleScore(_solid(0)), 5 * 16 * 15);
    });
  });

  group('lọc bàn chơi được', () {
    test('bàn rỗng -> loại', () {
      expect(isPuzzleBoardPlayable(const []), isFalse);
    });

    test('bàn không có gem nào -> loại', () {
      expect(
        isPuzzleBoardPlayable(_grid([
          [null, -1],
          [-1, null],
        ])),
        isFalse,
      );
    });

    test('bàn xen kẽ hoàn toàn -> loại (không có nước đi nào)', () {
      expect(
        isPuzzleBoardPlayable(_checker(8)),
        isFalse,
        reason: 'không có nhóm >= 2 thì ván bắt đầu đã kẹt',
      );
    });

    test('bàn quá ít điểm so với target -> loại', () {
      // 2 ô cùng màu trên bàn 4x4: cận trên 10 < target 4*4*6 = 96.
      final g = List.generate(
        4,
        (r) => List<int?>.generate(4, (c) => r == 0 && c < 2 ? 0 : null),
      );
      expect(puzzleMaxPossibleScore(g), lessThan(puzzleTargetScore(4, 4)));
      expect(isPuzzleBoardPlayable(g), isFalse);
    });

    test('bàn một màu liền khối -> chơi được', () {
      expect(isPuzzleBoardPlayable(_solid(0)), isTrue);
    });
  });

  group('bộ preset', () {
    test('mọi mã preset đều decode được', () {
      for (final p in kPuzzlePresets) {
        expect(decodePuzzleGrid(p.code), isNotNull, reason: p.id);
      }
    });

    test('id preset không trùng nhau', () {
      final ids = kPuzzlePresets.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('đủ số preset chơi được để vòng chọn có ý nghĩa', () {
      final playable = playablePuzzleBoards(
        kPuzzlePresets.map((p) => p.code).toList(),
      );
      expect(
        playable.length,
        greaterThanOrEqualTo(10),
        reason: 'ít bàn quá thì "bàn hôm nay" lặp lại liên tục',
      );
    });

    test('preset checker bị loại đúng như dự kiến', () {
      // Ca kiểm thử sống cho chính bộ lọc: preset này cố ý giữ trong bảng.
      final checker = kPuzzlePresets.firstWhere((p) => p.id == 'checker');
      expect(isPuzzleBoardPlayable(decodePuzzleGrid(checker.code)!), isFalse);
      expect(playablePuzzleBoards([checker.code]), isEmpty);
    });

    test('mã hỏng bị bỏ qua, không ném', () {
      final out = playablePuzzleBoards([
        'khong-phai-base64!!!',
        kPuzzlePresets.first.code,
      ]);
      expect(out.length, 1);
    });
  });

  group('chọn tất định', () {
    test('cùng ngày -> cùng chỉ số, gọi bao nhiêu lần cũng vậy', () {
      for (var day = 20000; day < 20010; day++) {
        final a = pickPuzzleDailyIndex(day, 11);
        for (var i = 0; i < 5; i++) {
          expect(pickPuzzleDailyIndex(day, 11), a, reason: 'day $day');
        }
      }
    });

    test('không còn bàn nào -> -1, không ném', () {
      expect(pickPuzzleDailyIndex(20000, 0), -1);
      expect(pickPuzzleDailyIndex(20000, -3), -1);
    });

    test('chỉ số luôn nằm trong khoảng hợp lệ', () {
      for (var day = 0; day < 500; day++) {
        final i = pickPuzzleDailyIndex(day, 7);
        expect(i, inInclusiveRange(0, 6), reason: 'day $day');
      }
    });

    test('trải đều: 60 ngày phủ hết mọi bàn, không lặp dài', () {
      // Đo thật trước khi chốt ngưỡng (xem ghi chú trong `pickPuzzleDailyIndex`):
      // gieo trần epoch-day cho đủ 11/11 bàn và chuỗi lặp dài nhất 3.
      const n = 11;
      final idx = [
        for (var day = 20000; day < 20060; day++) pickPuzzleDailyIndex(day, n),
      ];

      expect(idx.toSet().length, n, reason: 'có bàn không bao giờ được chọn');

      var maxRun = 1, run = 1;
      for (var i = 1; i < idx.length; i++) {
        run = idx[i] == idx[i - 1] ? run + 1 : 1;
        if (run > maxRun) maxRun = run;
      }
      expect(
        maxRun,
        lessThanOrEqualTo(4),
        reason: 'cùng một bàn lặp $maxRun ngày liền là hỏng cảm giác "hôm nay"',
      );
    });

    test('chọn bàn: cùng ngày ra cùng bàn', () {
      final codes = kPuzzlePresets.map((p) => p.code).toList();
      final a = pickPuzzleDailyBoard(20123, codes);
      final b = pickPuzzleDailyBoard(20123, codes);
      expect(a, isNotNull);
      expect(a, equals(b));
    });

    test('chọn bàn: mọi mã đều hỏng -> null', () {
      expect(pickPuzzleDailyBoard(20123, ['rac', 'rac2']), isNull);
    });

    test('chọn bàn: chỉ còn bàn không chơi được -> null', () {
      final checker = kPuzzlePresets.firstWhere((p) => p.id == 'checker');
      expect(pickPuzzleDailyBoard(20123, [checker.code]), isNull);
    });

    test('bàn trả về luôn là bàn chơi được', () {
      final codes = kPuzzlePresets.map((p) => p.code).toList();
      for (var day = 20000; day < 20050; day++) {
        final b = pickPuzzleDailyBoard(day, codes);
        expect(b, isNotNull, reason: 'day $day');
        expect(isPuzzleBoardPlayable(b!), isTrue, reason: 'day $day');
      }
    });
  });
}

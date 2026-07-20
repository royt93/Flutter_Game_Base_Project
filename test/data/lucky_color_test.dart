import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/lucky_color.dart';

void main() {
  group('luckyColorIndexForDay', () {
    test('deterministic — cùng epochDay/colorCount ra cùng kết quả', () {
      final a = luckyColorIndexForDay(20_000, 6);
      final b = luckyColorIndexForDay(20_000, 6);
      expect(a, b);
    });

    test('luôn trong khoảng [0, colorCount) với colorCount 4..7', () {
      for (var colorCount = 4; colorCount <= 7; colorCount++) {
        for (var epochDay = 0; epochDay < 200; epochDay++) {
          final index = luckyColorIndexForDay(epochDay, colorCount);
          expect(index, greaterThanOrEqualTo(0));
          expect(index, lessThan(colorCount));
        }
      }
    });

    test(
      'ngày khác nhau có thể ra màu khác nhau (không cố định 1 giá trị)',
      () {
        final results = {
          for (var day = 0; day < 50; day++) luckyColorIndexForDay(day, 6),
        };
        expect(results.length, greaterThan(1));
      },
    );
  });
}

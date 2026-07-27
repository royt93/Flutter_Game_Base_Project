import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/levels.dart';
import 'package:pop_star_blast/data/weekly_featured.dart';

void main() {
  test('cùng epoch-week → cùng level (deterministic)', () {
    expect(featuredLevelIdForWeek(100), featuredLevelIdForWeek(100));
  });

  test('luôn nằm trong khoảng level campaign hợp lệ', () {
    for (var week = 0; week < kLevelCount * 3; week++) {
      final id = featuredLevelIdForWeek(week);
      expect(id, greaterThanOrEqualTo(1));
      expect(id, lessThanOrEqualTo(kLevelCount));
    }
  });

  test('tuần hoàn đều theo % kLevelCount', () {
    for (var week = 0; week < kLevelCount * 2; week++) {
      expect(featuredLevelIdForWeek(week), week % kLevelCount + 1);
    }
  });

  test('các tuần khác nhau ra level khác nhau (không cố định 1 giá trị)', () {
    final ids = {
      for (var week = 0; week < kLevelCount; week++)
        featuredLevelIdForWeek(week),
    };
    expect(ids.length, kLevelCount);
  });
}

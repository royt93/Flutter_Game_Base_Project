import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/weekly_goal.dart';

void main() {
  group('weekIndexForEpochDay', () {
    test('chia đúng theo 7 ngày, không cần khớp lịch dương', () {
      expect(weekIndexForEpochDay(0), 0);
      expect(weekIndexForEpochDay(6), 0);
      expect(weekIndexForEpochDay(7), 1);
      expect(weekIndexForEpochDay(13), 1);
      expect(weekIndexForEpochDay(14), 2);
    });
  });

  group('weeklyGoalProgressForWeek', () {
    test('tuần không đổi giữ nguyên tiến độ', () {
      expect(
        weeklyGoalProgressForWeek(
          previousWeek: 10,
          currentWeek: 10,
          previousProgress: 120,
        ),
        120,
      );
    });

    test('sang tuần mới reset tiến độ về 0', () {
      expect(
        weeklyGoalProgressForWeek(
          previousWeek: 10,
          currentWeek: 11,
          previousProgress: 300,
        ),
        0,
      );
    });

    test('tuần nhảy nhiều hơn 1 (bỏ tuần) vẫn reset về 0', () {
      expect(
        weeklyGoalProgressForWeek(
          previousWeek: 10,
          currentWeek: 15,
          previousProgress: 300,
        ),
        0,
      );
    });
  });
}

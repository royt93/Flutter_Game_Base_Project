import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/login_streak.dart';

void main() {
  group('nextLoginStreak', () {
    test('gap 0 (đã điểm danh hôm nay) giữ nguyên streak', () {
      expect(
        nextLoginStreak(
          previousEpochDay: 100,
          todayEpochDay: 100,
          previousStreak: 4,
        ),
        4,
      );
    });

    test('gap 1 (ngày liên tiếp) tăng streak lên 1', () {
      expect(
        nextLoginStreak(
          previousEpochDay: 100,
          todayEpochDay: 101,
          previousStreak: 4,
        ),
        5,
      );
    });

    test('gap >= 2 (bỏ ngày) reset streak về 1', () {
      expect(
        nextLoginStreak(
          previousEpochDay: 100,
          todayEpochDay: 102,
          previousStreak: 4,
        ),
        1,
      );
      expect(
        nextLoginStreak(
          previousEpochDay: 100,
          todayEpochDay: 200,
          previousStreak: 6,
        ),
        1,
      );
    });

    test(
      'previousEpochDay=-1 (chưa từng điểm danh) coi như gap lớn, reset về 1',
      () {
        expect(
          nextLoginStreak(
            previousEpochDay: -1,
            todayEpochDay: 0,
            previousStreak: 0,
          ),
          1,
        );
      },
    );

    test('gap âm (đồng hồ lùi) giữ nguyên streak (không cho tăng)', () {
      expect(
        nextLoginStreak(
          previousEpochDay: 100,
          todayEpochDay: 99,
          previousStreak: 3,
        ),
        3,
      );
    });
  });
}

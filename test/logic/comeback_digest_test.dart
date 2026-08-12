import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/comeback_digest.dart';

/// I86 — digest "bạn đã bỏ lỡ gì".
///
/// Giá trị của tính năng nằm ở chỗ **chỉ nói điều đúng**. Một dòng sai (nhắc
/// rương đã nhận, nhắc mùa vừa reset) làm hỏng niềm tin vào cả popup, nên test
/// tập trung vào các điều kiện im lặng.
List<String> _keys(List<DigestLine> lines) => lines.map((l) => l.key).toList();

List<DigestLine> _digest({
  int daysAway = 5,
  int totalStars = 0,
  int nextChestStars = 0,
  int weeklyGoalProgress = 0,
  int weeklyGoalTarget = 300,
  int seasonDaysLeft = 0,
  int unlockedLevel = 10,
  int levelCount = 260,
}) => buildComebackDigest(
  daysAway: daysAway,
  totalStars: totalStars,
  nextChestStars: nextChestStars,
  weeklyGoalProgress: weeklyGoalProgress,
  weeklyGoalTarget: weeklyGoalTarget,
  seasonDaysLeft: seasonDaysLeft,
  unlockedLevel: unlockedLevel,
  levelCount: levelCount,
);

void main() {
  group('giới hạn', () {
    test('không bao giờ quá kMaxDigestLines', () {
      final d = _digest(
        daysAway: 9,
        totalStars: 10,
        nextChestStars: 30,
        weeklyGoalProgress: 100,
        seasonDaysLeft: 2,
      );
      expect(d.length, kMaxDigestLines);
    });

    test('không có gì để nói -> rỗng (UI chỉ hiện thưởng)', () {
      expect(
        _digest(daysAway: 0, unlockedLevel: 261, levelCount: 260),
        isEmpty,
      );
    });
  });

  group('số ngày vắng', () {
    test('vắng nhiều ngày -> có dòng, mang đúng số', () {
      final d = _digest(daysAway: 12);
      expect(d.first.key, 'digest_days_away');
      expect(d.first.params['n'], '12');
    });

    test('0 ngày -> không nhắc', () {
      expect(_keys(_digest(daysAway: 0)), isNot(contains('digest_days_away')));
    });
  });

  group('rương kế tiếp', () {
    test('còn thiếu sao -> nhắc đúng số còn thiếu', () {
      final d = _digest(totalStars: 12, nextChestStars: 15);
      final line = d.firstWhere((l) => l.key == 'digest_stars_to_chest');
      expect(line.params['n'], '3');
    });

    test('đã nhận hết mốc (nextChestStars = 0) -> im lặng', () {
      expect(
        _keys(_digest(totalStars: 999, nextChestStars: 0)),
        isNot(contains('digest_stars_to_chest')),
      );
    });

    test('đã đủ sao cho mốc kế -> im lặng (không nói "còn 0 sao")', () {
      expect(
        _keys(_digest(totalStars: 30, nextChestStars: 30)),
        isNot(contains('digest_stars_to_chest')),
      );
    });
  });

  group('mục tiêu tuần', () {
    test('đã bắt đầu, chưa xong -> nhắc phần còn lại', () {
      final d = _digest(weeklyGoalProgress: 120, weeklyGoalTarget: 300);
      final line = d.firstWhere((l) => l.key == 'digest_weekly_left');
      expect(line.params['n'], '180');
    });

    test('chưa đóng góp gì -> im lặng', () {
      expect(
        _keys(_digest(weeklyGoalProgress: 0)),
        isNot(contains('digest_weekly_left')),
        reason: '"còn 300/300" không nói lên điều gì',
      );
    });

    test('đã xong -> im lặng', () {
      expect(
        _keys(_digest(weeklyGoalProgress: 300, weeklyGoalTarget: 300)),
        isNot(contains('digest_weekly_left')),
      );
    });
  });

  group('mùa', () {
    test('sắp hết (<=7 ngày) -> nhắc', () {
      expect(
        _keys(_digest(daysAway: 0, seasonDaysLeft: 3)),
        contains('digest_season_ending'),
      );
    });

    test('còn dài -> im lặng, chưa đáng hành động', () {
      expect(
        _keys(_digest(daysAway: 0, seasonDaysLeft: 20)),
        isNot(contains('digest_season_ending')),
      );
    });

    test('mùa vừa reset (0 ngày) -> im lặng', () {
      expect(
        _keys(_digest(daysAway: 0, seasonDaysLeft: 0)),
        isNot(contains('digest_season_ending')),
      );
    });
  });

  group('tiến độ campaign', () {
    test('còn màn để chơi -> nhắc màn kế', () {
      final d = _digest(daysAway: 0, unlockedLevel: 88);
      final line = d.firstWhere((l) => l.key == 'digest_next_level');
      expect(line.params['n'], '88');
    });

    test('đã phá đảo -> im lặng', () {
      expect(
        _keys(_digest(daysAway: 0, unlockedLevel: 261, levelCount: 260)),
        isNot(contains('digest_next_level')),
      );
    });

    test('luôn xếp cuối, nhường chỗ cho thứ sắp hết hạn', () {
      final d = _keys(_digest(daysAway: 3, seasonDaysLeft: 2));
      expect(d.last, 'digest_next_level');
    });
  });
}

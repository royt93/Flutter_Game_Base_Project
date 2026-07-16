import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/achievements.dart';

void main() {
  group('kAchievements', () {
    test('25 thành tựu, mỗi id duy nhất', () {
      expect(kAchievements.length, 25);
      expect(kAchievements.map((a) => a.id).toSet().length, 25);
    });

    test('5 mốc tăng dần cho mỗi metric', () {
      for (final metric in AchievementMetric.values) {
        final thresholds = kAchievements
            .where((a) => a.metric == metric)
            .map((a) => a.threshold)
            .toList();
        expect(thresholds.length, 5);
        expect(thresholds, List.of(thresholds)..sort());
      }
    });
  });

  group('newlyUnlockedAchievementIds', () {
    test('chưa đạt mốc nào -> rỗng', () {
      expect(
        newlyUnlockedAchievementIds({
          AchievementMetric.totalGemsPopped: 10,
        }, {}),
        isEmpty,
      );
    });

    test('đạt đúng 1 mốc -> trả về đúng id đó', () {
      final result = newlyUnlockedAchievementIds({
        AchievementMetric.totalGemsPopped: 500,
      }, {});
      expect(result, ['gems_500']);
    });

    test('vượt nhiều mốc cùng lúc -> trả về tất cả mốc đã qua', () {
      final result = newlyUnlockedAchievementIds({
        AchievementMetric.maxComboEver: 12,
      }, {});
      expect(result, ['combo_3', 'combo_6', 'combo_10']);
    });

    test('mốc đã unlock trước đó -> không lặp lại', () {
      final result = newlyUnlockedAchievementIds(
        {AchievementMetric.maxComboEver: 12},
        {'combo_3', 'combo_6', 'combo_10'},
      );
      expect(result, isEmpty);
    });

    test('metric không có trong map -> coi như 0', () {
      expect(newlyUnlockedAchievementIds({}, {}), isEmpty);
    });
  });
}

/// I22: hệ thống thành tựu — vanity-only, không ảnh hưởng gameplay/pay-to-win,
/// tách biệt hoàn toàn khỏi Relic/Perk (F14). Xem
/// `docs/superpowers/specs/2026-07-16-achievements-design.md`.
enum AchievementMetric {
  totalGemsPopped,
  maxComboEver,
  levelsThreeStarred,
  boardsFullyCleared,
  totalBoostersUsed,
}

class Achievement {
  const Achievement({
    required this.id,
    required this.metric,
    required this.threshold,
    required this.coinReward,
    required this.titleKey,
    required this.descKey,
  });

  final String id;
  final AchievementMetric metric;
  final int threshold;
  final int coinReward;
  final String titleKey;
  final String descKey;
}

/// Danh sách cố định, mỗi mốc unlock đúng 1 lần — không tier. 5 mốc tăng dần
/// cho mỗi metric (25 thành tựu).
const List<Achievement> kAchievements = [
  Achievement(
    id: 'gems_500',
    metric: AchievementMetric.totalGemsPopped,
    threshold: 500,
    coinReward: 50,
    titleKey: 'ach_gems_500_title',
    descKey: 'ach_gems_500_desc',
  ),
  Achievement(
    id: 'gems_2000',
    metric: AchievementMetric.totalGemsPopped,
    threshold: 2000,
    coinReward: 100,
    titleKey: 'ach_gems_2000_title',
    descKey: 'ach_gems_2000_desc',
  ),
  Achievement(
    id: 'gems_10000',
    metric: AchievementMetric.totalGemsPopped,
    threshold: 10000,
    coinReward: 250,
    titleKey: 'ach_gems_10000_title',
    descKey: 'ach_gems_10000_desc',
  ),
  Achievement(
    id: 'gems_50000',
    metric: AchievementMetric.totalGemsPopped,
    threshold: 50000,
    coinReward: 500,
    titleKey: 'ach_gems_50000_title',
    descKey: 'ach_gems_50000_desc',
  ),
  Achievement(
    id: 'gems_200000',
    metric: AchievementMetric.totalGemsPopped,
    threshold: 200000,
    coinReward: 1000,
    titleKey: 'ach_gems_200000_title',
    descKey: 'ach_gems_200000_desc',
  ),
  Achievement(
    id: 'combo_3',
    metric: AchievementMetric.maxComboEver,
    threshold: 3,
    coinReward: 50,
    titleKey: 'ach_combo_3_title',
    descKey: 'ach_combo_3_desc',
  ),
  Achievement(
    id: 'combo_6',
    metric: AchievementMetric.maxComboEver,
    threshold: 6,
    coinReward: 100,
    titleKey: 'ach_combo_6_title',
    descKey: 'ach_combo_6_desc',
  ),
  Achievement(
    id: 'combo_10',
    metric: AchievementMetric.maxComboEver,
    threshold: 10,
    coinReward: 250,
    titleKey: 'ach_combo_10_title',
    descKey: 'ach_combo_10_desc',
  ),
  Achievement(
    id: 'combo_15',
    metric: AchievementMetric.maxComboEver,
    threshold: 15,
    coinReward: 500,
    titleKey: 'ach_combo_15_title',
    descKey: 'ach_combo_15_desc',
  ),
  Achievement(
    id: 'combo_25',
    metric: AchievementMetric.maxComboEver,
    threshold: 25,
    coinReward: 1000,
    titleKey: 'ach_combo_25_title',
    descKey: 'ach_combo_25_desc',
  ),
  Achievement(
    id: 'stars3_5',
    metric: AchievementMetric.levelsThreeStarred,
    threshold: 5,
    coinReward: 50,
    titleKey: 'ach_stars3_5_title',
    descKey: 'ach_stars3_5_desc',
  ),
  Achievement(
    id: 'stars3_20',
    metric: AchievementMetric.levelsThreeStarred,
    threshold: 20,
    coinReward: 100,
    titleKey: 'ach_stars3_20_title',
    descKey: 'ach_stars3_20_desc',
  ),
  Achievement(
    id: 'stars3_50',
    metric: AchievementMetric.levelsThreeStarred,
    threshold: 50,
    coinReward: 250,
    titleKey: 'ach_stars3_50_title',
    descKey: 'ach_stars3_50_desc',
  ),
  Achievement(
    id: 'stars3_100',
    metric: AchievementMetric.levelsThreeStarred,
    threshold: 100,
    coinReward: 500,
    titleKey: 'ach_stars3_100_title',
    descKey: 'ach_stars3_100_desc',
  ),
  Achievement(
    id: 'stars3_200',
    metric: AchievementMetric.levelsThreeStarred,
    threshold: 200,
    coinReward: 1000,
    titleKey: 'ach_stars3_200_title',
    descKey: 'ach_stars3_200_desc',
  ),
  Achievement(
    id: 'clear_5',
    metric: AchievementMetric.boardsFullyCleared,
    threshold: 5,
    coinReward: 50,
    titleKey: 'ach_clear_5_title',
    descKey: 'ach_clear_5_desc',
  ),
  Achievement(
    id: 'clear_20',
    metric: AchievementMetric.boardsFullyCleared,
    threshold: 20,
    coinReward: 100,
    titleKey: 'ach_clear_20_title',
    descKey: 'ach_clear_20_desc',
  ),
  Achievement(
    id: 'clear_50',
    metric: AchievementMetric.boardsFullyCleared,
    threshold: 50,
    coinReward: 250,
    titleKey: 'ach_clear_50_title',
    descKey: 'ach_clear_50_desc',
  ),
  Achievement(
    id: 'clear_150',
    metric: AchievementMetric.boardsFullyCleared,
    threshold: 150,
    coinReward: 500,
    titleKey: 'ach_clear_150_title',
    descKey: 'ach_clear_150_desc',
  ),
  Achievement(
    id: 'clear_400',
    metric: AchievementMetric.boardsFullyCleared,
    threshold: 400,
    coinReward: 1000,
    titleKey: 'ach_clear_400_title',
    descKey: 'ach_clear_400_desc',
  ),
  Achievement(
    id: 'booster_5',
    metric: AchievementMetric.totalBoostersUsed,
    threshold: 5,
    coinReward: 50,
    titleKey: 'ach_booster_5_title',
    descKey: 'ach_booster_5_desc',
  ),
  Achievement(
    id: 'booster_20',
    metric: AchievementMetric.totalBoostersUsed,
    threshold: 20,
    coinReward: 100,
    titleKey: 'ach_booster_20_title',
    descKey: 'ach_booster_20_desc',
  ),
  Achievement(
    id: 'booster_50',
    metric: AchievementMetric.totalBoostersUsed,
    threshold: 50,
    coinReward: 250,
    titleKey: 'ach_booster_50_title',
    descKey: 'ach_booster_50_desc',
  ),
  Achievement(
    id: 'booster_100',
    metric: AchievementMetric.totalBoostersUsed,
    threshold: 100,
    coinReward: 500,
    titleKey: 'ach_booster_100_title',
    descKey: 'ach_booster_100_desc',
  ),
  Achievement(
    id: 'booster_250',
    metric: AchievementMetric.totalBoostersUsed,
    threshold: 250,
    coinReward: 1000,
    titleKey: 'ach_booster_250_title',
    descKey: 'ach_booster_250_desc',
  ),
];

/// Thuần: id các thành tựu mới đạt mốc dựa trên giá trị counter hiện tại +
/// set id đã unlock trước đó. Tách khỏi [GameController] để test không cần
/// widget harness (`test/data/achievements_test.dart`).
List<String> newlyUnlockedAchievementIds(
  Map<AchievementMetric, int> metricValues,
  Set<String> alreadyUnlocked,
) {
  final result = <String>[];
  for (final a in kAchievements) {
    if (alreadyUnlocked.contains(a.id)) continue;
    if ((metricValues[a.metric] ?? 0) < a.threshold) continue;
    result.add(a.id);
  }
  return result;
}

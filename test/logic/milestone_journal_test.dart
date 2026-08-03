import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/milestone_journal.dart';

MilestoneEntry? _find(List<MilestoneEntry> entries, MilestoneKind kind) {
  for (final e in entries) {
    if (e.kind == kind) return e;
  }
  return null;
}

void main() {
  group('buildMilestoneJournal', () {
    test('mọi giá trị "chưa từng có" (âm/0/rỗng) -> list rỗng', () {
      final entries = buildMilestoneJournal(
        lastLoginEpochDay: 0,
        loginStreakCount: 0,
        lastClaimDay: -1,
        lastDailyChallengeDay: -1,
        lastSpinDay: -1,
        lastGauntletDay: -1,
        raidBossLastAttemptDay: -1,
        lastFeaturedWeekSeen: -1,
        lastPetCollectTimestampMs: 0,
        achievementUnlockDays: const {},
      );
      expect(entries, isEmpty);
    });

    test('sort giảm dần theo epochDay, mới nhất trước', () {
      final entries = buildMilestoneJournal(
        lastLoginEpochDay: 10,
        loginStreakCount: 3,
        lastClaimDay: 5,
        lastDailyChallengeDay: 20,
        lastSpinDay: -1,
        lastGauntletDay: -1,
        raidBossLastAttemptDay: -1,
        lastFeaturedWeekSeen: -1,
        lastPetCollectTimestampMs: 0,
        achievementUnlockDays: const {},
      );
      expect(entries.map((e) => e.epochDay).toList(), [20, 10, 5]);
      expect(entries[0].kind, MilestoneKind.dailyChallenge);
      expect(entries[1].kind, MilestoneKind.loginStreak);
      expect(entries[1].param, '3');
      expect(entries[2].kind, MilestoneKind.dailyClaim);
    });

    test('lastFeaturedWeekSeen quy đổi week-index -> epochDay (x7)', () {
      final entries = buildMilestoneJournal(
        lastLoginEpochDay: 0,
        loginStreakCount: 0,
        lastClaimDay: -1,
        lastDailyChallengeDay: -1,
        lastSpinDay: -1,
        lastGauntletDay: -1,
        raidBossLastAttemptDay: -1,
        lastFeaturedWeekSeen: 100,
        lastPetCollectTimestampMs: 0,
        achievementUnlockDays: const {},
      );
      expect(entries.single.kind, MilestoneKind.weeklyFeatured);
      expect(entries.single.epochDay, 700);
    });

    test('lastPetCollectTimestampMs (ms thật) quy đổi -> epochDay', () {
      final entries = buildMilestoneJournal(
        lastLoginEpochDay: 0,
        loginStreakCount: 0,
        lastClaimDay: -1,
        lastDailyChallengeDay: -1,
        lastSpinDay: -1,
        lastGauntletDay: -1,
        raidBossLastAttemptDay: -1,
        lastFeaturedWeekSeen: -1,
        lastPetCollectTimestampMs: 15 * 86400000 + 1234,
        achievementUnlockDays: const {},
      );
      expect(entries.single.kind, MilestoneKind.petCollected);
      expect(entries.single.epochDay, 15);
    });

    test('nhiều achievement unlock -> mỗi id 1 entry, param là id', () {
      final entries = buildMilestoneJournal(
        lastLoginEpochDay: 0,
        loginStreakCount: 0,
        lastClaimDay: -1,
        lastDailyChallengeDay: -1,
        lastSpinDay: -1,
        lastGauntletDay: -1,
        raidBossLastAttemptDay: -1,
        lastFeaturedWeekSeen: -1,
        lastPetCollectTimestampMs: 0,
        achievementUnlockDays: const {'gems_500': 30, 'combo_10': 40},
      );
      expect(entries.map((e) => e.epochDay).toList(), [40, 30]);
      final combo = _find(entries, MilestoneKind.achievementUnlocked);
      expect(combo, isNotNull);
      expect(entries.map((e) => e.param).toSet(), {'gems_500', 'combo_10'});
    });
  });
}

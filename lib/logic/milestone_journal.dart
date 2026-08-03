/// I72 Milestone Journal — gom lại các mốc đã có timestamp thật rải rác
/// khắp `GameController` thành 1 feed duy nhất, sort mới nhất trước. Hàm
/// thuần, không đọc `StorageService`/GetX — nhận raw value làm tham số
/// (đúng pattern `newlyUnlockedAchievementIds` ở `achievements.dart`), để
/// UI layer tự map [MilestoneKind] sang icon/title đã dịch.
enum MilestoneKind {
  loginStreak,
  dailyClaim,
  dailyChallenge,
  spinWheel,
  gauntlet,
  raidBoss,
  weeklyFeatured,
  petCollected,
  achievementUnlocked,
}

class MilestoneEntry {
  const MilestoneEntry({
    required this.kind,
    required this.epochDay,
    this.param,
  });

  final MilestoneKind kind;
  final int epochDay;

  /// Dữ liệu phụ theo [kind]: `achievementUnlocked` -> id thành tựu (UI tra
  /// `titleKey` qua `kAchievements`); `loginStreak` -> số ngày streak hiện
  /// tại. Các kind còn lại không cần, để `null`.
  final String? param;
}

/// [lastFeaturedWeekSeen] lưu dạng week-index (`epochDay ~/ 7`, xem
/// `weekIndexForEpochDay` ở `weekly_goal.dart`) chứ không phải epochDay —
/// nhân lại 7 để đưa về cùng thang đo với các mốc còn lại khi sort. Chỉ cần
/// đúng thứ tự tương đối, không cần đúng ngày cụ thể trong tuần.
/// [lastPetCollectTimestampMs] là mốc mili-giây thật (I65) -> chia
/// 86400000 để quy về epochDay.
List<MilestoneEntry> buildMilestoneJournal({
  required int lastLoginEpochDay,
  required int loginStreakCount,
  required int lastClaimDay,
  required int lastDailyChallengeDay,
  required int lastSpinDay,
  required int lastGauntletDay,
  required int raidBossLastAttemptDay,
  required int lastFeaturedWeekSeen,
  required int lastPetCollectTimestampMs,
  required Map<String, int> achievementUnlockDays,
}) {
  final entries = <MilestoneEntry>[];

  if (loginStreakCount > 0) {
    entries.add(
      MilestoneEntry(
        kind: MilestoneKind.loginStreak,
        epochDay: lastLoginEpochDay,
        param: '$loginStreakCount',
      ),
    );
  }
  if (lastClaimDay >= 0) {
    entries.add(
      MilestoneEntry(kind: MilestoneKind.dailyClaim, epochDay: lastClaimDay),
    );
  }
  if (lastDailyChallengeDay >= 0) {
    entries.add(
      MilestoneEntry(
        kind: MilestoneKind.dailyChallenge,
        epochDay: lastDailyChallengeDay,
      ),
    );
  }
  if (lastSpinDay >= 0) {
    entries.add(
      MilestoneEntry(kind: MilestoneKind.spinWheel, epochDay: lastSpinDay),
    );
  }
  if (lastGauntletDay >= 0) {
    entries.add(
      MilestoneEntry(kind: MilestoneKind.gauntlet, epochDay: lastGauntletDay),
    );
  }
  if (raidBossLastAttemptDay >= 0) {
    entries.add(
      MilestoneEntry(
        kind: MilestoneKind.raidBoss,
        epochDay: raidBossLastAttemptDay,
      ),
    );
  }
  if (lastFeaturedWeekSeen >= 0) {
    entries.add(
      MilestoneEntry(
        kind: MilestoneKind.weeklyFeatured,
        epochDay: lastFeaturedWeekSeen * 7,
      ),
    );
  }
  if (lastPetCollectTimestampMs > 0) {
    entries.add(
      MilestoneEntry(
        kind: MilestoneKind.petCollected,
        epochDay: lastPetCollectTimestampMs ~/ 86400000,
      ),
    );
  }
  for (final e in achievementUnlockDays.entries) {
    entries.add(
      MilestoneEntry(
        kind: MilestoneKind.achievementUnlocked,
        epochDay: e.value,
        param: e.key,
      ),
    );
  }

  entries.sort((a, b) => b.epochDay.compareTo(a.epochDay));
  return entries;
}

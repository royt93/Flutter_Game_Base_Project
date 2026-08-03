import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/storage_service.dart';
import '../../data/achievements.dart';
import '../../logic/milestone_journal.dart';
import '../controllers/game_controller.dart';
import 'neon_dialog.dart';

/// I72 Milestone Journal — xem lại các mốc đã đạt (login streak, achievement,
/// daily challenge...) theo thời gian, mới nhất trước. Chỉ đọc dữ liệu đã có
/// sẵn timestamp thật, không tạo subsystem lưu trữ mới ngoài
/// [StorageKeys.achievementUnlockDays] (ghi trong `_checkAchievements()`).
Future<void> showMilestoneJournalDialog(
  BuildContext context,
  GameController gameCtrl,
) {
  final entries = buildMilestoneJournal(
    lastLoginEpochDay: gameCtrl.lastLoginEpochDay.value,
    loginStreakCount: gameCtrl.loginStreakCount.value,
    lastClaimDay: StorageService.to.getInt(StorageKeys.lastClaimDay, def: -1),
    lastDailyChallengeDay: StorageService.to.getInt(
      StorageKeys.lastDailyChallengeDay,
      def: -1,
    ),
    lastSpinDay: StorageService.to.getInt(StorageKeys.lastSpinDay, def: -1),
    lastGauntletDay: StorageService.to.getInt(
      StorageKeys.lastGauntletDay,
      def: -1,
    ),
    raidBossLastAttemptDay: StorageService.to.getInt(
      StorageKeys.raidBossLastAttemptDay,
      def: -1,
    ),
    lastFeaturedWeekSeen: StorageService.to.getInt(
      StorageKeys.lastFeaturedWeekSeen,
      def: -1,
    ),
    lastPetCollectTimestampMs: gameCtrl.lastPetCollectMs.value,
    achievementUnlockDays: gameCtrl.achievementUnlockDays,
  );
  final todayEpochDay =
      DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;

  return NeonDialog.show(
    context: context,
    title: 'milestone_journal_title'.tr,
    color: NeonTheme.purple,
    icon: Icons.auto_stories_rounded,
    dismissible: true,
    content: entries.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: NeonTheme.s16),
            child: Text(
              'milestone_journal_empty'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: NeonTheme.inkSoft),
            ),
          )
        : SizedBox(
            width: double.maxFinite,
            height: 320,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: NeonTheme.s8),
              itemBuilder: (_, i) => _MilestoneRow(
                entry: entries[i],
                todayEpochDay: todayEpochDay,
              ),
            ),
          ),
    actions: const [],
  );
}

IconData _iconFor(MilestoneKind kind) {
  switch (kind) {
    case MilestoneKind.loginStreak:
      return Icons.event_available_rounded;
    case MilestoneKind.dailyClaim:
      return Icons.card_giftcard_rounded;
    case MilestoneKind.dailyChallenge:
      return Icons.emoji_events_rounded;
    case MilestoneKind.spinWheel:
      return Icons.casino_rounded;
    case MilestoneKind.gauntlet:
      return Icons.whatshot_rounded;
    case MilestoneKind.raidBoss:
      return Icons.shield_rounded;
    case MilestoneKind.weeklyFeatured:
      return Icons.star_rounded;
    case MilestoneKind.petCollected:
      return Icons.pets_rounded;
    case MilestoneKind.achievementUnlocked:
      return Icons.military_tech_rounded;
  }
}

String _titleFor(MilestoneEntry entry) {
  switch (entry.kind) {
    case MilestoneKind.loginStreak:
      return 'milestone_login_streak'.trParams({'count': entry.param ?? '0'});
    case MilestoneKind.dailyClaim:
      return 'milestone_daily_claim'.tr;
    case MilestoneKind.dailyChallenge:
      return 'milestone_daily_challenge'.tr;
    case MilestoneKind.spinWheel:
      return 'milestone_spin_wheel'.tr;
    case MilestoneKind.gauntlet:
      return 'milestone_gauntlet'.tr;
    case MilestoneKind.raidBoss:
      return 'milestone_raid_boss'.tr;
    case MilestoneKind.weeklyFeatured:
      return 'milestone_weekly_featured'.tr;
    case MilestoneKind.petCollected:
      return 'milestone_pet_collected'.tr;
    case MilestoneKind.achievementUnlocked:
      final id = entry.param;
      final match = kAchievements.where((a) => a.id == id);
      return match.isEmpty
          ? 'milestone_achievement_unlocked'.tr
          : match.first.titleKey.tr;
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.entry, required this.todayEpochDay});

  final MilestoneEntry entry;
  final int todayEpochDay;

  @override
  Widget build(BuildContext context) {
    final daysAgo = todayEpochDay - entry.epochDay;
    final whenLabel = daysAgo <= 0
        ? 'milestone_today'.tr
        : 'milestone_days_ago'.trParams({'days': '$daysAgo'});
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NeonTheme.s16,
        vertical: NeonTheme.s8,
      ),
      decoration: BoxDecoration(
        color: NeonTheme.cardAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(_iconFor(entry.kind), color: NeonTheme.purple, size: 22),
          const SizedBox(width: NeonTheme.s8),
          Expanded(
            child: Text(
              _titleFor(entry),
              style: TextStyle(
                color: NeonTheme.ink,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            whenLabel,
            style: TextStyle(color: NeonTheme.inkSoft, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

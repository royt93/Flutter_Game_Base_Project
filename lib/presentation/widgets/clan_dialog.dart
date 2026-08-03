import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../data/clan.dart';
import '../../logic/leaderboard.dart';
import '../controllers/game_controller.dart';
import 'neon_dialog.dart';

/// I66 Clan Lite — pool đóng góp tuần (NPC tĩnh + người chơi, seeded theo
/// [GameController.currentWeekIndex]) và bảng xếp hạng đóng góp tuần
/// ([clan_league]), tái dùng offline-leaderboard pattern của I9.
Future<void> showClanDialog(BuildContext context, GameController gameCtrl) {
  return NeonDialog.show(
    context: context,
    title: 'clan_title'.tr,
    color: NeonTheme.purple,
    icon: Icons.groups_rounded,
    dismissible: true,
    content: Obx(() {
      final week = gameCtrl.currentWeekIndex;
      final contribWeek = gameCtrl.clanContribWeek.value;
      final pool = clanPoolTotal(week, contribWeek);
      final claimed = gameCtrl.clanGoalClaimed;
      final canClaim = pool >= clanGoalTarget && !claimed;
      final entries = buildLeaderboard([
        for (var i = 0; i < kClanMemberNames.length; i++)
          LeaderboardEntry(
            kClanMemberNames[i],
            clanBotContributionForWeek(week, i),
          ),
      ], contribWeek);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'clan_goal'.tr,
            style: TextStyle(
              color: NeonTheme.ink,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'clan_goal_hint'.tr,
            style: TextStyle(color: NeonTheme.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: NeonTheme.s16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (pool / clanGoalTarget).clamp(0, 1).toDouble(),
              minHeight: 10,
              backgroundColor: NeonTheme.cardAlt,
              valueColor: AlwaysStoppedAnimation(NeonTheme.purple),
            ),
          ),
          const SizedBox(height: NeonTheme.s8),
          Text(
            '${pool.clamp(0, clanGoalTarget)}/$clanGoalTarget',
            style: TextStyle(color: NeonTheme.ink, fontWeight: FontWeight.w800),
          ),
          if (claimed) ...[
            const SizedBox(height: NeonTheme.s8),
            Text(
              'weekly_goal_claimed_label'.tr,
              style: TextStyle(
                color: NeonTheme.purple,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: NeonTheme.s24),
          NeonDialogButton(
            action: NeonDialogAction(
              label: canClaim ? 'ach_claim'.tr : 'coll_close'.tr,
              color: NeonTheme.purple,
              onTap: canClaim
                  ? () => gameCtrl.claimClanGoalReward()
                  : () => Navigator.of(context, rootNavigator: true).pop(),
            ),
          ),
          const SizedBox(height: NeonTheme.s24),
          Text(
            'clan_league'.tr,
            style: TextStyle(
              color: NeonTheme.ink,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: NeonTheme.s8),
          ...entries.asMap().entries.map((e) {
            final rank = e.key + 1;
            final entry = e.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: NeonTheme.inkSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.isPlayer ? 'leaderboard_you'.tr : entry.name,
                      style: TextStyle(
                        color: NeonTheme.ink,
                        fontWeight: entry.isPlayer
                            ? FontWeight.w800
                            : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '${entry.stars}',
                    style: TextStyle(
                      color: NeonTheme.inkSoft,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    }),
    actions: const [],
  );
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../controllers/game_controller.dart';
import 'neon_dialog.dart';

Future<void> showDailyQuestDialog(
  BuildContext context,
  GameController controller,
) {
  controller.checkDailyQuestRollover();
  return NeonDialog.show(
    context: context,
    title: 'daily_quest_title'.tr,
    color: NeonTheme.purple,
    icon: Icons.task_alt_rounded,
    dismissible: true,
    content: Obx(
      () => Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(controller.dailyQuests.length, (index) {
          final quest = controller.dailyQuests[index];
          final progress = controller.dailyQuestProgress[index];
          final claimed = controller.dailyQuestClaimed.contains(index);
          return Padding(
            padding: const EdgeInsets.only(bottom: NeonTheme.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        quest.nameKey.tr,
                        style: TextStyle(
                          color: NeonTheme.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '+${quest.coinReward}',
                      style: const TextStyle(
                        color: NeonTheme.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: NeonTheme.s8),
                LinearProgressIndicator(
                  value: (progress / quest.target).clamp(0, 1),
                  backgroundColor: NeonTheme.cardAlt,
                  color: NeonTheme.purple,
                ),
                const SizedBox(height: NeonTheme.s8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${progress.clamp(0, quest.target)}/${quest.target}',
                        style: TextStyle(color: NeonTheme.inkSoft),
                      ),
                    ),
                    if (claimed)
                      Text(
                        'daily_quest_claimed'.tr,
                        style: const TextStyle(
                          color: NeonTheme.teal,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else
                      FilledButton(
                        onPressed: progress >= quest.target
                            ? () => controller.claimDailyQuest(index)
                            : null,
                        child: Text('daily_quest_claim'.tr),
                      ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    ),
    actions: [
      NeonDialogAction(
        label: 'coll_close'.tr,
        color: NeonTheme.purple,
        onTap: () {},
      ),
    ],
  );
}

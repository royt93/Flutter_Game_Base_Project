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
        children: [
          // F17: nút tiêu Combo Token đặt NGAY tại chỗ hệ này đang hiển thị —
          // không dựng màn hình riêng cho từng đường tiêu.
          _RerollRow(controller: controller),
          const SizedBox(height: NeonTheme.s16),
          ...List.generate(controller.dailyQuests.length, (index) {
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
        ],
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

/// F17: dòng "đổi nhiệm vụ" + số dư Combo Token.
class _RerollRow extends StatelessWidget {
  const _RerollRow({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final can = controller.canRerollDailyQuests;
    return Row(
      children: [
        const Icon(Icons.bolt_rounded, color: NeonTheme.cyan, size: 18),
        const SizedBox(width: 4),
        Text(
          '${controller.comboTokens.value}',
          style: const TextStyle(
            color: NeonTheme.cyan,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        FilledButton(
          key: const Key('token_reroll_quests'),
          onPressed: can ? controller.rerollDailyQuests : null,
          child: Text(
            'token_reroll_quest'.trParams({
              'n': '${GameController.tokenCostRerollQuest}',
            }),
          ),
        ),
      ],
    );
  }
}

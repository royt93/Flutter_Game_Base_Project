import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../logic/next_action.dart';
import 'pressable_scale.dart';

/// I84: dải "Tiếp theo" trên Home — tối đa 3 việc đáng làm nhất lúc này.
///
/// Cố ý đặt **trên** carousel chứ không thay thế nó: carousel đầy đủ vẫn ở
/// dưới cho ai muốn khám phá, còn dải này trả lời câu "giờ làm gì?" mà trước
/// đây người chơi phải tự lọc từ 14 mode + ~20 hệ meta.
///
/// Widget thuần hiển thị: nhận danh sách đã xếp hạng sẵn từ
/// `GameController.nextActions()` và [onTap] do Home truyền vào. Không tự đọc
/// state, không tự điều hướng — để logic ưu tiên và điều hướng nằm đúng chỗ
/// của chúng.
class NextUpBar extends StatelessWidget {
  const NextUpBar({super.key, required this.actions, required this.onTap});

  final List<NextAction> actions;
  final void Function(NextAction action) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NeonTheme.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'home_next_title'.tr,
            style: TextStyle(
              color: NeonTheme.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          if (actions.isEmpty)
            // Không để trống và cũng không hiện thẻ giả — một dòng ngắn là đủ.
            Text(
              'home_next_empty'.tr,
              key: const Key('next_up_empty'),
              style: TextStyle(color: NeonTheme.inkSoft, fontSize: 13),
            )
          else
            Wrap(
              spacing: NeonTheme.s8,
              runSpacing: NeonTheme.s8,
              children: [
                for (final a in actions)
                  _NextChip(action: a, onTap: () => onTap(a)),
              ],
            ),
        ],
      ),
    );
  }
}

class _NextChip extends StatelessWidget {
  const _NextChip({required this.action, required this.onTap});

  final NextAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spec = _specFor(action.kind);
    return PressableScale(
      onTap: onTap,
      child: Container(
        key: Key('next_up_${action.kind.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: NeonTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: spec.color, width: 2),
          boxShadow: NeonTheme.drop(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(spec.icon, color: spec.color, size: 16),
            const SizedBox(width: 6),
            Text(
              _label(action),
              style: TextStyle(
                color: NeonTheme.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _label(NextAction a) => switch (a.kind) {
  NextActionKind.dailyReward => 'home_next_daily'.tr,
  NextActionKind.dailySpin => 'home_next_spin'.tr,
  NextActionKind.dailyQuest => 'home_next_quest'.trParams({
    'n': '${a.value ?? 0}',
  }),
  // Tái dùng nhãn đã có đủ 22 ngôn ngữ thay vì thêm key mới cho cùng một thứ.
  NextActionKind.raidBoss => 'raid_boss_title'.tr,
  NextActionKind.starRoadChest => 'home_next_chest'.tr,
  NextActionKind.seasonMilestone => 'home_next_season'.tr,
  NextActionKind.weeklyGoal => 'home_next_weekly'.tr,
  NextActionKind.clanGoal => 'home_next_clan'.tr,
  NextActionKind.campaignLevel => 'home_next_level'.trParams({
    'n': '${a.value ?? 1}',
  }),
};

({IconData icon, Color color}) _specFor(NextActionKind kind) => switch (kind) {
  NextActionKind.dailyReward => (
    icon: Icons.card_giftcard_rounded,
    color: NeonTheme.gold,
  ),
  NextActionKind.dailySpin => (
    icon: Icons.casino_rounded,
    color: NeonTheme.pink,
  ),
  NextActionKind.dailyQuest => (
    icon: Icons.checklist_rounded,
    color: NeonTheme.teal,
  ),
  NextActionKind.raidBoss => (
    icon: Icons.local_fire_department_rounded,
    color: NeonTheme.red,
  ),
  NextActionKind.starRoadChest => (
    icon: Icons.inventory_2_rounded,
    color: NeonTheme.gold,
  ),
  NextActionKind.seasonMilestone => (
    icon: Icons.emoji_events_rounded,
    color: NeonTheme.orange,
  ),
  NextActionKind.weeklyGoal => (
    icon: Icons.flag_rounded,
    color: NeonTheme.cyan,
  ),
  NextActionKind.clanGoal => (
    icon: Icons.groups_rounded,
    color: NeonTheme.indigo,
  ),
  NextActionKind.campaignLevel => (
    icon: Icons.play_arrow_rounded,
    color: NeonTheme.teal,
  ),
};

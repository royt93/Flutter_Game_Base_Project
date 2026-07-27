import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../controllers/game_controller.dart';
import 'neon_dialog.dart';

/// I48 Login Streak Calendar — hiện 7 ô ngày trong cycle hiện tại, ô 3/5/7 có
/// thưởng coin. Nút "Nhận" chỉ enable đúng ngày hiện tại khi có thưởng &
/// chưa nhận.
Future<void> showLoginStreakDialog(
  BuildContext context,
  GameController gameCtrl,
) {
  return NeonDialog.show(
    context: context,
    title: 'login_streak_title'.tr,
    color: NeonTheme.red,
    icon: Icons.event_available_rounded,
    dismissible: true,
    content: Obx(() {
      final today = gameCtrl.dayInCycle(gameCtrl.loginStreakCount.value);
      final reward = GameController.loginStreakRewards[today];
      final claimed = (gameCtrl.loginStreakClaimedMask.value >> today) & 1 == 1;
      final canClaim = reward != null && !claimed;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: NeonTheme.s8,
            runSpacing: NeonTheme.s8,
            alignment: WrapAlignment.center,
            children: [
              for (var day = 1; day <= 7; day++)
                _DayCell(
                  day: day,
                  isToday: day == today,
                  isPast: day < today,
                  isClaimed:
                      (gameCtrl.loginStreakClaimedMask.value >> day) & 1 == 1,
                  reward: GameController.loginStreakRewards[day],
                ),
            ],
          ),
          const SizedBox(height: NeonTheme.s24),
          NeonDialogButton(
            action: NeonDialogAction(
              label: canClaim
                  ? 'login_streak_claim_button'.tr
                  : 'coll_close'.tr,
              color: NeonTheme.red,
              onTap: canClaim
                  ? () => gameCtrl.claimLoginStreakReward()
                  : () => Navigator.of(context, rootNavigator: true).pop(),
            ),
          ),
        ],
      );
    }),
    actions: const [],
  );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isPast,
    required this.isClaimed,
    required this.reward,
  });

  final int day;
  final bool isToday;
  final bool isPast;
  final bool isClaimed;
  final int? reward;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(
        horizontal: NeonTheme.s8,
        vertical: NeonTheme.s8,
      ),
      decoration: BoxDecoration(
        color: isToday ? NeonTheme.red.withValues(alpha: 0.18) : null,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday ? NeonTheme.red : NeonTheme.cardAlt,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${'login_streak_day_label'.tr} $day',
            style: TextStyle(
              color: NeonTheme.ink,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: NeonTheme.s8),
          if (isClaimed)
            Icon(Icons.check_circle_rounded, color: NeonTheme.red, size: 22)
          else if (reward != null)
            Text(
              '+$reward',
              style: TextStyle(
                color: isPast ? NeonTheme.inkSoft : NeonTheme.ink,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Icon(Icons.remove_rounded, color: NeonTheme.inkSoft, size: 18),
        ],
      ),
    );
  }
}

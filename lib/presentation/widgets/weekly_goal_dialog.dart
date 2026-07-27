import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../data/weekly_goal.dart';
import '../controllers/game_controller.dart';
import 'neon_dialog.dart';

/// I50 Weekly Goal Card — thanh tiến độ pop gem cộng dồn trong tuần (mọi
/// mode), nút "Nhận" chỉ enable khi đạt [weeklyGoalTarget] và chưa nhận
/// trong tuần hiện tại.
Future<void> showWeeklyGoalDialog(
  BuildContext context,
  GameController gameCtrl,
) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (dialogCtx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Obx(() {
        final progress = gameCtrl.weeklyGoalProgress.value;
        final claimed = gameCtrl.weeklyGoalClaimed;
        final canClaim = progress >= weeklyGoalTarget && !claimed;
        return NeonDialog.panel(
          title: 'weekly_goal_title'.tr,
          color: NeonTheme.teal,
          icon: Icons.flag_rounded,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'weekly_goal_desc'.tr,
                style: TextStyle(color: NeonTheme.inkSoft, fontSize: 13),
              ),
              const SizedBox(height: NeonTheme.s16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (progress / weeklyGoalTarget).clamp(0, 1).toDouble(),
                  minHeight: 10,
                  backgroundColor: NeonTheme.cardAlt,
                  valueColor: AlwaysStoppedAnimation(NeonTheme.teal),
                ),
              ),
              const SizedBox(height: NeonTheme.s8),
              Text(
                '${progress.clamp(0, weeklyGoalTarget)}/$weeklyGoalTarget',
                style: TextStyle(
                  color: NeonTheme.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (claimed) ...[
                const SizedBox(height: NeonTheme.s8),
                Text(
                  'weekly_goal_claimed_label'.tr,
                  style: TextStyle(
                    color: NeonTheme.teal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            NeonDialogAction(
              label: canClaim ? 'weekly_goal_claim_button'.tr : 'coll_close'.tr,
              color: NeonTheme.teal,
              onTap: canClaim
                  ? () => gameCtrl.claimWeeklyGoalReward()
                  : () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
            ),
          ],
        );
      }),
    ),
  );
}

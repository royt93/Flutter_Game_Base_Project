import 'package:flutter/material.dart';

import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../controllers/game_controller.dart';
import 'coin_chip.dart';
import 'neon_dialog.dart';

IconData _spinRewardIcon(String type) => switch (type) {
  'bomb' => Icons.dangerous_rounded,
  'shuffle' => Icons.shuffle_rounded,
  'undo' => Icons.undo_rounded,
  _ => Icons.monetization_on_rounded,
};

String _spinRewardLabel(SpinReward r) =>
    r.type == 'coins' ? '${fmtNum(r.amount)} xu' : '${r.type} x${r.amount}';

/// I7: vòng quay hằng ngày. Kết quả đã chốt trước ([GameController.todaySpinReward],
/// seed = ngày) — reel chỉ animate rồi dừng đúng ô đó, không tự random riêng.
void showSpinWheelDialog(BuildContext context, GameController gameCtrl) {
  if (!gameCtrl.canClaimSpin) {
    NeonDialog.show(
      context: context,
      title: 'Vòng quay',
      color: NeonTheme.purple,
      icon: Icons.casino_rounded,
      message: 'Hôm nay quay rồi, quay lại vào ngày mai nhé!',
      actions: [
        NeonDialogAction(label: 'Đóng', color: NeonTheme.purple, onTap: () {}),
      ],
    );
    return;
  }

  final target = gameCtrl.todaySpinReward;
  var done = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setState) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: NeonDialog.panel(
            title: 'Vòng quay may mắn',
            color: NeonTheme.purple,
            content: _SpinReel(
              target: target,
              onDone: () => setState(() => done = true),
            ),
            message: done ? 'Nhận được ${_spinRewardLabel(target)}!' : null,
            actions: [
              NeonDialogAction(
                label: done ? 'Nhận' : 'Đang quay...',
                color: NeonTheme.purple,
                onTap: () {
                  if (!done) return;
                  gameCtrl.claimSpin();
                  Navigator.of(dialogCtx, rootNavigator: true).pop();
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _SpinReel extends StatelessWidget {
  const _SpinReel({required this.target, required this.onDone});

  final SpinReward target;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final rewards = GameController.spinRewards;
    final targetIndex = rewards.indexWhere(
      (r) => r.type == target.type && r.amount == target.amount,
    );
    final totalTicks = rewards.length * 3 + targetIndex;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: totalTicks.toDouble()),
      duration: const Duration(milliseconds: 1800),
      curve: Curves.easeOutCubic,
      onEnd: onDone,
      builder: (context, value, _) {
        final reward = rewards[value.floor() % rewards.length];
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: NeonTheme.s24,
            vertical: NeonTheme.s16,
          ),
          decoration: BoxDecoration(
            color: NeonTheme.cardAlt,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              reward.type == 'coins'
                  ? const CoinIcon(size: 28)
                  : Icon(
                      _spinRewardIcon(reward.type),
                      color: NeonTheme.purple,
                      size: 28,
                    ),
              const SizedBox(width: NeonTheme.s8),
              Text(
                _spinRewardLabel(reward),
                style: TextStyle(
                  color: NeonTheme.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

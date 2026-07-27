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

  NeonDialog.show(
    context: context,
    title: 'Vòng quay may mắn',
    color: NeonTheme.purple,
    content: _SpinWheelBody(
      target: target,
      onClaim: () {
        gameCtrl.claimSpin();
        Navigator.of(context, rootNavigator: true).pop();
      },
    ),
    actions: const [],
  );
}

class _SpinWheelBody extends StatefulWidget {
  const _SpinWheelBody({required this.target, required this.onClaim});

  final SpinReward target;
  final VoidCallback onClaim;

  @override
  State<_SpinWheelBody> createState() => _SpinWheelBodyState();
}

class _SpinWheelBodyState extends State<_SpinWheelBody> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SpinReel(
          target: widget.target,
          onDone: () => setState(() => _done = true),
        ),
        if (_done) ...[
          const SizedBox(height: NeonTheme.s16),
          Text(
            'Nhận được ${_spinRewardLabel(widget.target)}!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NeonTheme.inkSoft,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: NeonTheme.s24),
        NeonDialogButton(
          action: NeonDialogAction(
            label: _done ? 'Nhận' : 'Đang quay...',
            color: NeonTheme.purple,
            onTap: () {
              if (!_done) return;
              widget.onClaim();
            },
          ),
        ),
      ],
    );
  }
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

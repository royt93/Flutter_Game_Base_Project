import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../data/burst_styles.dart';
import '../controllers/game_controller.dart';
import 'neon_dialog.dart';

/// I52 Pop Burst Style Picker — chọn kiểu hiệu ứng nổ. Style chưa mở khoá
/// (theo `gameCtrl.totalGemsPopped`) hiện mờ + ngưỡng cần đạt, không tap được.
Future<void> showBurstStylePickerDialog(
  BuildContext context,
  GameController gameCtrl,
) {
  return NeonDialog.show(
    context: context,
    title: 'drawer_burst_style_label'.tr,
    color: NeonTheme.indigo,
    icon: Icons.auto_awesome_motion_rounded,
    content: Column(
      children: [
        for (final style in kBurstStyles)
          _BurstStyleRow(
            style: style,
            gameCtrl: gameCtrl,
            onSelected: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
      ],
    ),
    actions: [
      NeonDialogAction(
        label: 'coll_close'.tr,
        color: NeonTheme.indigo,
        onTap: () {},
      ),
    ],
  );
}

class _BurstStyleRow extends StatelessWidget {
  const _BurstStyleRow({
    required this.style,
    required this.gameCtrl,
    required this.onSelected,
  });

  final BurstStyle style;
  final GameController gameCtrl;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final unlocked = isBurstStyleUnlocked(
      style,
      gameCtrl.totalGemsPopped.value,
    );
    final active = gameCtrl.activeBurstStyleKind.value == style.kind;
    return Opacity(
      opacity: unlocked ? 1 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: NeonTheme.s8),
        child: GestureDetector(
          onTap: unlocked
              ? () {
                  gameCtrl.setActiveBurstStyle(style.kind);
                  onSelected();
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: NeonTheme.s16,
              vertical: NeonTheme.s8,
            ),
            decoration: BoxDecoration(
              color: active ? NeonTheme.indigo.withValues(alpha: 0.18) : null,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? NeonTheme.indigo : NeonTheme.cardAlt,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  unlocked
                      ? Icons.auto_awesome_motion_rounded
                      : Icons.lock_rounded,
                  color: NeonTheme.ink,
                  size: 22,
                ),
                const SizedBox(width: NeonTheme.s8),
                Expanded(
                  child: Text(
                    style.nameKey.tr,
                    style: TextStyle(
                      color: NeonTheme.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!unlocked)
                  Text(
                    '${style.unlockThreshold}',
                    style: TextStyle(
                      color: NeonTheme.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else if (active)
                  Icon(Icons.check_circle_rounded, color: NeonTheme.indigo),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

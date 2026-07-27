import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../data/combo_text_styles.dart';
import '../controllers/game_controller.dart';
import 'neon_dialog.dart';

/// I54 Combo Text Style Picker — chọn kiểu chữ combo-milestone. Style chưa mở
/// khoá (theo `gameCtrl.maxComboEver`) hiện mờ + ngưỡng cần đạt, không tap được.
Future<void> showComboTextStylePickerDialog(
  BuildContext context,
  GameController gameCtrl,
) {
  return NeonDialog.show(
    context: context,
    title: 'drawer_combo_text_style_label'.tr,
    color: NeonTheme.yellow,
    icon: Icons.text_fields_rounded,
    content: Column(
      children: [
        for (final style in kComboTextStyles)
          _ComboTextStyleRow(
            style: style,
            gameCtrl: gameCtrl,
            onSelected: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
      ],
    ),
    actions: [
      NeonDialogAction(
        label: 'coll_close'.tr,
        color: NeonTheme.yellow,
        onTap: () {},
      ),
    ],
  );
}

class _ComboTextStyleRow extends StatelessWidget {
  const _ComboTextStyleRow({
    required this.style,
    required this.gameCtrl,
    required this.onSelected,
  });

  final ComboTextStyle style;
  final GameController gameCtrl;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final unlocked = isComboTextStyleUnlocked(
      style,
      gameCtrl.maxComboEver.value,
    );
    final active = gameCtrl.activeComboTextStyleKind.value == style.kind;
    return Opacity(
      opacity: unlocked ? 1 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: NeonTheme.s8),
        child: GestureDetector(
          onTap: unlocked
              ? () {
                  gameCtrl.setActiveComboTextStyle(style.kind);
                  onSelected();
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: NeonTheme.s16,
              vertical: NeonTheme.s8,
            ),
            decoration: BoxDecoration(
              color: active ? NeonTheme.yellow.withValues(alpha: 0.18) : null,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? NeonTheme.yellow : NeonTheme.cardAlt,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  unlocked ? Icons.text_fields_rounded : Icons.lock_rounded,
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
                  Icon(Icons.check_circle_rounded, color: NeonTheme.yellow),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

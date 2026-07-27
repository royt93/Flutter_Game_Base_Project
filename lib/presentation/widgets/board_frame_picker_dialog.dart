import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../data/achievements.dart';
import '../../data/board_frames.dart';
import '../controllers/game_controller.dart';
import 'neon_dialog.dart';

/// I51 Board Frame Picker chọn khung viền board. Khung chưa mở khoá (theo
/// `gameCtrl.prestigeTier`/`unlockedAchievementIds`) hiện mờ + điều kiện mở
/// khoá, không tap được.
Future<void> showBoardFramePickerDialog(
  BuildContext context,
  GameController gameCtrl,
) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setState) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: NeonDialog.panel(
          title: 'drawer_board_frame_label'.tr,
          color: NeonTheme.indigo,
          icon: Icons.crop_free_rounded,
          content: Column(
            children: [
              for (final frame in kBoardFrames)
                _BoardFrameRow(
                  frame: frame,
                  gameCtrl: gameCtrl,
                  onSelected: () =>
                      Navigator.of(dialogCtx, rootNavigator: true).pop(),
                ),
            ],
          ),
          actions: [
            NeonDialogAction(
              label: 'coll_close'.tr,
              color: NeonTheme.indigo,
              onTap: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BoardFrameRow extends StatelessWidget {
  const _BoardFrameRow({
    required this.frame,
    required this.gameCtrl,
    required this.onSelected,
  });

  final BoardFrame frame;
  final GameController gameCtrl;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final unlocked = isBoardFrameUnlocked(
        frame,
        gameCtrl.prestigeTier.value,
        gameCtrl.unlockedAchievementIds,
      );
      final active = gameCtrl.activeBoardFrameId.value == frame.id;
      return Opacity(
        opacity: unlocked ? 1 : 0.45,
        child: GestureDetector(
          onTap: unlocked
              ? () {
                  gameCtrl.setActiveBoardFrame(frame.id);
                  onSelected();
                }
              : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: NeonTheme.s8),
            padding: const EdgeInsets.symmetric(
              horizontal: NeonTheme.s16,
              vertical: NeonTheme.s8,
            ),
            decoration: BoxDecoration(
              color: NeonTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: frame.color, width: active ? 2.5 : 1.5),
              boxShadow: active ? NeonTheme.glow(frame.color) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: frame.color, width: 3),
                  ),
                ),
                const SizedBox(width: NeonTheme.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        frame.nameKey.tr,
                        style: TextStyle(
                          color: NeonTheme.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!unlocked) Text(_unlockText(), style: _lockStyle),
                    ],
                  ),
                ),
                if (active)
                  Icon(Icons.check_circle_rounded, color: frame.color),
              ],
            ),
          ),
        ),
      );
    });
  }

  static TextStyle get _lockStyle => TextStyle(
    color: NeonTheme.inkSoft,
    fontWeight: FontWeight.w600,
    fontSize: 12,
  );

  String _unlockText() {
    switch (frame.unlockKind) {
      case BoardFrameUnlockKind.always:
        return '';
      case BoardFrameUnlockKind.prestigeTier:
        return 'board_frame_unlock_prestige'.trParams({
          'tier': '${frame.requiredPrestigeTier}',
        });
      case BoardFrameUnlockKind.achievement:
        final achievement = kAchievements.firstWhere(
          (a) => a.id == frame.requiredAchievementId,
        );
        return 'wardrobe_unlock_via'.trParams({
          'achievement': achievement.titleKey.tr,
        });
    }
  }
}

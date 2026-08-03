import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../data/achievements.dart';
import '../../data/board_frames.dart';
import '../controllers/game_controller.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';

/// I73: màn hình riêng thay cho dialog "Khung viền" cũ (bị tràn nội dung khi
/// danh sách khung tăng lên 8) — full-screen route giống ModeSelectScreen,
/// không giới hạn chiều cao nội dung.
class BoardFrameScreen extends StatelessWidget {
  const BoardFrameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameCtrl = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'drawer_board_frame_label'.tr,
                color: NeonTheme.indigo,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(NeonTheme.s16),
                  children: [
                    for (final frame in kBoardFrames)
                      _BoardFrameRow(frame: frame, gameCtrl: gameCtrl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardFrameRow extends StatelessWidget {
  const _BoardFrameRow({required this.frame, required this.gameCtrl});

  final BoardFrame frame;
  final GameController gameCtrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final unlocked = isBoardFrameUnlocked(
        frame,
        gameCtrl.prestigeTier.value,
        gameCtrl.unlockedAchievementIds,
        treasureMapCompleted: gameCtrl.treasureMapCompleted.value,
      );
      final active = gameCtrl.activeBoardFrameId.value == frame.id;
      return Opacity(
        opacity: unlocked ? 1 : 0.45,
        child: GestureDetector(
          onTap: unlocked ? () => gameCtrl.setActiveBoardFrame(frame.id) : null,
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
                      if (!unlocked)
                        Text(_unlockText(), style: _lockStyle)
                      else if (frame.unlockKind ==
                          BoardFrameUnlockKind.seasonal)
                        Text(
                          'board_frame_seasonal_badge'.tr,
                          style: _lockStyle.copyWith(color: frame.color),
                        ),
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
      case BoardFrameUnlockKind.treasureMap:
        return 'board_frame_unlock_treasure'.tr;
      case BoardFrameUnlockKind.seasonal:
        return 'board_frame_unlock_seasonal'.trParams({
          'start': '${frame.seasonStartDay}/${frame.seasonStartMonth}',
          'end': '${frame.seasonEndDay}/${frame.seasonEndMonth}',
        });
    }
  }
}

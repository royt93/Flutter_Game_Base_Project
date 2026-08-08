import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../data/achievements.dart';
import '../../data/mascot_skins.dart';
import '../controllers/game_controller.dart';
import 'sticker_album_screen.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/mascot_skin_tile.dart';
import '../widgets/neon_button.dart';
import '../widgets/prestige_action.dart';

/// I34: gộp hiển thị prestige tier (I27), thành tựu đã unlock (I22) và mascot
/// skin đã sở hữu (I30) vào 1 màn "khoe" duy nhất — thuần trình bày, không
/// thêm state/storage mới, chỉ đọc lại các Rx đã có trên [GameController].
class TrophyRoomScreen extends StatelessWidget {
  const TrophyRoomScreen({super.key});

  Widget _sectionHeader(String label) => Padding(
    padding: const EdgeInsets.only(bottom: NeonTheme.s8),
    child: Text(
      label,
      style: TextStyle(
        color: NeonTheme.ink,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final gameCtrl = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'trophy_room_title'.tr, color: NeonTheme.gold),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(NeonTheme.s16),
                  children: [
                    _sectionHeader('trophy_room_prestige_section'.tr),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: PrestigeAction(
                        gameCtrl: gameCtrl,
                        onTap: () => showPrestigeDialog(context, gameCtrl),
                      ),
                    ),
                    const SizedBox(height: NeonTheme.s16),
                    _sectionHeader('trophy_room_achievements_section'.tr),
                    Obx(() {
                      gameCtrl.unlockedAchievementIds.length;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: NeonTheme.s8,
                              crossAxisSpacing: NeonTheme.s8,
                              childAspectRatio: 0.85,
                            ),
                        itemCount: kAchievements.length,
                        itemBuilder: (context, i) {
                          final a = kAchievements[i];
                          final unlocked = gameCtrl.unlockedAchievementIds
                              .contains(a.id);
                          return _AchievementTile(
                            achievement: a,
                            unlocked: unlocked,
                          );
                        },
                      );
                    }),
                    const SizedBox(height: NeonTheme.s16),
                    _sectionHeader('trophy_room_mascots_section'.tr),
                    Obx(() {
                      gameCtrl.unlockedMascotSkinIds.length;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: NeonTheme.s8,
                              crossAxisSpacing: NeonTheme.s8,
                              childAspectRatio: 0.9,
                            ),
                        itemCount: kMascotSkins.length,
                        itemBuilder: (context, i) {
                          final skin = kMascotSkins[i];
                          final unlocked = gameCtrl.unlockedMascotSkinIds
                              .contains(skin.id);
                          return MascotSkinTile(skin: skin, unlocked: unlocked);
                        },
                      );
                    }),
                    const SizedBox(height: NeonTheme.s16),
                    Center(
                      child: NeonButton(
                        label: 'sticker_album_title'.tr,
                        color: NeonTheme.magenta,
                        icon: Icons.auto_awesome_rounded,
                        onTap: () => Get.to(() => const StickerAlbumScreen()),
                      ),
                    ),
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

/// Thẻ thành tựu trong Trophy Room — khác `_AchievementRow` ở
/// `AchievementsScreen`: khi khoá KHÔNG hiện `titleKey`/`descKey` (không lộ
/// nội dung chưa mở khoá).
class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.unlocked});

  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? NeonTheme.gold : NeonTheme.inkSoft;
    return Container(
      padding: const EdgeInsets.all(NeonTheme.s8),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: unlocked ? 2.5 : 1.5),
        boxShadow: unlocked ? NeonTheme.glow(color) : null,
      ),
      child: Opacity(
        opacity: unlocked ? 1.0 : 0.5,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              unlocked ? Icons.emoji_events_rounded : Icons.lock_rounded,
              color: color,
              size: 26,
            ),
            if (unlocked) ...[
              const SizedBox(height: 4),
              Text(
                achievement.titleKey.tr,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: NeonTheme.ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../data/board_frames.dart';
import '../../data/burst_styles.dart';
import '../../data/combo_text_styles.dart';
import '../../data/mascot_skins.dart';
import '../controllers/game_controller.dart';
import '../widgets/mascot_skin_tile.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';

/// I77: gộp cả 4 hệ cosmetic (mascot skin, board frame, burst style, combo
/// text style) đã shipped riêng lẻ vào 1 màn "album" duy nhất, đọc lại state
/// đã có sẵn trên [GameController] — không thêm hệ unlock mới, chỉ trình bày
/// lại + hiển thị tiến độ mốc thưởng xu ([GameController.totalCosmeticsOwned]).
class StickerAlbumScreen extends StatelessWidget {
  const StickerAlbumScreen({super.key});

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
              NeonAppBar(
                title: 'sticker_album_title'.tr,
                color: NeonTheme.magenta,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(NeonTheme.s16),
                  children: [
                    Obx(
                      () => _ProgressBanner(
                        owned: gameCtrl.totalCosmeticsOwned,
                        total:
                            kMascotSkins.length +
                            kBoardFrames.length +
                            kBurstStyles.length +
                            kComboTextStyles.length,
                      ),
                    ),
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
                          return MascotSkinTile(
                            skin: skin,
                            unlocked: unlocked,
                            mascotSize: 48,
                          );
                        },
                      );
                    }),
                    const SizedBox(height: NeonTheme.s16),
                    _sectionHeader('drawer_board_frame_label'.tr),
                    Obx(() {
                      gameCtrl.prestigeTier.value;
                      gameCtrl.unlockedAchievementIds.length;
                      gameCtrl.treasureMapCompleted.value;
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
                        itemCount: kBoardFrames.length,
                        itemBuilder: (context, i) {
                          final frame = kBoardFrames[i];
                          final unlocked = isBoardFrameUnlocked(
                            frame,
                            gameCtrl.prestigeTier.value,
                            gameCtrl.unlockedAchievementIds,
                            treasureMapCompleted:
                                gameCtrl.treasureMapCompleted.value,
                          );
                          return _BoardFrameTile(
                            frame: frame,
                            unlocked: unlocked,
                          );
                        },
                      );
                    }),
                    const SizedBox(height: NeonTheme.s16),
                    _sectionHeader('drawer_burst_style_label'.tr),
                    Obx(() {
                      gameCtrl.totalGemsPopped.value;
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
                        itemCount: kBurstStyles.length,
                        itemBuilder: (context, i) {
                          final style = kBurstStyles[i];
                          final unlocked = isBurstStyleUnlocked(
                            style,
                            gameCtrl.totalGemsPopped.value,
                          );
                          return _SimpleCosmeticTile(
                            nameKey: style.nameKey,
                            unlocked: unlocked,
                            icon: Icons.auto_awesome_motion_rounded,
                            color: NeonTheme.indigo,
                          );
                        },
                      );
                    }),
                    const SizedBox(height: NeonTheme.s16),
                    _sectionHeader('drawer_combo_text_style_label'.tr),
                    Obx(() {
                      gameCtrl.maxComboEver.value;
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
                        itemCount: kComboTextStyles.length,
                        itemBuilder: (context, i) {
                          final style = kComboTextStyles[i];
                          final unlocked = isComboTextStyleUnlocked(
                            style,
                            gameCtrl.maxComboEver.value,
                          );
                          return _SimpleCosmeticTile(
                            nameKey: style.nameKey,
                            unlocked: unlocked,
                            icon: Icons.text_fields_rounded,
                            color: NeonTheme.yellow,
                          );
                        },
                      );
                    }),
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

class _ProgressBanner extends StatelessWidget {
  const _ProgressBanner({required this.owned, required this.total});

  final int owned;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NeonTheme.s16,
        vertical: NeonTheme.s8,
      ),
      decoration: BoxDecoration(
        color: NeonTheme.cardAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: NeonTheme.magenta),
          const SizedBox(width: NeonTheme.s8),
          // `Expanded` để chuỗi xuống dòng thay vì tràn: nó dài theo bản dịch
          // VÀ theo cỡ chữ hệ thống, hai thứ layout này không kiểm soát.
          Expanded(
            child: Text(
              'sticker_album_progress'.trParams({
                'owned': '$owned',
                'total': '$total',
              }),
              style: TextStyle(
                color: NeonTheme.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardFrameTile extends StatelessWidget {
  const _BoardFrameTile({required this.frame, required this.unlocked});

  final BoardFrame frame;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? frame.color : NeonTheme.inkSoft;
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
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                border: Border.all(color: frame.color, width: 3),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              frame.nameKey.tr,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: NeonTheme.ink,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ dùng chung cho Burst Style/Combo Text Style — cả 2 chỉ có
/// `nameKey`/`unlockThreshold`, không có màu/icon riêng theo từng entry.
class _SimpleCosmeticTile extends StatelessWidget {
  const _SimpleCosmeticTile({
    required this.nameKey,
    required this.unlocked,
    required this.icon,
    required this.color,
  });

  final String nameKey;
  final bool unlocked;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tileColor = unlocked ? color : NeonTheme.inkSoft;
    return Container(
      padding: const EdgeInsets.all(NeonTheme.s8),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tileColor, width: unlocked ? 2.5 : 1.5),
        boxShadow: unlocked ? NeonTheme.glow(tileColor) : null,
      ),
      child: Opacity(
        opacity: unlocked ? 1.0 : 0.5,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              unlocked ? icon : Icons.lock_rounded,
              color: tileColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              nameKey.tr,
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
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../../data/achievements.dart';
import '../../data/mascot_skins.dart';
import '../controllers/game_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/star_mascot.dart';

/// I30: chọn/mua trang phục (skin) cho `StarMascot` — mở khoá bằng xu hoặc
/// đạt thành tựu mốc cao.
class MascotWardrobeScreen extends StatelessWidget {
  const MascotWardrobeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameCtrl = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'wardrobe_title'.tr,
                color: NeonTheme.magenta,
                actions: [CoinChip(gameCtrl)],
              ),
              Expanded(
                child: Obx(() {
                  // Đọc trực tiếp mọi Rx dùng trong itemBuilder (lazy) để Obx
                  // đăng ký được observable — cùng pattern AchievementsScreen.
                  gameCtrl.coins.value;
                  gameCtrl.unlockedMascotSkinIds.length;
                  gameCtrl.activeMascotSkinId.value;
                  return GridView.builder(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: NeonTheme.s16,
                          crossAxisSpacing: NeonTheme.s16,
                          childAspectRatio: 0.82,
                        ),
                    itemCount: kMascotSkins.length,
                    itemBuilder: (context, i) {
                      final skin = kMascotSkins[i];
                      final unlocked = gameCtrl.unlockedMascotSkinIds.contains(
                        skin.id,
                      );
                      final active =
                          gameCtrl.activeMascotSkinId.value == skin.id;
                      final canAfford =
                          skin.coinPrice != null &&
                          gameCtrl.coins.value >= skin.coinPrice!;
                      return _SkinCard(
                        skin: skin,
                        unlocked: unlocked,
                        active: active,
                        canAfford: canAfford,
                        onBuy: () => gameCtrl.buySkin(skin),
                        onSelect: () => gameCtrl.selectMascotSkin(skin.id),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.unlocked,
    required this.active,
    required this.canAfford,
    required this.onBuy,
    required this.onSelect,
  });

  final MascotSkin skin;
  final bool unlocked;
  final bool active;
  final bool canAfford;
  final VoidCallback onBuy;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? NeonTheme.gold
        : (unlocked ? NeonTheme.magenta : NeonTheme.inkSoft);
    return Container(
      padding: const EdgeInsets.all(NeonTheme.s8),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: active ? 2.5 : 1.5),
        boxShadow: active ? NeonTheme.glow(color) : NeonTheme.drop(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Opacity(
              opacity: unlocked ? 1.0 : 0.45,
              child: Center(child: StarMascot(size: 72, palette: skin.palette)),
            ),
          ),
          Text(
            skin.nameKey.tr,
            style: TextStyle(
              color: NeonTheme.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: NeonTheme.s8),
          _actionArea(),
        ],
      ),
    );
  }

  Widget _actionArea() {
    if (active) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: NeonTheme.gold,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            'wardrobe_selected_label'.tr,
            style: const TextStyle(
              color: NeonTheme.gold,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    if (unlocked) {
      return PressableScale(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: NeonTheme.s16,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: NeonTheme.magenta,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'wardrobe_select_button'.tr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    if (skin.coinPrice != null) {
      return PressableScale(
        onTap: canAfford ? onBuy : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: canAfford ? NeonTheme.yellow : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: canAfford ? NeonTheme.yellow : Colors.grey,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoinIcon(size: 14),
              const SizedBox(width: 4),
              Text(
                fmtNum(skin.coinPrice!),
                style: TextStyle(
                  color: canAfford ? Colors.white : NeonTheme.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final achievement = kAchievements.firstWhere(
      (a) => a.id == skin.unlockAchievementId,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_rounded, color: NeonTheme.inkSoft, size: 14),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            'wardrobe_unlock_via'.trParams({
              'achievement': achievement.titleKey.tr,
            }),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NeonTheme.inkSoft,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../data/constellations.dart';
import '../controllers/game_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_icon.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/stroke_text.dart';

/// I64: Màn hình Đền Trời & Chòm Sao (Sky Shrine).
class SkyShrineScreen extends StatelessWidget {
  const SkyShrineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameCtrl = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'sky_shrine_title'.tr,
                color: NeonTheme.cyan,
                actions: [
                  Obx(
                    () => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: NeonTheme.s8 * 1.5,
                        vertical: NeonTheme.s8 * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: NeonTheme.ink.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: NeonTheme.cyan.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const NeonIcon(
                            Icons.eco_rounded,
                            color: NeonTheme.teal,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${gameCtrl.starSeedCount.value}',
                            style: const TextStyle(
                              color: NeonTheme.teal,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CoinChip(gameCtrl),
                ],
              ),
              Expanded(
                child: Obx(
                  () => ListView(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(NeonTheme.s16),
                        decoration: BoxDecoration(
                          color: NeonTheme.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: NeonTheme.cyan.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const NeonIcon(
                              Icons.star_rounded,
                              color: NeonTheme.gold,
                              size: 32,
                            ),
                            const SizedBox(width: NeonTheme.s8 * 1.5),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'sky_shrine_stars_collected'.trParams({
                                      'stars': '${gameCtrl.totalStars.value}',
                                    }),
                                    style: TextStyle(
                                      color: NeonTheme.ink,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'sky_shrine_sub'.tr,
                                    style: TextStyle(
                                      color: NeonTheme.inkSoft,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: NeonTheme.s16),
                      for (var i = 0; i < kConstellations.length; i++) ...[
                        if (i > 0) const SizedBox(height: NeonTheme.s8 * 1.5),
                        _ConstellationCard(
                          constellation: kConstellations[i],
                          index: i,
                          gameCtrl: gameCtrl,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConstellationCard extends StatelessWidget {
  const _ConstellationCard({
    required this.constellation,
    required this.index,
    required this.gameCtrl,
  });

  final Constellation constellation;
  final int index;
  final GameController gameCtrl;

  @override
  Widget build(BuildContext context) {
    final totalStars = gameCtrl.totalStars.value;
    final isLit = isConstellationLit(constellation, totalStars);
    final isSeedClaimed = gameCtrl.isStarSeedClaimed(index);
    final isActiveAura =
        gameCtrl.activeSkyAura.value == constellation.auraVariant;

    // Direct trigger seed claim if lit and not claimed yet
    if (isLit && !isSeedClaimed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        gameCtrl.claimStarSeedForConstellation(index);
      });
    }

    return Container(
      padding: const EdgeInsets.all(NeonTheme.s16),
      decoration: BoxDecoration(
        color: isLit
            ? constellation.color.withValues(alpha: 0.15)
            : NeonTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLit ? constellation.color : NeonTheme.inkSoft.withValues(alpha: 0.2),
          width: isLit ? 2 : 1,
        ),
        boxShadow: isLit ? NeonTheme.glow(constellation.color) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isLit
                  ? constellation.color.withValues(alpha: 0.2)
                  : NeonTheme.inkSoft.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              constellation.icon,
              color: isLit ? constellation.color : NeonTheme.inkSoft,
              size: 28,
            ),
          ),
          const SizedBox(width: NeonTheme.s8 * 1.5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StrokeText(
                  constellation.nameKey.tr,
                  fontSize: 16,
                  color: isLit ? constellation.color : NeonTheme.inkSoft,
                ),
                const SizedBox(height: 4),
                Text(
                  isLit
                      ? 'sky_shrine_lit'.tr
                      : 'sky_shrine_stars_req'.trParams({
                          'req': '${constellation.starsRequired}',
                          'curr': '$totalStars',
                        }),
                  style: TextStyle(
                    color: isLit ? NeonTheme.ink : NeonTheme.inkSoft,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (isLit)
            PressableScale(
              onTap: () {
                if (isActiveAura) {
                  gameCtrl.setActiveSkyAura('default');
                } else {
                  gameCtrl.setActiveSkyAura(constellation.auraVariant);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: NeonTheme.s8 * 1.5,
                  vertical: NeonTheme.s8,
                ),
                decoration: BoxDecoration(
                  color: isActiveAura
                      ? constellation.color
                      : constellation.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: constellation.color),
                ),
                child: Text(
                  isActiveAura
                      ? 'sky_shrine_aura_active'.tr
                      : 'sky_shrine_aura_equip'.tr,
                  style: TextStyle(
                    color: isActiveAura ? Colors.white : constellation.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

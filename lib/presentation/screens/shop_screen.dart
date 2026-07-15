import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../controllers/game_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/pressable_scale.dart';

/// Cửa hàng booster: bomb / shuffle / undo, mua bằng xu.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameCtrl = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'shop_title'.tr,
                color: NeonTheme.yellow,
                actions: [CoinChip(gameCtrl)],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(NeonTheme.s16),
                  children: [
                    Obx(
                      () => _BoosterRow(
                        icon: Icons.dangerous_rounded,
                        color: NeonTheme.orange,
                        label: 'booster_bomb_label'.tr,
                        desc: 'booster_bomb_desc'.tr,
                        count: gameCtrl.bombCount.value,
                        price: GameController.bombPrice,
                        canAfford:
                            gameCtrl.coins.value >= GameController.bombPrice,
                        onBuy: gameCtrl.buyBomb,
                      ),
                    ),
                    const SizedBox(height: NeonTheme.s16),
                    Obx(
                      () => _BoosterRow(
                        icon: Icons.shuffle_rounded,
                        color: NeonTheme.cyan,
                        label: 'shuffle'.tr,
                        desc: 'booster_shuffle_desc'.tr,
                        count: gameCtrl.shuffleCount.value,
                        price: GameController.shufflePrice,
                        canAfford:
                            gameCtrl.coins.value >= GameController.shufflePrice,
                        onBuy: gameCtrl.buyShuffle,
                      ),
                    ),
                    const SizedBox(height: NeonTheme.s16),
                    Obx(
                      () => _BoosterRow(
                        icon: Icons.undo_rounded,
                        color: NeonTheme.purple,
                        label: 'booster_undo_label'.tr,
                        desc: 'booster_undo_desc'.tr,
                        count: gameCtrl.undoCount.value,
                        price: GameController.undoPrice,
                        canAfford:
                            gameCtrl.coins.value >= GameController.undoPrice,
                        onBuy: gameCtrl.buyUndo,
                      ),
                    ),
                    const SizedBox(height: NeonTheme.s16),
                    Obx(
                      () => _BoosterRow(
                        icon: Icons.auto_awesome_rounded,
                        color: NeonTheme.magenta,
                        label: 'booster_rainbow_label'.tr,
                        desc: 'booster_rainbow_desc'.tr,
                        count: gameCtrl.rainbowCount.value,
                        price: GameController.rainbowPrice,
                        canAfford:
                            gameCtrl.coins.value >= GameController.rainbowPrice,
                        onBuy: gameCtrl.buyRainbow,
                      ),
                    ),
                    const SizedBox(height: NeonTheme.s16),
                    Obx(
                      () => _BoosterRow(
                        icon: Icons.swap_horiz_rounded,
                        color: NeonTheme.lime,
                        label: 'booster_swap_label'.tr,
                        desc: 'booster_swap_desc'.tr,
                        count: gameCtrl.swapCount.value,
                        price: GameController.swapPrice,
                        canAfford:
                            gameCtrl.coins.value >= GameController.swapPrice,
                        onBuy: gameCtrl.buySwap,
                      ),
                    ),
                    const SizedBox(height: NeonTheme.s16),
                    Obx(
                      () => _BoosterRow(
                        icon: Icons.ac_unit_rounded,
                        color: NeonTheme.cyan,
                        label: 'booster_freeze_label'.tr,
                        desc: 'booster_freeze_desc'.trParams({
                          'n': '${GameController.freezeTurns}',
                        }),
                        count: gameCtrl.freezeCount.value,
                        price: GameController.freezePrice,
                        canAfford:
                            gameCtrl.coins.value >= GameController.freezePrice,
                        onBuy: gameCtrl.buyFreeze,
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

class _BoosterRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String desc;
  final int count;
  final int price;
  final bool canAfford;
  final VoidCallback onBuy;

  const _BoosterRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.desc,
    required this.count,
    required this.price,
    required this.canAfford,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NeonTheme.s16),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2.5),
        boxShadow: NeonTheme.drop(),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: NeonTheme.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(end: count.toDouble()),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  builder: (_, v, _) => Text(
                    '$label  ×${v.round()}',
                    style: TextStyle(
                      color: NeonTheme.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: NeonTheme.s8),
                Text(
                  desc,
                  style: TextStyle(color: NeonTheme.inkSoft, fontSize: 12),
                ),
              ],
            ),
          ),
          PressableScale(
            onTap: canAfford ? onBuy : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: NeonTheme.s16,
                vertical: NeonTheme.s8,
              ),
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
                  const SizedBox(width: NeonTheme.s8),
                  Text(
                    fmtNum(price),
                    style: TextStyle(
                      color: canAfford ? Colors.white : NeonTheme.inkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

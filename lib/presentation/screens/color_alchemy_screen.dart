import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../../data/achievements.dart';
import '../../data/pigments.dart';
import '../controllers/game_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/pressable_scale.dart';

class ColorAlchemyScreen extends StatelessWidget {
  const ColorAlchemyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'alchemy_title'.tr,
                color: NeonTheme.purple,
                actions: [CoinChip(controller)],
              ),
              Padding(
                padding: const EdgeInsets.all(NeonTheme.s16),
                child: Text(
                  'alchemy_hint'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: NeonTheme.inkSoft),
                ),
              ),
              Expanded(
                child: Obx(() {
                  controller.coins.value;
                  controller.unlockedPigmentIds.length;
                  controller.unlockedAchievementIds.length;
                  controller.gemColorOverrides.length;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NeonTheme.s16,
                    ),
                    itemCount: NeonTheme.gemColors.length,
                    itemBuilder: (_, slot) =>
                        _SlotRow(slot: slot, controller: controller),
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

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.slot, required this.controller});
  final int slot;
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final selectedId = controller.gemColorOverrides[slot];
    return Card(
      color: NeonTheme.card,
      margin: const EdgeInsets.only(bottom: NeonTheme.s8),
      child: Padding(
        padding: const EdgeInsets.all(NeonTheme.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: resolvedGemColor(slot)),
                const SizedBox(width: NeonTheme.s8),
                Expanded(
                  child: Text(
                    'alchemy_slot'.trParams({'slot': '${slot + 1}'}),
                    style: TextStyle(
                      color: NeonTheme.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (selectedId != null)
                  TextButton(
                    onPressed: () => controller.clearGemColorOverride(slot),
                    child: Text('alchemy_reset'.tr),
                  ),
              ],
            ),
            Wrap(
              spacing: NeonTheme.s8,
              runSpacing: NeonTheme.s8,
              children: [
                for (final pigment in kPigments)
                  _PigmentChip(
                    pigment: pigment,
                    selected: pigment.id == selectedId,
                    controller: controller,
                    slot: slot,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PigmentChip extends StatelessWidget {
  const _PigmentChip({
    required this.pigment,
    required this.selected,
    required this.controller,
    required this.slot,
  });
  final Pigment pigment;
  final bool selected;
  final GameController controller;
  final int slot;

  @override
  Widget build(BuildContext context) {
    final unlocked = controller.isPigmentUnlocked(pigment);
    return PressableScale(
      onTap: () {
        if (unlocked) {
          controller.setGemColorOverride(slot, pigment.id);
        } else if (pigment.coinPrice != null &&
            controller.buyPigment(pigment)) {
          controller.setGemColorOverride(slot, pigment.id);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: pigment.color.withValues(alpha: unlocked ? 0.22 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? pigment.color : NeonTheme.inkSoft,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 7, backgroundColor: pigment.color),
            const SizedBox(width: 5),
            Text(pigment.nameKey.tr),
            if (!unlocked) ...[
              const SizedBox(width: 4),
              Text(
                pigment.coinPrice != null
                    ? fmtNum(pigment.coinPrice!)
                    : kAchievements
                          .firstWhere(
                            (a) => a.id == pigment.unlockAchievementId,
                          )
                          .titleKey
                          .tr,
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

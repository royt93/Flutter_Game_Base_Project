import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../../logic/mystery_crate.dart';
import '../controllers/game_controller.dart';
import 'neon_dialog.dart';
import 'neon_icon.dart';
import 'stroke_text.dart';

/// I63: Dialog mở Cosmetic Mystery Crate.
void showMysteryCrateDialog(BuildContext context, GameController gameCtrl) {
  NeonDialog.show(
    context: context,
    title: 'mystery_crate_title'.tr,
    color: NeonTheme.magenta,
    icon: Icons.inventory_2_rounded,
    content: _MysteryCrateContent(gameCtrl: gameCtrl),
    actions: [
      NeonDialogAction(
        label: 'coll_close'.tr,
        color: NeonTheme.magenta,
        onTap: () {},
      ),
    ],
  );
}

class _MysteryCrateContent extends StatefulWidget {
  const _MysteryCrateContent({required this.gameCtrl});

  final GameController gameCtrl;

  @override
  State<_MysteryCrateContent> createState() => _MysteryCrateContentState();
}

class _MysteryCrateContentState extends State<_MysteryCrateContent> {
  CosmeticEntry? _rolledItem;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final coins = widget.gameCtrl.coins.value;
      final cost = GameController.mysteryCrateCost;
      final canAfford = coins >= cost;

      final allEntries = getAllCosmeticEntries();
      final eligibleCount = allEntries.where((entry) {
        switch (entry.kind) {
          case CosmeticKind.mascotSkin:
            final isUnlocked = widget.gameCtrl.unlockedMascotSkinIds.contains(entry.id);
            return !isUnlocked;
          case CosmeticKind.boardFrame:
            final isActive = widget.gameCtrl.activeBoardFrameId.value == entry.id;
            return !isActive;
          case CosmeticKind.burstStyle:
            final isActive = widget.gameCtrl.activeBurstStyleKind.value.name == entry.id;
            return !isActive;
          case CosmeticKind.comboTextStyle:
            final isActive = widget.gameCtrl.activeComboTextStyleKind.value.name == entry.id;
            return !isActive;
        }
      }).length;

      final poolEmpty = eligibleCount == 0;

      return Column(
        children: [
          if (_rolledItem != null) ...[
            Container(
              padding: const EdgeInsets.all(NeonTheme.s16),
              decoration: BoxDecoration(
                color: _rolledItem!.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _rolledItem!.color, width: 2),
                boxShadow: NeonTheme.glow(_rolledItem!.color),
              ),
              child: Column(
                children: [
                  NeonIcon(
                    Icons.card_giftcard_rounded,
                    color: _rolledItem!.color,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'mystery_crate_unlocked_label'.tr,
                    style: TextStyle(
                      color: NeonTheme.inkSoft,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StrokeText(
                    _rolledItem!.nameKey.tr,
                    fontSize: 20,
                    color: _rolledItem!.color,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Text(
              'mystery_crate_desc'.trParams({'cost': fmtNum(cost)}),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: NeonTheme.inkSoft,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed: (!canAfford || poolEmpty)
                ? null
                : () {
                    final item = widget.gameCtrl.rollMysteryCrate();
                    if (item != null) {
                      setState(() => _rolledItem = item);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: NeonTheme.magenta,
              disabledBackgroundColor: NeonTheme.muted,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  poolEmpty
                      ? 'mystery_crate_empty_pool'.tr
                      : 'mystery_crate_open_button'.trParams({
                          'cost': fmtNum(cost),
                        }),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

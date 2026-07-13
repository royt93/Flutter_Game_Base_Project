import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../data/perks.dart';
import '../controllers/game_controller.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';

/// F14: chọn tối đa 2 perk vĩnh viễn (mở khoá theo world đã hoàn thành),
/// áp dụng ngay khi vào level kế tiếp — không đổi giữa chừng ván.
class PerksScreen extends StatelessWidget {
  const PerksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameCtrl = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'perks_title'.tr, color: NeonTheme.magenta),
              Expanded(
                child: Obx(() {
                  final unlockedIds = gameCtrl.unlockedPerksList
                      .map((p) => p.id)
                      .toSet();
                  return ListView.builder(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    itemCount: kPerks.length,
                    itemBuilder: (context, i) {
                      final perk = kPerks[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: NeonTheme.s8),
                        child: _PerkRow(
                          perk: perk,
                          unlocked: unlockedIds.contains(perk.id),
                          active: gameCtrl.activePerkIds.contains(perk.id),
                          onTap: () => gameCtrl.togglePerk(perk.id),
                        ),
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

class _PerkRow extends StatelessWidget {
  final Perk perk;
  final bool unlocked;
  final bool active;
  final VoidCallback onTap;

  const _PerkRow({
    required this.perk,
    required this.unlocked,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? NeonTheme.gold : NeonTheme.magenta;
    return Opacity(
      opacity: unlocked ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: unlocked ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: NeonTheme.s16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: NeonTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: active ? 2.5 : 1.5),
            boxShadow: active ? NeonTheme.glow(color) : null,
          ),
          child: Row(
            children: [
              Icon(
                unlocked
                    ? (active ? Icons.check_circle : Icons.radio_button_off)
                    : Icons.lock,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      perk.nameKey.tr,
                      style: TextStyle(
                        color: NeonTheme.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      unlocked
                          ? perk.descKey.tr
                          : '${'perk_locked'.tr} ${perk.unlockAfterWorld}',
                      style: TextStyle(
                        color: NeonTheme.inkSoft,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
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

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../data/constellations.dart';
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
                  // I83: perk prestige nằm CHUNG danh sách này, không có màn
                  // riêng — cả game chỉ có một chỗ chọn perk.
                  final unlockedIds = gameCtrl.allUnlockedPerks
                      .map((p) => p.id)
                      .toSet();
                  final all = [...kPerks, ...kPrestigePerks];
                  return ListView.builder(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    // +1 cho dòng đếm ô perk ở đầu danh sách.
                    itemCount: all.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          key: const Key('perk_slots_label'),
                          padding: const EdgeInsets.only(bottom: NeonTheme.s8),
                          child: Text(
                            'pp_slots'.trParams({
                              'used': '${gameCtrl.activePerkIds.length}',
                              'max': '${gameCtrl.perkSlots}',
                            }),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: NeonTheme.inkSoft,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }
                      final perk = all[i - 1];
                      final isPrestige = kPrestigePerks.contains(perk);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: NeonTheme.s8),
                        child: _PerkRow(
                          perk: perk,
                          unlocked: unlockedIds.contains(perk.id),
                          // Perk prestige chưa mở hiện gợi ý "Prestige để mở
                          // khoá" — đây chính là động lực prestige mà AC yêu
                          // cầu, thay vì ẩn hẳn.
                          lockedHint:
                              isPrestige && !unlockedIds.contains(perk.id)
                              ? 'pp_locked_hint'.tr
                              : null,
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

  /// I83: dòng phụ giải thích vì sao perk còn khoá (`null` = không hiện).
  final String? lockedHint;

  const _PerkRow({
    required this.perk,
    required this.unlocked,
    required this.active,
    required this.onTap,
    this.lockedHint,
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
                      // I83: perk prestige gate theo constellation + tier chứ
                      // không theo world, nên `unlockAfterWorld` (= 0) vô
                      // nghĩa với chúng — dùng `lockedHint` thay.
                      unlocked
                          ? perk.descKey.tr
                          : lockedHint ??
                                '${'perk_locked'.tr} ${perk.unlockAfterWorld}',
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

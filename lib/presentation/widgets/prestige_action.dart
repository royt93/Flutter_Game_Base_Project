import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../controllers/game_controller.dart';
import 'neon_dialog.dart';

/// I27: mở dialog xác nhận Prestige — no-op nếu chưa đủ điều kiện
/// ([PrestigeAction] tự ẩn/khoá tap trong trường hợp đó nên bình thường
/// không gọi được, nhưng vẫn guard ở đây cho chắc). Dùng chung ở cả
/// `HomeScreen` lẫn `LevelSelectScreen`.
void showPrestigeDialog(BuildContext context, GameController gameCtrl) {
  if (!gameCtrl.canPrestige) return;
  final nextTier = gameCtrl.prestigeTier.value + 1;
  NeonDialog.show(
    context: context,
    title: 'prestige_title'.tr,
    color: NeonTheme.magenta,
    icon: Icons.auto_awesome_rounded,
    message: 'prestige_msg'.trParams({
      'tier': '$nextTier',
      'coin': '${GameController.prestigeRewardCoins}',
    }),
    actions: [
      NeonDialogAction(label: 'cancel'.tr, color: NeonTheme.cyan, onTap: () {}),
      NeonDialogAction(
        label: 'prestige_confirm'.tr,
        color: NeonTheme.magenta,
        onTap: gameCtrl.prestige,
      ),
    ],
  );
}

/// I27: badge/entry-point Prestige — ẩn hoàn toàn nếu chưa từng prestige và
/// chưa đủ điều kiện; hiện tier tĩnh (`P{tier}`) nếu đã prestige nhưng chưa
/// đủ điều kiện lần kế; tappable khi [GameController.canPrestige]. Dùng
/// chung ở cả `HomeScreen` lẫn `LevelSelectScreen` (X15: đóng gap thiếu badge
/// ở Home so với spec I27).
class PrestigeAction extends StatelessWidget {
  const PrestigeAction({
    super.key,
    required this.gameCtrl,
    required this.onTap,
  });

  final GameController gameCtrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tier = gameCtrl.prestigeTier.value;
      final ready = gameCtrl.canPrestige;
      if (tier == 0 && !ready) return const SizedBox.shrink();
      return GestureDetector(
        key: const Key('prestige_badge'),
        onTap: ready ? onTap : null,
        child: Container(
          margin: const EdgeInsetsDirectional.only(end: NeonTheme.s8),
          padding: const EdgeInsets.symmetric(
            horizontal: NeonTheme.s16,
            vertical: NeonTheme.s8,
          ),
          decoration: BoxDecoration(
            color: NeonTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: NeonTheme.magenta, width: 2),
            boxShadow: NeonTheme.drop(y: 3, blur: 6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: NeonTheme.magenta,
                size: 18,
              ),
              const SizedBox(width: NeonTheme.s8),
              Text(
                ready
                    ? 'prestige_ready'.trParams({'tier': '${tier + 1}'})
                    : 'P$tier',
                style: TextStyle(
                  color: NeonTheme.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

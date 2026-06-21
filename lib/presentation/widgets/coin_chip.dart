import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../controllers/game_controller.dart';

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.monetization_on_rounded, color: NeonTheme.yellow, size: size);
}

/// Chip hiển thị số xu (icon vàng + viền/glow neon), reactive theo
/// [GameController.coins]. Dùng chung cho action bar các màn phụ
/// (Đền Neon, Thành tựu, Level Select, World Map).
class CoinChip extends StatelessWidget {
  const CoinChip(this.controller, {super.key});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: NeonTheme.s8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NeonTheme.yellow, width: 1.5),
        boxShadow: NeonTheme.glow(NeonTheme.yellow, blur: 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinIcon(),
          const SizedBox(width: 5),
          Obx(
            () => Text(
              fmtNum(controller.coins.value),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
      Icon(Icons.monetization_on_rounded, color: NeonTheme.gold, size: size);
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
      // `end` chứ không `right`: ở tiếng Ả Rập hàng chip lật, khoảng hở phải
      // theo sang bên kia, nếu không hai chip dính vào nhau.
      margin: const EdgeInsetsDirectional.only(end: NeonTheme.s8),
      padding: const EdgeInsets.symmetric(
        horizontal: NeonTheme.s16,
        vertical: NeonTheme.s8,
      ),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NeonTheme.gold, width: 2),
        boxShadow: NeonTheme.drop(y: 3, blur: 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinIcon(),
          const SizedBox(width: NeonTheme.s8),
          Obx(
            () => TweenAnimationBuilder<double>(
              tween: Tween(end: controller.coins.value.toDouble()),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (_, v, _) => Text(
                fmtNum(v.round()),
                style: TextStyle(
                  color: NeonTheme.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

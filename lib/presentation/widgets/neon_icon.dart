import 'package:flutter/material.dart';

/// Icon phong cách neon: lõi trắng + glow màu (dùng chung toàn app).
class NeonIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const NeonIcon(this.icon, {super.key, required this.color, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: Colors.white,
      shadows: [
        Shadow(color: color, blurRadius: 14),
        Shadow(color: color, blurRadius: 6),
      ],
    );
  }
}

/// Nút icon neon bấm được (glow + vùng chạm rộng).
class NeonIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;

  const NeonIconButton(
    this.icon, {
    super.key,
    required this.color,
    required this.onTap,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: NeonIcon(icon, color: color, size: size),
      splashRadius: 24,
    );
  }
}

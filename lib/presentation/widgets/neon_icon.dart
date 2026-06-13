import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

/// Nút back neon dùng chung cho mọi màn phụ (mặc định quay lại màn trước).
class NeonBackButton extends StatelessWidget {
  final Color color;
  final VoidCallback? onTap;
  const NeonBackButton({super.key, this.color = const Color(0xFF00F0FF), this.onTap});

  @override
  Widget build(BuildContext context) {
    return NeonIconButton(
      Icons.arrow_back_rounded,
      color: color,
      onTap: onTap ?? Get.back,
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

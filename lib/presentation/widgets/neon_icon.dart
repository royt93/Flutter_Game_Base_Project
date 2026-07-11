import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';

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
  const NeonBackButton({
    super.key,
    this.color = const Color(0xFF00F0FF),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NeonIconButton(
      Icons.arrow_back_rounded,
      color: color,
      onTap: onTap ?? Get.back,
    );
  }
}

/// Nút icon neon bấm được (glow + vùng chạm rộng). [boxed] = chip tròn viền
/// neon + glow (dùng cho lối vào chính ở Home); mặc định icon trần (back/appbar).
class NeonIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;
  final bool boxed;

  const NeonIconButton(
    this.icon, {
    super.key,
    required this.color,
    required this.onTap,
    this.size = 24,
    this.boxed = false,
  });

  @override
  Widget build(BuildContext context) {
    if (boxed) {
      final enabled = onTap != null;
      final c = enabled ? color : Colors.grey;
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: NeonTheme.card,
            shape: BoxShape.circle,
            border: Border.all(color: c, width: 3),
            boxShadow: enabled ? NeonTheme.drop(y: 4, blur: 10) : null,
          ),
          child: Center(
            child: NeonIcon(icon, color: c, size: size),
          ),
        ),
      );
    }
    return IconButton(
      onPressed: onTap,
      icon: NeonIcon(icon, color: color, size: size),
      splashRadius: 24,
    );
  }
}

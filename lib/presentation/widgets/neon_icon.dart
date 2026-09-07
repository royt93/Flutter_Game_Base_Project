import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import 'pressable_scale.dart';

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
  final Color? color;
  final VoidCallback? onTap;
  const NeonBackButton({super.key, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return NeonIconButton(
      Icons.arrow_back_rounded,
      color: color ?? NeonTheme.cyan,
      onTap: onTap ?? Get.back,
      // Trước đây hardcode tiếng Việt — người dùng 21 ngôn ngữ khác nghe
      // TalkBack đọc 'Quay lại'.
      semanticLabel: 'back_button_label'.tr,
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
  final String? semanticLabel;
  final bool compact;

  const NeonIconButton(
    this.icon, {
    super.key,
    required this.color,
    required this.onTap,
    this.size = 24,
    this.boxed = false,
    this.semanticLabel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (boxed) {
      final enabled = onTap != null;
      final c = enabled ? color : Colors.grey;
      return Semantics(
        button: true,
        enabled: enabled,
        label: semanticLabel,
        child: PressableScale(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: NeonTheme.card,
              shape: BoxShape.circle,
              // ponytail: bỏ viền solid cứng (thô), thay bằng halo phát sáng
              // mềm mại đúng chất neon — glow() toả 3 lớp mờ dần ra ngoài
              // thay vì 1 đường viền đứt khúc rõ nét.
              boxShadow: enabled
                  ? [
                      ...NeonTheme.glow(c, blur: 16, spread: 1),
                      ...NeonTheme.drop(y: 4, blur: 8),
                    ]
                  : NeonTheme.drop(y: 4, blur: 8),
            ),
            child: Center(
              child: NeonIcon(icon, color: c, size: size),
            ),
          ),
        ),
      );
    }
    return IconButton(
      onPressed: onTap,
      icon: NeonIcon(icon, color: color, size: size),
      splashRadius: 24,
      tooltip: semanticLabel,
      padding: compact ? EdgeInsets.zero : const EdgeInsets.all(8),
      constraints: compact
          ? const BoxConstraints(minWidth: 32, minHeight: 32)
          : null,
    );
  }
}

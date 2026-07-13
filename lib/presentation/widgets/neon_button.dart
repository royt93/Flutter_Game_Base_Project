import 'package:flutter/material.dart';
import '../../core/neon_theme.dart';
import 'pressable_scale.dart';
import 'stroke_text.dart';

/// Nút bấm phong cách neon: viền sáng + glow + chữ phát sáng.
class NeonButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final double width;
  final IconData? icon;
  final String? semanticLabel;

  const NeonButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.width = 240,
    this.icon,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final c = enabled ? color : const Color(0xFFB9B3CC);
    // Nút kẹo: thân solid màu accent, viền đáy đậm hơn (bevel), bóng đổ chunky.
    final darker = Color.lerp(c, Colors.black, 0.22)!;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(vertical: NeonTheme.s16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(c, Colors.white, 0.18)!, c],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border(bottom: BorderSide(color: darker, width: 4)),
            boxShadow: enabled ? NeonTheme.drop(y: 5, blur: 12) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: NeonTheme.s8),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: StrokeText(
                    label,
                    fontSize: 19,
                    color: Colors.white,
                    stroke: darker,
                    strokeWidth: 3.5,
                    weight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/neon_theme.dart';

/// Background neon dùng chung cho mọi màn (gradient + các quầng sáng mềm + vignette).
/// Rẻ (không MaskFilter) — dùng RadialGradient cho quầng sáng.
class NeonBg extends StatelessWidget {
  final Widget child;
  const NeonBg({super.key, required this.child});

  Widget _blob(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: NeonTheme.bgGradient),
      child: Stack(
        children: [
          Positioned(top: -80, left: -60, child: _blob(NeonTheme.cyan, 320)),
          Positioned(top: 120, right: -90, child: _blob(NeonTheme.magenta, 300)),
          Positioned(
              bottom: -100, left: -40, child: _blob(NeonTheme.purple, 360)),
          Positioned(
              bottom: 40, right: -60, child: _blob(NeonTheme.lime, 240)),
          // vignette
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.1,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                  stops: const [0.6, 1.0],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

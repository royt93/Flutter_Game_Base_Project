import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Reactive background that lerps between a "cool" and "hot" color as
/// [heat] rises (IDEA-08) — the caller computes [heat] from whatever combo/
/// streak mechanic it has (e.g. `min(1.0, comboCount / 10)`); this widget has
/// no idea what a "combo" is, matching [VictoryCardTemplate]'s convention of
/// taking caller-computed values rather than inventing game-specific
/// mechanics.
///
/// No GLSL shader here on purpose — a smoothly `AnimatedContainer`-lerped
/// gradient already reads as "heat" and is a much smaller/safer bet than
/// authoring a fragment shader for this.
class ComboHeatBackground extends StatelessWidget {
  const ComboHeatBackground({
    super.key,
    required this.heat,
    required this.child,
    this.coolColor,
    this.hotColor,
  });

  /// 0.0 = cool/calm, 1.0 = maximum heat. Values outside [0, 1] are clamped.
  final double heat;

  final Widget child;

  /// Defaults to [NeonTheme.cyan].
  final Color? coolColor;

  /// Defaults to [NeonTheme.orange].
  final Color? hotColor;

  @override
  Widget build(BuildContext context) {
    final cool = coolColor ?? NeonTheme.cyan;
    final hot = hotColor ?? NeonTheme.orange;
    final color = Color.lerp(cool, hot, heat.clamp(0.0, 1.0))!;
    return AnimatedContainer(
      duration: NeonTheme.reducedMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.18)!, color],
        ),
      ),
      child: child,
    );
  }
}

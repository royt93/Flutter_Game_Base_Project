import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Circular avatar wrapping an arbitrary [child] (typically an `Image`,
/// `Icon`, or initials `Text`) with a decorative colored ring around it — for
/// player profile displays.
class AvatarFrame extends StatelessWidget {
  const AvatarFrame({
    super.key,
    required this.child,
    this.color,
    this.size = 64,
    this.ringWidth = 3,
  });

  final Widget child;

  /// Defaults to [NeonTheme.cyan] — nullable because a `NeonTheme` color
  /// field is no longer a compile-time constant (see exportPalette/
  /// importPalette), so it can't be a `const` constructor default value.
  final Color? color;
  final double size;
  final double ringWidth;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? NeonTheme.cyan;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: ringWidth),
        boxShadow: NeonTheme.glow(color, blur: 12),
      ),
      padding: EdgeInsets.all(ringWidth),
      child: ClipOval(child: child),
    );
  }
}

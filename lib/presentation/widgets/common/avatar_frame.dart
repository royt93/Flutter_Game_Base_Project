import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';

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
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;

  /// Defaults to [NeonTheme.cyan] — nullable because a `NeonTheme` color
  /// field is no longer a compile-time constant (see exportPalette/
  /// importPalette), so it can't be a `const` constructor default value.
  final Color? color;
  final double size;
  final double ringWidth;

  /// Called when the avatar is tapped (e.g. to change it). When null, the
  /// frame stays purely display-only (no press feedback).
  final VoidCallback? onTap;

  /// Describes whose/what avatar this is (e.g. "Alice's avatar", "Change
  /// avatar") — [child] is caller-supplied (image/icon/initials) and can't
  /// describe itself, so without this a screen reader announces nothing
  /// meaningful for the frame.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? NeonTheme.cyan;
    final frame = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: ringWidth),
        boxShadow: NeonTheme.glow(color, blur: 12),
      ),
      padding: EdgeInsets.all(ringWidth),
      child: ClipOval(
        child: semanticLabel == null ? child : ExcludeSemantics(child: child),
      ),
    );
    // ENH-46: always wrap in PressableScale — with onTap null it's a no-op
    // (identical to the prior display-only behavior). Semantics(button:
    // true) only added when actually tappable.
    final pressable = PressableScale(onTap: onTap, child: frame);
    if (onTap == null && semanticLabel == null) return pressable;
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: pressable,
    );
  }
}

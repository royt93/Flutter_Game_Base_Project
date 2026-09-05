import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Generic rounded card/panel — the building-block container most screens
/// wrap content in. Background is [NeonTheme.card] (or [NeonTheme.cardAlt]
/// via [alt]), with a [NeonTheme.drop] shadow and an optional colored
/// [borderColor] accent ring.
class PanelCard extends StatelessWidget {
  const PanelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NeonTheme.s16),
    this.borderRadius = 22,
    this.borderColor,
    this.alt = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  /// Optional colored border accent — omit for a plain (borderless) card.
  final Color? borderColor;

  /// true = [NeonTheme.cardAlt] background, false = [NeonTheme.card].
  final bool alt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: alt ? NeonTheme.cardAlt : NeonTheme.card,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 2)
            : null,
        boxShadow: NeonTheme.drop(),
      ),
      child: child,
    );
  }
}

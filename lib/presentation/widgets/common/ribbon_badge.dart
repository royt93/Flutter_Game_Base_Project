import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Diagonal corner-ribbon overlay (e.g. "NEW"/"SALE"/"BEST VALUE") wrapping
/// any [child] — shop/IAP item badge. Draws into its own internal [Stack]
/// sized to [child], independent of any [Stack] the caller might have
/// (avoids the caller-owned-`Stack` coupling problem noted for
/// [LoadingOverlay]/ENH-03 — just wrap: `RibbonBadge(text: 'SALE',
/// child: myCard)`).
class RibbonBadge extends StatelessWidget {
  const RibbonBadge({
    super.key,
    required this.child,
    required this.text,
    this.color,
  });

  final Widget child;

  /// Ribbon label, e.g. "NEW", "SALE", "-50%".
  final String text;

  /// Ribbon background color. Default: [NeonTheme.red].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? NeonTheme.red;
    return ClipRect(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            top: 14,
            right: -34,
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 130,
                padding: const EdgeInsets.symmetric(vertical: 5),
                alignment: Alignment.center,
                color: c,
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

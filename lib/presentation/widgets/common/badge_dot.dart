import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Small round dot signaling "something's new"/"unclaimed reward" — placed
/// inside a [Stack] wrapping the caller's own icon/widget (e.g.
/// `Stack(children: [Icon(...), Positioned(
/// top: -2, right: -2, child: BadgeDot())])`). Does not position itself.
class BadgeDot extends StatelessWidget {
  const BadgeDot({super.key, this.size = 10, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? NeonTheme.red;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: NeonTheme.card, width: 1.5),
        boxShadow: NeonTheme.glow(c, blur: 6, spread: 0.3),
      ),
    );
  }
}

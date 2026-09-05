import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Chấm tròn nhỏ báo "có cái mới"/"chưa nhận thưởng" — đặt trong 1 [Stack] bọc
/// icon/widget khác của caller (vd `Stack(children: [Icon(...), Positioned(
/// top: -2, right: -2, child: BadgeDot())])`). Không tự định vị.
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

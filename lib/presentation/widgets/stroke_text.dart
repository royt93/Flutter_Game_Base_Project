import 'package:flutter/material.dart';

import '../../core/neon_theme.dart';

/// Chữ có viền (stroke) — dễ đọc trên nền candy nhiều màu. Vẽ 1 lớp stroke phía
/// sau + 1 lớp fill phía trước (kỹ thuật outline chuẩn cho casual game).
class StrokeText extends StatelessWidget {
  const StrokeText(
    this.text, {
    super.key,
    required this.fontSize,
    this.color = Colors.white,
    this.stroke,
    this.strokeWidth = 3.5,
    this.weight = FontWeight.w900,
    this.letterSpacing = 0.5,
    this.shadows,
  });

  final String text;
  final double fontSize;
  final Color color;
  final Color? stroke;
  final double strokeWidth;
  final FontWeight weight;
  final double letterSpacing;
  final List<Shadow>? shadows;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: weight,
            letterSpacing: letterSpacing,
            shadows: shadows,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = stroke ?? NeonTheme.ink,
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: weight,
            letterSpacing: letterSpacing,
            color: color,
          ),
        ),
      ],
    );
  }
}

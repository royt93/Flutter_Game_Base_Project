import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Ring-shaped progress indicator (custom-painted, not the default
/// CircularProgressIndicator) — used for a countdown timer / daily quest
/// ring, with a label/icon centered inside it. Animates the arc when
/// [progress] changes via TweenAnimationBuilder.
class CircularProgressRing extends StatelessWidget {
  const CircularProgressRing({
    super.key,
    required this.progress,
    this.size = 72,
    this.strokeWidth = 8,
    this.color,
    this.trackColor,
    this.icon,
    this.label,
  });

  /// 0.0-1.0.
  final double progress;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final IconData? icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final ringColor = color ?? NeonTheme.cyan;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, t, _) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(
          progress: t,
          color: ringColor,
          trackColor: trackColor ?? NeonTheme.cardAlt,
          strokeWidth: strokeWidth,
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: icon != null
                ? Icon(icon, color: ringColor, size: size * 0.36)
                : label != null
                ? Text(
                    label!,
                    style: TextStyle(
                      color: NeonTheme.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: size * 0.24,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

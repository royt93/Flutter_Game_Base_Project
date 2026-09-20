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
    this.child,
    this.semanticLabel,
  });

  /// 0.0-1.0.
  final double progress;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final IconData? icon;
  final String? label;

  /// Overrides the default "Progress: N%" Semantics label (ENH-59) — the
  /// ring itself is drawn entirely via [CustomPaint], so without this a
  /// screen reader gets nothing for it (a [label]/[icon]/[child] centered
  /// inside, if any, would still get its own automatic semantics, but that
  /// doesn't convey "this is a progress indicator" or its percentage).
  final String? semanticLabel;

  /// Arbitrary widget centered inside the ring — takes priority over [icon]
  /// and [label] when non-null (both are ignored), so existing call sites
  /// using [icon]/[label] keep working unchanged.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final ringColor = color ?? NeonTheme.cyan;
    final percent = (progress.clamp(0.0, 1.0) * 100).round();
    // Semantics wraps the animated builder (not built fresh inside it) so
    // the announced value is the settled target percentage, not every
    // transient in-between frame of the fill-in animation. excludeSemantics
    // suppresses whatever automatic semantics `label`/`icon`/`child` would
    // otherwise add on their own (e.g. a `label` Text repeating the same
    // percentage) so a screen reader hears this node's value exactly once.
    return Semantics(
      label: semanticLabel ?? 'Progress: $percent%',
      value: '$percent%',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: NeonTheme.reducedMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 400),
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
              child:
                  child ??
                  (icon != null
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
                      : null),
            ),
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
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = 2 * pi * progress;

    // Candy-kit glow, same "wider blurred stroke behind the crisp one"
    // technique used everywhere else in the kit via NeonTheme.glow — done
    // by hand here (rather than a BoxShadow) since this is a CustomPainter
    // arc, not a Container.
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 1.8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(rect, -pi / 2, sweep, false, glowPaint);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -pi / 2, sweep, false, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

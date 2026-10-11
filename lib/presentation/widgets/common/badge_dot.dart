import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Small round dot signaling "something's new"/"unclaimed reward" — placed
/// inside a [Stack] wrapping the caller's own icon/widget. Does not position
/// itself. Animation is opt-in through [pulse] and [radar].
class BadgeDot extends StatefulWidget {
  const BadgeDot({
    super.key,
    this.size = 10,
    this.color,
    this.pulse = false,
    this.radar = false,
  });

  final double size;
  final Color? color;
  final bool pulse;
  final bool radar;

  @override
  State<BadgeDot> createState() => _BadgeDotState();
}

class _BadgeDotState extends State<BadgeDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reducedMotion = false;

  bool get _animated => (widget.pulse || widget.radar) && !_reducedMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasReduced = _reducedMotion;
    _reducedMotion = NeonTheme.reducedMotion(context);
    if (_animated && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!_animated && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    } else if (wasReduced != _reducedMotion && _reducedMotion) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant BadgeDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_animated && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!_animated && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? NeonTheme.red;
    final size = widget.size;
    Widget dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: NeonTheme.card, width: 1.5),
        boxShadow: NeonTheme.glow(color, blur: 6, spread: 0.3),
      ),
    );

    if (_animated) {
      dot = RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          child: dot,
          builder: (context, child) {
            final t = _controller.value;
            final scaled = Transform.scale(
              scale: widget.pulse ? 1 + 0.25 * (1 - (2 * t - 1).abs()) : 1,
              child: child,
            );
            if (!widget.radar) return scaled;
            return SizedBox.square(
              dimension: size * 2.5,
              child: CustomPaint(
                key: const ValueKey('badgeRadarPainter'),
                painter: _RadarPainter(
                  progress: t,
                  color: color,
                  dotSize: size,
                ),
                child: Center(child: scaled),
              ),
            );
          },
        ),
      );
    }

    return ExcludeSemantics(child: dot);
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.progress,
    required this.color,
    required this.dotSize,
  });

  final double progress;
  final Color color;
  final double dotSize;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, dotSize * 0.12);
    for (var ring = 0; ring < 3; ring++) {
      final phase = (progress + ring / 3) % 1;
      paint.color = color.withValues(alpha: (1 - phase) * 0.45);
      canvas.drawCircle(
        center,
        dotSize * 0.65 + (maxRadius - dotSize * 0.65) * phase,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.dotSize != dotSize;
}

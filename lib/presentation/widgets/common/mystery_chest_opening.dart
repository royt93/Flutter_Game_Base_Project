import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

enum MysteryChestPhase { idle, shaking, opened, revealed }

MysteryChestPhase mysteryChestPhaseAt(double progress) {
  final value = progress.clamp(0.0, 1.0);
  if (value <= 0) return MysteryChestPhase.idle;
  if (value < 0.42) return MysteryChestPhase.shaking;
  if (value < 0.72) return MysteryChestPhase.opened;
  return MysteryChestPhase.revealed;
}

class MysteryChestOpening extends StatefulWidget {
  const MysteryChestOpening({
    super.key,
    this.reward,
    this.onRevealed,
    this.semanticLabel = 'Open treasure chest',
    this.size = const Size(240, 220),
    this.duration = const Duration(milliseconds: 1500),
    this.rayColor,
  });

  final Widget? reward;
  final VoidCallback? onRevealed;
  final String semanticLabel;
  final Size size;
  final Duration duration;
  final Color? rayColor;

  @override
  State<MysteryChestOpening> createState() => MysteryChestOpeningState();
}

class MysteryChestOpeningState extends State<MysteryChestOpening>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reducedMotion = false;
  bool _didNotify = false;

  MysteryChestPhase get phase => mysteryChestPhaseAt(_controller.value);
  double get animationProgress => _controller.value;
  bool get isAnimating => _controller.isAnimating;

  @override
  void initState() {
    super.initState();
    if (widget.duration <= Duration.zero) {
      throw ArgumentError.value(
        widget.duration,
        'duration',
        'must be positive',
      );
    }
    if (widget.size.width <= 0 ||
        widget.size.height <= 0 ||
        !widget.size.width.isFinite ||
        !widget.size.height.isFinite) {
      throw ArgumentError.value(
        widget.size,
        'size',
        'must be finite and positive',
      );
    }
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = NeonTheme.reducedMotion(context);
    if (reduced && !_reducedMotion && _controller.isAnimating) {
      _controller.value = 1;
      _notifyRevealed();
    }
    _reducedMotion = reduced;
  }

  @override
  void didUpdateWidget(covariant MysteryChestOpening oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration <= Duration.zero) {
      throw ArgumentError.value(
        widget.duration,
        'duration',
        'must be positive',
      );
    }
    if (widget.size.width <= 0 ||
        widget.size.height <= 0 ||
        !widget.size.width.isFinite ||
        !widget.size.height.isFinite) {
      throw ArgumentError.value(
        widget.size,
        'size',
        'must be finite and positive',
      );
    }
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  void _open() {
    if (phase != MysteryChestPhase.idle) return;
    _didNotify = false;
    if (_reducedMotion) {
      _controller.value = 1;
      _notifyRevealed();
    } else {
      _controller.forward(from: 0);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _notifyRevealed();
  }

  void _notifyRevealed() {
    if (_didNotify || !mounted) return;
    _didNotify = true;
    widget.onRevealed?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rays = widget.rayColor ?? NeonTheme.gold;
    return Semantics(
      button: phase == MysteryChestPhase.idle,
      label: widget.semanticLabel,
      value: phase.name,
      onTap: phase == MysteryChestPhase.idle ? _open : null,
      child: GestureDetector(
        onTap: _open,
        child: SizedBox.fromSize(
          size: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final progress = _controller.value;
              final currentPhase = mysteryChestPhaseAt(progress);
              final openedProgress = ((progress - 0.42) / 0.30).clamp(0.0, 1.0);
              final shake = currentPhase == MysteryChestPhase.shaking
                  ? math.sin(progress * math.pi * 48) *
                        5 *
                        (1 - progress / 0.42)
                  : 0.0;
              final showRays =
                  currentPhase.index >= MysteryChestPhase.opened.index &&
                  !_reducedMotion;
              final rewardOpacity = ((progress - 0.72) / 0.16).clamp(0.0, 1.0);

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (showRays)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: SunburstGodRays(
                              animation: _controller,
                              color: rays,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Align(
                    alignment: const Alignment(0, -0.1),
                    child: Transform.translate(
                      offset: Offset(shake, 0),
                      child: SizedBox(
                        width: widget.size.width * 0.72,
                        height: widget.size.height * 0.62,
                        child: CustomPaint(
                          painter: _ChestPainter(openedProgress),
                        ),
                      ),
                    ),
                  ),
                  if (widget.reward != null && rewardOpacity > 0)
                    PositionedDirectional(
                      bottom: 0,
                      start: 0,
                      end: 0,
                      child: IgnorePointer(
                        ignoring: rewardOpacity < 1,
                        child: Opacity(
                          opacity: rewardOpacity,
                          child: widget.reward,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class SunburstGodRays extends CustomPainter {
  SunburstGodRays({required this.animation, required this.color})
    : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final Paint _paint = Paint()..style = PaintingStyle.fill;
  final Path _ray = Path();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;
    final innerRadius = outerRadius * 0.22;
    final rotation = animation.value * math.pi * 2;
    for (var i = 0; i < 16; i++) {
      final angle = rotation + i * math.pi / 8;
      final spread = i.isEven ? 0.095 : 0.055;
      final tip = Offset(
        center.dx + math.cos(angle) * outerRadius,
        center.dy + math.sin(angle) * outerRadius,
      );
      final left = Offset(
        center.dx + math.cos(angle - spread) * innerRadius,
        center.dy + math.sin(angle - spread) * innerRadius,
      );
      final right = Offset(
        center.dx + math.cos(angle + spread) * innerRadius,
        center.dy + math.sin(angle + spread) * innerRadius,
      );
      _ray
        ..reset()
        ..moveTo(left.dx, left.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(right.dx, right.dy)
        ..close();
      _paint.color = color.withValues(alpha: i.isEven ? 0.22 : 0.12);
      canvas.drawPath(_ray, _paint);
    }
  }

  @override
  bool shouldRepaint(covariant SunburstGodRays oldDelegate) =>
      oldDelegate.animation != animation || oldDelegate.color != color;
}

class _ChestPainter extends CustomPainter {
  _ChestPainter(this.openProgress);

  final double openProgress;
  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.38,
        size.width * 0.84,
        size.height * 0.54,
      ),
      const Radius.circular(14),
    );
    _paint.color = const Color(0xFF9A4D16);
    canvas.drawRRect(body.shift(const Offset(0, 7)), _paint);
    _paint.color = const Color(0xFFD78224);
    canvas.drawRRect(body, _paint);
    _paint.color = const Color(0xFFFFC928);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.43,
        size.height * 0.4,
        size.width * 0.14,
        size.height * 0.52,
      ),
      _paint,
    );

    final pivot = Offset(size.width / 2, size.height * 0.4);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(-1.25 * openProgress);
    _paint.color = const Color(0xFFFFC928);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          -size.width * 0.45,
          -size.height * 0.28,
          size.width * 0.9,
          size.height * 0.26,
        ),
        const Radius.circular(12),
      ),
      _paint,
    );
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0xFF9A4D16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          -size.width * 0.45,
          -size.height * 0.28,
          size.width * 0.9,
          size.height * 0.26,
        ),
        const Radius.circular(12),
      ),
      _paint,
    );
    _paint.style = PaintingStyle.fill;
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChestPainter oldDelegate) =>
      oldDelegate.openProgress != openProgress;
}

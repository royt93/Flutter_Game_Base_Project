import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../stroke_text.dart';

double goldenShimmerOffsetAt(double progress) =>
    -1 + 3 * progress.clamp(0.0, 1.0);

/// Golden highlight sweep over [StrokeText]. Honors Reduced Motion and
/// inherited [TickerMode] so scrolling/offstage routes can pause the ticker.
class GoldenShimmerText extends StatefulWidget {
  const GoldenShimmerText(
    this.text, {
    super.key,
    required this.fontSize,
    this.color = const Color(0xFFFFC928),
    this.stroke,
    this.strokeWidth = 3.5,
    this.weight = FontWeight.w900,
    this.letterSpacing = 0.5,
    this.shadows,
    this.shimmerColor = Colors.white,
    this.duration = const Duration(milliseconds: 1500),
    this.animated = true,
  });

  final String text;
  final double fontSize;
  final Color color;
  final Color? stroke;
  final double strokeWidth;
  final FontWeight weight;
  final double letterSpacing;
  final List<Shadow>? shadows;
  final Color shimmerColor;
  final Duration duration;
  final bool animated;

  @override
  State<GoldenShimmerText> createState() => _GoldenShimmerTextState();
}

class _GoldenShimmerTextState extends State<GoldenShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _shouldAnimate = false;

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
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant GoldenShimmerText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration <= Duration.zero) {
      throw ArgumentError.value(
        widget.duration,
        'duration',
        'must be positive',
      );
    }
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    _syncTicker();
  }

  void _syncTicker() {
    final shouldAnimate =
        widget.animated &&
        TickerMode.valuesOf(context).enabled &&
        !NeonTheme.reducedMotion(context);
    if (shouldAnimate == _shouldAnimate) return;
    _shouldAnimate = shouldAnimate;
    if (shouldAnimate) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _text() => StrokeText(
    widget.text,
    fontSize: widget.fontSize,
    color: widget.color,
    stroke: widget.stroke,
    strokeWidth: widget.strokeWidth,
    weight: widget.weight,
    letterSpacing: widget.letterSpacing,
    shadows: widget.shadows,
  );

  @override
  Widget build(BuildContext context) {
    if (!_shouldAnimate) return _text();
    return Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final offset = goldenShimmerOffsetAt(_controller.value);
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment(offset, 0),
                end: Alignment(offset + 1, 0),
                colors: [
                  widget.color,
                  widget.color,
                  widget.shimmerColor,
                  widget.color,
                  widget.color,
                ],
                stops: const [0, 0.38, 0.5, 0.62, 1],
              ).createShader(bounds),
              child: child,
            );
          },
          child: _text(),
        ),
      ),
    );
  }
}

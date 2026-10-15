import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/neon_theme.dart';

@immutable
class FloatingEmojiParticle {
  const FloatingEmojiParticle({
    required this.emoji,
    required this.origin,
    required this.durationSeconds,
    required this.amplitude,
    required this.frequency,
    required this.phase,
  });

  final String emoji;
  final Offset origin;
  final double durationSeconds;
  final double amplitude;
  final double frequency;
  final double phase;
}

Offset floatingEmojiOffsetAt(
  FloatingEmojiParticle particle,
  Size bounds,
  double elapsedSeconds, {
  double riseDistance = 260,
}) {
  final progress = (elapsedSeconds / particle.durationSeconds).clamp(0.0, 1.0);
  return Offset(
    particle.origin.dx * bounds.width +
        sin(elapsedSeconds * particle.frequency + particle.phase) *
            particle.amplitude,
    particle.origin.dy * bounds.height -
        riseDistance * Curves.easeOut.transform(progress),
  );
}

double floatingEmojiOpacityAt(
  FloatingEmojiParticle particle,
  double elapsedSeconds,
) {
  if (particle.durationSeconds <= 0) return 0;
  final progress = (elapsedSeconds / particle.durationSeconds).clamp(0.0, 1.0);
  if (progress >= 1) return 0;
  if (progress <= 0.55) return 1;
  return (1 - (progress - 0.55) / 0.45).clamp(0.0, 1.0);
}

class FloatingEmojiBurst extends StatefulWidget {
  FloatingEmojiBurst({
    super.key,
    this.origin = const Offset(0.9, 0.9),
    this.duration = const Duration(milliseconds: 1800),
    this.riseDistance = 260,
    this.random,
    this.onFinished,
  }) {
    if (!_validOrigin(origin)) {
      throw ArgumentError.value(
        origin,
        'origin',
        'coordinates must be finite and between 0 and 1',
      );
    }
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'must be positive');
    }
    if (!riseDistance.isFinite || riseDistance <= 0) {
      throw ArgumentError.value(
        riseDistance,
        'riseDistance',
        'must be positive and finite',
      );
    }
  }

  static const maxConcurrent = 20;

  static bool _validOrigin(Offset origin) =>
      origin.dx.isFinite &&
      origin.dy.isFinite &&
      origin.dx >= 0 &&
      origin.dx <= 1 &&
      origin.dy >= 0 &&
      origin.dy <= 1;

  final Offset origin;
  final Duration duration;
  final double riseDistance;
  final Random? random;
  final VoidCallback? onFinished;

  @override
  State<FloatingEmojiBurst> createState() => FloatingEmojiBurstState();
}

class FloatingEmojiBurstState extends State<FloatingEmojiBurst>
    with SingleTickerProviderStateMixin {
  late final Random _random = widget.random ?? Random();
  late final Ticker _ticker;
  final List<_ActiveEmoji> _active = [];
  Duration _lastElapsed = Duration.zero;
  bool _skipPaint = false;
  bool _reducedMotion = false;
  int get activeCount => _active.length;
  bool get isAnimating => _ticker.isActive;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  void burst(String emoji, {Offset? origin}) {
    if (emoji.isEmpty) {
      throw ArgumentError.value(emoji, 'emoji', 'must not be empty');
    }
    if (_reducedMotion || _active.length >= FloatingEmojiBurst.maxConcurrent) {
      return;
    }
    final spawn = origin ?? widget.origin;
    if (!FloatingEmojiBurst._validOrigin(spawn)) {
      throw ArgumentError.value(
        spawn,
        'origin',
        'coordinates must be finite and between 0 and 1',
      );
    }
    _active.add(
      _ActiveEmoji(
        particle: FloatingEmojiParticle(
          emoji: emoji,
          origin: spawn,
          durationSeconds: widget.duration.inMicroseconds / 1e6,
          amplitude: 14 + _random.nextDouble() * 30,
          frequency: 3 + _random.nextDouble() * 4,
          phase: _random.nextDouble() * pi * 2,
        ),
      ),
    );
    if (!_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion = NeonTheme.reducedMotion(context);
    if (reducedMotion && !_reducedMotion) {
      _active.clear();
      _ticker.stop();
      _lastElapsed = Duration.zero;
    }
    _reducedMotion = reducedMotion;
  }

  void _tick(Duration elapsed) {
    final delta = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    for (final item in _active) {
      item.elapsedSeconds += delta;
    }
    _active.removeWhere(
      (item) => item.elapsedSeconds >= item.particle.durationSeconds,
    );
    if (_active.isEmpty) {
      _ticker.stop();
      _lastElapsed = Duration.zero;
      widget.onFinished?.call();
    }
    _skipPaint = !_skipPaint;
    if (!_skipPaint || _active.isEmpty) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _active.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var index = 0; index < _active.length; index++)
                  _buildEmoji(_active[index], constraints.biggest, index),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildEmoji(_ActiveEmoji active, Size bounds, int index) {
    final particle = active.particle;
    final position = floatingEmojiOffsetAt(
      particle,
      bounds,
      active.elapsedSeconds,
      riseDistance: widget.riseDistance,
    );
    return Positioned(
      key: ValueKey('floatingEmoji_$index'),
      left: position.dx - 16,
      top: position.dy - 16,
      child: Opacity(
        opacity: floatingEmojiOpacityAt(particle, active.elapsedSeconds),
        child: Text(particle.emoji, style: const TextStyle(fontSize: 32)),
      ),
    );
  }
}

class _ActiveEmoji {
  _ActiveEmoji({required this.particle});

  final FloatingEmojiParticle particle;
  double elapsedSeconds = 0;
}

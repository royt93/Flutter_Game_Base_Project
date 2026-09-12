import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/neon_theme.dart';

/// Confetti piece shape — mixed randomly so a burst isn't visually uniform.
enum ConfettiShape { rect, circle }

/// One confetti piece's fixed randomized traits, generated once at spawn.
/// Motion at any time [t] is a pure function of these traits (see
/// [confettiOffsetAt]/[confettiRotationAt]/[confettiOpacityAt]) so the
/// simulation is deterministic and unit-testable without building a widget.
@immutable
class ConfettiParticle {
  const ConfettiParticle({
    required this.startX,
    required this.fallSpeed,
    required this.size,
    required this.startRotation,
    required this.rotationSpeed,
    required this.swayAmplitude,
    required this.swayFrequency,
    required this.color,
    this.shape = ConfettiShape.rect,
  });

  /// Horizontal spawn position, 0.0 (left edge) - 1.0 (right edge).
  final double startX;

  /// Downward speed in logical px/sec.
  final double fallSpeed;
  final double size;

  /// Starting rotation in radians.
  final double startRotation;

  /// Spin speed in radians/sec.
  final double rotationSpeed;

  /// Side-to-side sway amplitude in logical px.
  final double swayAmplitude;

  /// Sway speed (radians/sec) fed into a sine wave.
  final double swayFrequency;
  final Color color;

  /// Rect or circle — mixed randomly per particle by
  /// [generateConfettiParticles] so a burst isn't visually uniform.
  final ConfettiShape shape;
}

/// Offset from its spawn point at [t] seconds since the burst started:
/// falls straight down at [ConfettiParticle.fallSpeed] while swaying
/// side-to-side on a sine wave. Pure function of `(particle, t)` — no
/// widget/render state involved, so it's unit-testable on its own.
Offset confettiOffsetAt(ConfettiParticle particle, double t) {
  final dx = sin(t * particle.swayFrequency) * particle.swayAmplitude;
  final dy = particle.fallSpeed * t;
  return Offset(dx, dy);
}

/// Rotation (radians) at [t] seconds since the burst started.
double confettiRotationAt(ConfettiParticle particle, double t) =>
    particle.startRotation + particle.rotationSpeed * t;

/// Opacity at [t] seconds into a [totalSeconds] effect: fully opaque until
/// 70% elapsed, then fades linearly to 0 so the burst doesn't cut off
/// abruptly. `totalSeconds <= 0` is treated as already-finished (0).
double confettiOpacityAt(double t, double totalSeconds) {
  if (totalSeconds <= 0) return 0;
  final frac = (t / totalSeconds).clamp(0.0, 1.0);
  if (frac < 0.7) return 1.0;
  return (1 - (frac - 0.7) / 0.3).clamp(0.0, 1.0);
}

/// Generates [count] particles with randomized traits drawn from [colors].
/// Pure aside from [random] (pass a seeded `Random` for deterministic
/// tests) — kept separate from the widget so "did we spawn the right
/// number of particles, with colors from the given palette" is a plain
/// unit test.
List<ConfettiParticle> generateConfettiParticles(
  int count,
  List<Color> colors, {
  Random? random,
}) {
  final rng = random ?? Random();
  return List.generate(count, (_) {
    return ConfettiParticle(
      startX: rng.nextDouble(),
      fallSpeed: 140 + rng.nextDouble() * 160,
      size: 6 + rng.nextDouble() * 6,
      startRotation: rng.nextDouble() * pi * 2,
      rotationSpeed: (rng.nextDouble() - 0.5) * 8,
      swayAmplitude: 16 + rng.nextDouble() * 28,
      swayFrequency: 1 + rng.nextDouble() * 2,
      color: colors[rng.nextInt(colors.length)],
      shape: rng.nextBool() ? ConfettiShape.rect : ConfettiShape.circle,
    );
  });
}

/// Full-screen confetti burst — N colored paper pieces rain down from the
/// top, sway, spin, and fade out; the effect stops and hides itself after
/// [duration] (unlike `NeonBg`/`AuroraBgLayer`, which run forever). Drop it
/// in a `Stack` over a win/level-complete screen; give it a fresh [key] each
/// time you want to retrigger it (a new key mounts a fresh particle set and
/// ticker instead of reusing a finished one).
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({
    super.key,
    this.particleCount = 60,
    this.duration = const Duration(milliseconds: 2200),
    this.colors,
    this.onFinished,
  });

  final int particleCount;
  final Duration duration;

  /// Defaults to [NeonTheme.gemColors] — nullable because `gemColors` is a
  /// getter (not a compile-time constant list) so it can't be a `const`
  /// constructor default value.
  final List<Color>? colors;

  /// Called once, right after [duration] elapses and the overlay hides
  /// itself — the usual place to `setState` the parent to unmount this
  /// widget.
  final VoidCallback? onFinished;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  late final List<ConfettiParticle> _particles;
  double _elapsedSeconds = 0;
  bool _finished = false;
  bool _startedOnce = false;
  // Repainting a full-screen particle field every frame is wasteful —
  // throttle actual repaints to ~30fps, same as AuroraBgLayer/NeonAuraLayer
  // (ShaderTickerLayerState); `_elapsedSeconds` still advances every tick
  // so the motion itself doesn't look throttled.
  bool _skipFrame = false;

  double get _totalSeconds => widget.duration.inMicroseconds / 1e6;

  @override
  void initState() {
    super.initState();
    _particles = generateConfettiParticles(
      widget.particleCount,
      widget.colors ?? NeonTheme.gemColors,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery can't be read in initState — didChangeDependencies is the
    // earliest safe place, and runs once before the first build. A burst of
    // N particles has no meaningful "static final frame" to fall back to
    // (unlike a progress bar or fade), so Reduce Motion skips the whole
    // effect: never start the ticker, call onFinished right away (deferred
    // to a post-frame callback so it isn't invoked mid-build).
    if (_startedOnce) return;
    _startedOnce = true;
    if (NeonTheme.reducedMotion(context)) {
      _finished = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished?.call();
      });
      return;
    }
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final seconds = elapsed.inMicroseconds / 1e6;
    if (seconds >= _totalSeconds) {
      _elapsedSeconds = _totalSeconds;
      _finished = true;
      _ticker?.stop();
      setState(() {});
      widget.onFinished?.call();
      return;
    }
    _elapsedSeconds = seconds;
    _skipFrame = !_skipFrame;
    if (_skipFrame) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ConfettiPainter(
            particles: _particles,
            elapsedSeconds: _elapsedSeconds,
            totalSeconds: _totalSeconds,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.particles,
    required this.elapsedSeconds,
    required this.totalSeconds,
  });

  final List<ConfettiParticle> particles;
  final double elapsedSeconds;
  final double totalSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = confettiOpacityAt(elapsedSeconds, totalSeconds);
    if (opacity <= 0) return;
    for (final p in particles) {
      final origin = Offset(p.startX * size.width, -p.size);
      final pos = origin + confettiOffsetAt(p, elapsedSeconds);
      if (pos.dy > size.height + p.size) continue; // đã rơi khỏi màn hình
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(confettiRotationAt(p, elapsedSeconds));
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      if (p.shape == ConfettiShape.circle) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          paint,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.6,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.elapsedSeconds != elapsedSeconds;
}

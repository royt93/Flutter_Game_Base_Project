import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/utils/object_pool.dart';

double pooledParticleOpacityAt(double progress) {
  final t = progress.clamp(0.0, 1.0);
  if (t < 0.7) return 1;
  return ((1 - t) / 0.3).clamp(0.0, 1.0);
}

Offset pooledParticleOffsetAt({
  required Offset center,
  required double angle,
  required double travelDistance,
  required double progress,
}) {
  final t = progress.clamp(0.0, 1.0);
  final eased = Curves.easeOut.transform(t);
  final distance = travelDistance * eased;
  return center +
      Offset(math.cos(angle) * distance, math.sin(angle) * distance);
}

class _BurstParticle {
  double angle = 0;
  double speed = 0;
  double size = 0;
  double rotation = 0;
  double spin = 0;
  Color color = Colors.white;
}

/// Reusable radial particle burst. Call [PooledParticleBurstState.burst] to
/// replay; the pool is prewarmed to [particleCount] so later bursts reuse every
/// particle object instead of allocating another batch.
class PooledParticleBurst extends StatefulWidget {
  const PooledParticleBurst({
    super.key,
    this.particleCount = 50,
    this.duration = const Duration(milliseconds: 1100),
    this.colors,
    this.randomSeed = 0,
    this.onBurstFinished,
  });

  final int particleCount;
  final Duration duration;
  final List<Color>? colors;
  final int randomSeed;
  final VoidCallback? onBurstFinished;

  @override
  State<PooledParticleBurst> createState() => PooledParticleBurstState();
}

class PooledParticleBurstState extends State<PooledParticleBurst>
    with SingleTickerProviderStateMixin {
  late final math.Random _random;
  late final ObjectPool<_BurstParticle> _pool;
  late final AnimationController _controller;
  final List<_BurstParticle> _active = [];
  bool _bursting = false;
  bool _reducedMotion = false;

  int get totalCreated => _pool.totalCreated;
  int get activeCount => _pool.activeCount;
  int get freeCount => _pool.freeCount;
  bool get isBursting => _bursting;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = NeonTheme.reducedMotion(context);
    if (reduced && _bursting) {
      _controller.stop();
      _releaseActive();
      _bursting = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
          widget.onBurstFinished?.call();
        }
      });
    }
    _reducedMotion = reduced;
  }

  @override
  void initState() {
    super.initState();
    if (widget.particleCount < 1 || widget.particleCount > 100) {
      throw ArgumentError.value(
        widget.particleCount,
        'particleCount',
        'must be between 1 and 100',
      );
    }
    if (widget.duration <= Duration.zero) {
      throw ArgumentError.value(
        widget.duration,
        'duration',
        'must be positive',
      );
    }
    _random = math.Random(widget.randomSeed);
    _pool = ObjectPool<_BurstParticle>(
      create: _BurstParticle.new,
      reset: (particle) {
        particle
          ..angle = 0
          ..speed = 0
          ..size = 0
          ..rotation = 0
          ..spin = 0
          ..color = Colors.white;
      },
      maxCapacity: widget.particleCount,
    )..prewarm(widget.particleCount);
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_finishIfDone);
  }

  void burst() {
    if (!mounted) return;
    if (_reducedMotion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onBurstFinished?.call();
      });
      return;
    }
    if (_bursting) _releaseActive();
    _active.clear();
    final colors = widget.colors ?? NeonTheme.gemColors;
    for (var i = 0; i < widget.particleCount; i++) {
      final particle = _pool.acquire()
        ..angle = _random.nextDouble() * math.pi * 2
        ..speed = 90 + _random.nextDouble() * 130
        ..size = 4 + _random.nextDouble() * 6
        ..rotation = _random.nextDouble() * math.pi * 2
        ..spin = (_random.nextDouble() - 0.5) * 8
        ..color = colors[_random.nextInt(colors.length)];
      _active.add(particle);
    }
    setState(() => _bursting = true);
    _controller.forward(from: 0);
  }

  void _finishIfDone(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_bursting || !mounted) return;
    _releaseActive();
    setState(() => _bursting = false);
    widget.onBurstFinished?.call();
  }

  void _releaseActive() {
    for (final particle in _active) {
      _pool.release(particle);
    }
    _active.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    _releaseActive();
    _pool.disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_bursting) return const SizedBox.expand();
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _PooledParticlePainter(
              particles: _active,
              progress: _controller,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _PooledParticlePainter extends CustomPainter {
  _PooledParticlePainter({required this.particles, required this.progress})
    : super(repaint: progress);

  final List<_BurstParticle> particles;
  final Animation<double> progress;
  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final center = size.center(Offset.zero);
    final opacity = pooledParticleOpacityAt(t);
    for (final particle in particles) {
      final point = pooledParticleOffsetAt(
        center: center,
        angle: particle.angle,
        travelDistance: particle.speed * (particle.size / 6 + 1),
        progress: t,
      );
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(particle.rotation + particle.spin * t);
      _paint.color = particle.color.withValues(alpha: opacity);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: particle.size,
          height: particle.size * 0.65,
        ),
        _paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PooledParticlePainter oldDelegate) =>
      !identical(oldDelegate.particles, particles);
}

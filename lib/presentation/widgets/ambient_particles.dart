import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/neon_theme.dart';
import '../../core/storage_service.dart';

/// X14: particle/ngôi sao trôi nhẹ phía sau mascot trên Home — mật độ thấp,
/// loop liên tục nhẹ (khác confetti là burst 1 lần). Gate reduce-motion qua
/// `StorageService.maybe` để an toàn khi render trong test độc lập chưa
/// đăng ký GetX service (cùng pattern X13).
class AmbientParticles extends StatefulWidget {
  const AmbientParticles({super.key, this.count = 7});

  final int count;

  @override
  State<AmbientParticles> createState() => _AmbientParticlesState();
}

class _AmbientParticlesState extends State<AmbientParticles>
    with SingleTickerProviderStateMixin {
  bool get _reduceMotion =>
      StorageService.maybe?.getBool(StorageKeys.reduceMotion) ?? false;

  AnimationController? _c;
  List<_Particle>? _particles;

  @override
  void initState() {
    super.initState();
    if (_reduceMotion) return;
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
    final rng = Random();
    _particles = List.generate(widget.count, (i) {
      return _Particle(
        x: rng.nextDouble(),
        yStart: rng.nextDouble(),
        drift: (rng.nextDouble() - 0.5) * 0.15,
        size: 4 + rng.nextDouble() * 6,
        speed: 0.4 + rng.nextDouble() * 0.6,
        phase: rng.nextDouble(),
        color: NeonTheme.gemColors[rng.nextInt(NeonTheme.gemColors.length)],
      );
    });
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion || _c == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _AmbientPainter(_c!, _particles!),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.x,
    required this.yStart,
    required this.drift,
    required this.size,
    required this.speed,
    required this.phase,
    required this.color,
  });

  final double x, yStart, drift, size, speed, phase;
  final Color color;
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.anim, this.particles) : super(repaint: anim);

  final Animation<double> anim;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    for (final p in particles) {
      // trôi lên đều đặn rồi lặp lại (wrap), nhấp nháy alpha nhẹ theo phase.
      final progress = (p.yStart - t * p.speed) % 1.0;
      final y = progress * size.height;
      final x = (p.x + sin((t + p.phase) * pi * 2) * p.drift) * size.width;
      final alpha = 0.25 + 0.35 * (sin((t + p.phase) * pi * 2) * 0.5 + 0.5);
      canvas.drawCircle(
        Offset(x, y),
        p.size,
        Paint()..color = p.color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) => false;
}

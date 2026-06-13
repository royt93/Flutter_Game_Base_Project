import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/neon_theme.dart';

/// Background neon ĐỘNG dùng chung cho mọi màn:
/// gradient nền + nebula trôi + sao lấp lánh + tia sweep xoay + vignette.
/// Hiệu năng tốt: dùng RadialGradient/shader, không MaskFilter.
class NeonBg extends StatefulWidget {
  final Widget child;
  const NeonBg({super.key, required this.child});

  @override
  State<NeonBg> createState() => _NeonBgState();
}

class _NeonBgState extends State<NeonBg> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rnd = math.Random(7);
  late final List<_Orb> _orbs;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 24))
      ..repeat();
    _orbs = List.generate(6, (i) {
      return _Orb(
        base: Offset(_rnd.nextDouble(), _rnd.nextDouble()),
        amp: Offset(0.12 + _rnd.nextDouble() * 0.16,
            0.12 + _rnd.nextDouble() * 0.16),
        phase: _rnd.nextDouble() * math.pi * 2,
        radius: 0.28 + _rnd.nextDouble() * 0.28,
        color: NeonTheme.gemColors[i % NeonTheme.gemColors.length],
      );
    });
    _stars = List.generate(60, (i) {
      return _Star(
        pos: Offset(_rnd.nextDouble(), _rnd.nextDouble()),
        phase: _rnd.nextDouble() * math.pi * 2,
        freq: 1 + _rnd.nextDouble() * 3,
        size: 0.6 + _rnd.nextDouble() * 1.8,
        sparkle: i % 6 == 0,
        color: NeonTheme.gemColors[_rnd.nextInt(NeonTheme.gemColors.length)],
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => CustomPaint(
                painter: _NeonBgPainter(_ctrl.value, _orbs, _stars),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Orb {
  final Offset base; // 0..1
  final Offset amp;
  final double phase;
  final double radius; // theo chiều rộng
  final Color color;
  _Orb({
    required this.base,
    required this.amp,
    required this.phase,
    required this.radius,
    required this.color,
  });
}

class _Star {
  final Offset pos;
  final double phase;
  final double freq;
  final double size;
  final bool sparkle;
  final Color color;
  _Star({
    required this.pos,
    required this.phase,
    required this.freq,
    required this.size,
    required this.sparkle,
    required this.color,
  });
}

class _NeonBgPainter extends CustomPainter {
  final double t; // 0..1
  final List<_Orb> orbs;
  final List<_Star> stars;
  _NeonBgPainter(this.t, this.orbs, this.stars);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final tau = t * math.pi * 2;

    // 1) Nền gradient
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0A1A), Color(0xFF14122E), Color(0xFF1A0A2E)],
        ).createShader(rect),
    );

    // 2) Tia sweep xoay (conic) tạo cảm giác sống động
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.4);
    canvas.rotate(tau);
    final sweepRect = Rect.fromCircle(
        center: Offset.zero, radius: size.longestSide);
    canvas.drawRect(
      sweepRect,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = SweepGradient(
          colors: [
            NeonTheme.cyan.withValues(alpha: 0.05),
            Colors.transparent,
            NeonTheme.magenta.withValues(alpha: 0.05),
            Colors.transparent,
            NeonTheme.cyan.withValues(alpha: 0.05),
          ],
        ).createShader(sweepRect),
    );
    canvas.restore();

    // 3) Nebula trôi
    for (final o in orbs) {
      final cx = (o.base.dx + o.amp.dx * math.sin(tau + o.phase)) * size.width;
      final cy = (o.base.dy + o.amp.dy * math.cos(tau + o.phase)) * size.height;
      final r = o.radius * size.width;
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [o.color.withValues(alpha: 0.18), o.color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
      );
    }

    // 4) Sao lấp lánh
    for (final s in stars) {
      final tw = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(tau * s.freq + s.phase));
      final p = Offset(s.pos.dx * size.width, s.pos.dy * size.height);
      if (s.sparkle) {
        final paint = Paint()
          ..color = s.color.withValues(alpha: 0.85 * tw)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
        final r = s.size * 2.2 * (0.6 + 0.4 * tw);
        canvas.drawLine(p - Offset(r, 0), p + Offset(r, 0), paint);
        canvas.drawLine(p - Offset(0, r), p + Offset(0, r), paint);
        canvas.drawCircle(p, 1.3, Paint()..color = Colors.white.withValues(alpha: tw));
      } else {
        canvas.drawCircle(
            p, s.size, Paint()..color = Colors.white.withValues(alpha: 0.5 * tw));
      }
    }

    // 5) Vignette
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.1,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
          stops: const [0.6, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _NeonBgPainter old) => old.t != t;
}

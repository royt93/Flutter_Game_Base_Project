import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/neon_theme.dart';

/// Background neon ĐỘNG dùng chung cho mọi màn:
/// gradient nền + nebula trôi + sao lấp lánh + tia sweep xoay + vignette.
/// Hiệu năng tốt: dùng RadialGradient/shader, không MaskFilter.
class NeonBg extends StatefulWidget {
  final Widget child;

  /// Màu chủ đạo theo thế giới. Null = palette neon mặc định (đa sắc).
  /// Khi có giá trị: tia sweep + nebula nghiêng về tông màu này → mỗi world
  /// một sắc thái riêng (cyan → magenta → lime → ...).
  final Color? accent;
  const NeonBg({super.key, required this.child, this.accent});

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
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
    _orbs = List.generate(6, (i) {
      return _Orb(
        base: Offset(_rnd.nextDouble(), _rnd.nextDouble()),
        amp: Offset(
          0.12 + _rnd.nextDouble() * 0.16,
          0.12 + _rnd.nextDouble() * 0.16,
        ),
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
              builder: (_, _) => CustomPaint(
                painter: _NeonBgPainter(
                  _ctrl.value,
                  _orbs,
                  _stars,
                  widget.accent,
                ),
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
  final Color? accent;
  _NeonBgPainter(this.t, this.orbs, this.stars, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final tau = t * math.pi * 2;

    // 1) Nền gradient candy sáng
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [NeonTheme.bgTop, NeonTheme.bgMid, NeonTheme.bgBot],
        ).createShader(rect),
    );

    // 2) Bong bóng kẹo trôi mềm (soft-light để hoà vào nền sáng, không cháy).
    for (final o in orbs) {
      final cx = (o.base.dx + o.amp.dx * math.sin(tau + o.phase)) * size.width;
      final cy = (o.base.dy + o.amp.dy * math.cos(tau + o.phase)) * size.height;
      final r = o.radius * size.width;
      final oc = accent != null ? Color.lerp(o.color, accent!, 0.5)! : o.color;
      final soft = Color.lerp(oc, Colors.white, 0.55)!;
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..blendMode = BlendMode.softLight
          ..shader = RadialGradient(
            colors: [soft.withValues(alpha: 0.9), soft.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
      );
    }

    // 3) Lấp lánh nhẹ (trắng/vàng) rải rác cho vui mắt.
    for (final s in stars) {
      final tw = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(tau * s.freq + s.phase));
      final p = Offset(s.pos.dx * size.width, s.pos.dy * size.height);
      if (s.sparkle) {
        final paint = Paint()
          ..color = Colors.white.withValues(alpha: 0.9 * tw)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
        final r = s.size * 2.2 * (0.6 + 0.4 * tw);
        canvas.drawLine(p - Offset(r, 0), p + Offset(r, 0), paint);
        canvas.drawLine(p - Offset(0, r), p + Offset(0, r), paint);
      } else {
        canvas.drawCircle(
          p,
          s.size,
          Paint()..color = Colors.white.withValues(alpha: 0.45 * tw),
        );
      }
    }

    // 4) Ánh sáng dịu ở đỉnh (sheen) — tăng cảm giác tươi sáng.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Colors.white.withValues(alpha: 0.25), Colors.transparent],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _NeonBgPainter old) =>
      old.t != t || old.accent != accent;
}

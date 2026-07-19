import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/neon_theme.dart';
import '../../data/worlds.dart';
import 'ambient_weather_layer.dart';
import 'aurora_bg_layer.dart';

/// Background neon ĐỘNG dùng chung cho mọi màn:
/// gradient nền + nebula trôi + sao lấp lánh + tia sweep xoay + vignette.
/// Hiệu năng tốt: dùng RadialGradient/shader, không MaskFilter.
class NeonBg extends StatefulWidget {
  final Widget child;

  /// Màu chủ đạo theo thế giới. Null = palette neon mặc định (đa sắc).
  /// Khi có giá trị: tia sweep + nebula nghiêng về tông màu này → mỗi world
  /// một sắc thái riêng (cyan → magenta → lime → ...).
  final Color? accent;

  /// G4: lấy mức "energy" combo hiện tại (0..1) mỗi frame, vd `() => game.heat`.
  /// Null = nền tĩnh mặc định (màn không có combo, vd Home).
  final double Function()? energyOf;

  /// I16: phủ thêm dải aurora chuyển sắc lên trên nền — chỉ world cuối.
  final bool aurora;

  /// I40: lớp particle thời tiết theo world (tuyết/tia lửa/bong bóng).
  /// `none` = không vẽ gì thêm.
  final WeatherKind weather;

  const NeonBg({
    super.key,
    required this.child,
    this.accent,
    this.energyOf,
    this.aurora = false,
    this.weather = WeatherKind.none,
  });

  @override
  State<NeonBg> createState() => _NeonBgState();
}

class _NeonBgState extends State<NeonBg> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;
  // P1: vẽ 6 orb (RadialGradient + softLight, đắt) + 60 star mỗi frame —
  // hạ tần suất repaint thật xuống ~30fps giống NeonAuraLayer (#10), _t/_energy
  // vẫn cập nhật mỗi tick nên chuyển động không bị giật.
  bool _skipFrame = false;
  final _rnd = math.Random(7);
  late final List<_Orb> _orbs;
  late final List<_Star> _stars;
  double _energy = 0; // G4: mượt hoá combo heat, lerp mỗi frame (~60fps)

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
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

  void _onTick(Duration elapsed) {
    _t = (elapsed.inMicroseconds / 1e6 / 24) % 1.0;
    final target = (widget.energyOf?.call() ?? 0).clamp(0.0, 1.0);
    _energy += (target - _energy) * 0.08;
    _skipFrame = !_skipFrame;
    if (_skipFrame && mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _NeonBgPainter(
                _t,
                _orbs,
                _stars,
                widget.accent,
                _energy,
              ),
            ),
          ),
        ),
        if (widget.aurora)
          Positioned.fill(
            child: AuroraBgLayer(
              color: (widget.accent ?? NeonTheme.indigo).withValues(alpha: 0.5),
            ),
          ),
        if (widget.weather != WeatherKind.none)
          Positioned.fill(child: AmbientWeatherLayer(weather: widget.weather)),
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
  final double energy; // G4: 0..1, combo heat mượt hoá
  _NeonBgPainter(this.t, this.orbs, this.stars, this.accent, this.energy);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final tau = t * math.pi * 2;
    // G4: energy cao → orb trôi nhanh hơn (biên độ nhỏ để tránh chói/khó đọc).
    final orbTau = tau * (1 + energy * 0.7);

    // 1) Nền gradient candy sáng
    canvas.drawRect(
      rect,
      Paint()..shader = NeonTheme.bgGradient.createShader(rect),
    );

    // 2) Bong bóng kẹo trôi mềm (soft-light để hoà vào nền sáng, không cháy).
    for (final o in orbs) {
      final cx =
          (o.base.dx + o.amp.dx * math.sin(orbTau + o.phase)) * size.width;
      final cy =
          (o.base.dy + o.amp.dy * math.cos(orbTau + o.phase)) * size.height;
      final r = o.radius * size.width;
      final oc = accent != null ? Color.lerp(o.color, accent!, 0.5)! : o.color;
      final warm = Color.lerp(oc, NeonTheme.orange, energy * 0.5)!;
      final soft = Color.lerp(warm, Colors.white, 0.55)!;
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..blendMode = BlendMode.softLight
          ..shader = RadialGradient(
            colors: [
              soft.withValues(alpha: 0.9 + 0.1 * energy),
              soft.withValues(alpha: 0),
            ],
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
      old.t != t || old.accent != accent || old.energy != energy;
}

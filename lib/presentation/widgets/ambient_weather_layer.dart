import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/neon_theme.dart';
import '../../core/storage_service.dart';
import '../../data/worlds.dart';

/// I40: lớp particle thời tiết nhẹ phía sau board (không che gameplay), khác
/// nhau theo [WeatherKind] của world hiện tại — tuyết rơi xuống (world băng),
/// tia lửa bay lên (world lửa), bong bóng nổi lên (world nước). `none` (world
/// mặc định + world cuối, tránh chồng lên aurora I16) không vẽ gì.
class AmbientWeatherLayer extends StatefulWidget {
  const AmbientWeatherLayer({
    super.key,
    required this.weather,
    this.count = 22,
  });

  final WeatherKind weather;
  final int count;

  @override
  State<AmbientWeatherLayer> createState() => _AmbientWeatherLayerState();
}

class _AmbientWeatherLayerState extends State<AmbientWeatherLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  bool get _reduceMotion =>
      StorageService.maybe?.getBool(StorageKeys.reduceMotion) ?? false;

  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _particles = List.generate(widget.count, (i) {
      return _Particle(
        x: rng.nextDouble(),
        phase: rng.nextDouble(),
        speed: 0.5 + rng.nextDouble() * 0.7,
        drift: (rng.nextDouble() - 0.5) * 0.5,
        size: 3 + rng.nextDouble() * 5,
      );
    });
    if (!_reduceMotion) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.weather == WeatherKind.none) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return CustomPaint(
              painter: _WeatherPainter(
                kind: widget.weather,
                particles: _particles,
                t: _c.value,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _Particle {
  final double x; // 0..1 vị trí ngang cơ bản
  final double phase; // 0..1 lệch pha dọc theo hành trình
  final double speed;
  final double drift; // biên độ lắc ngang
  final double size;
  _Particle({
    required this.x,
    required this.phase,
    required this.speed,
    required this.drift,
    required this.size,
  });
}

class _WeatherPainter extends CustomPainter {
  _WeatherPainter({
    required this.kind,
    required this.particles,
    required this.t,
  });

  final WeatherKind kind;
  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Tuyết rơi xuống; tia lửa/bong bóng bay/nổi lên (hướng ngược).
    final upward = kind != WeatherKind.snow;
    final color = switch (kind) {
      WeatherKind.snow => Colors.white,
      WeatherKind.spark => NeonTheme.orange,
      WeatherKind.bubble => NeonTheme.cyan,
      WeatherKind.none => Colors.transparent,
    };

    for (final p in particles) {
      final travel = (p.phase + t * p.speed) % 1.0;
      final dy = upward ? (1 - travel) : travel;
      final wobble = sin((travel + p.phase) * pi * 4) * p.drift;
      final dx = ((p.x + wobble) % 1.0 + 1.0) % 1.0;
      final center = Offset(dx * size.width, dy * size.height);
      // mờ dần ở 2 đầu hành trình để không "xuất hiện/biến mất" đột ngột.
      final edge = min(travel, 1 - travel);
      final alpha = (edge / 0.15).clamp(0.0, 1.0) * 0.6;
      if (alpha <= 0) continue;

      switch (kind) {
        case WeatherKind.bubble:
          canvas.drawCircle(
            center,
            p.size,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = color.withValues(alpha: alpha),
          );
        case WeatherKind.snow:
        case WeatherKind.spark:
        case WeatherKind.none:
          canvas.drawCircle(
            center,
            p.size * (kind == WeatherKind.spark ? 0.6 : 1.0),
            Paint()..color = color.withValues(alpha: alpha),
          );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter old) =>
      old.t != t || old.kind != kind;
}

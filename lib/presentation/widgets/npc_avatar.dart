import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/neon_theme.dart';

/// Avatar nhân vật (vệ thần neon) vẽ bằng code — mỗi thế giới 1 motif riêng,
/// tô theo màu chủ đạo của thế giới. Không cần asset.
class NpcAvatar extends StatelessWidget {
  final int world; // 1..5
  final double size;
  const NpcAvatar({super.key, required this.world, this.size = 84});

  @override
  Widget build(BuildContext context) {
    final color = NeonTheme.accentForWorld(world);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _NpcPainter(world, color)),
    );
  }
}

class _NpcPainter extends CustomPainter {
  final int world;
  final Color color;
  _NpcPainter(this.world, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // Quầng sáng nền
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.5), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Lõi tròn (thân vệ thần)
    final core = r * 0.62;
    canvas.drawCircle(
      c,
      core,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, color],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: core)),
    );
    canvas.drawCircle(
      c,
      core,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = Colors.white.withValues(alpha: 0.9),
    );

    final glow = Paint()
      ..color = Colors.white
      ..blendMode = BlendMode.plus;
    final motif = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    switch (world) {
      case 1: // Luma — tia sáng toả
        for (int i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          final p1 = c + Offset(math.cos(a), math.sin(a)) * core * 0.5;
          final p2 = c + Offset(math.cos(a), math.sin(a)) * (r * 0.92);
          canvas.drawLine(p1, p2, motif);
        }
        canvas.drawCircle(c, core * 0.3, glow);
        break;
      case 2: // Vera — nhịp đập (sóng tim)
        final path = Path();
        final w = core * 1.4;
        path.moveTo(c.dx - w, c.dy);
        path.lineTo(c.dx - w * 0.4, c.dy);
        path.lineTo(c.dx - w * 0.2, c.dy - core * 0.7);
        path.lineTo(c.dx, c.dy + core * 0.7);
        path.lineTo(c.dx + w * 0.2, c.dy - core * 0.4);
        path.lineTo(c.dx + w * 0.4, c.dy);
        path.lineTo(c.dx + w, c.dy);
        canvas.drawPath(path, motif..color = Colors.white);
        break;
      case 3: // Cir — mạch điện (node + nối)
        final nodes = [
          c + Offset(-core * 0.6, -core * 0.5),
          c + Offset(core * 0.6, -core * 0.2),
          c + Offset(-core * 0.2, core * 0.6),
          c + Offset(core * 0.5, core * 0.5),
        ];
        for (int i = 0; i < nodes.length - 1; i++) {
          canvas.drawLine(nodes[i], nodes[i + 1], motif..color = Colors.white);
        }
        for (final n in nodes) {
          canvas.drawCircle(n, 4.5, Paint()..color = Colors.white);
          canvas.drawCircle(n, 4.5, motif..color = color);
        }
        break;
      case 4: // Ember — sao chổi (đầu + đuôi)
        final head = c + Offset(core * 0.45, -core * 0.45);
        canvas.drawCircle(head, core * 0.34, Paint()..color = Colors.white);
        final tail = Path()
          ..moveTo(head.dx, head.dy)
          ..lineTo(c.dx - core, c.dy + core * 0.9)
          ..lineTo(c.dx - core * 0.4, c.dy + core * 0.3)
          ..close();
        canvas.drawPath(
            tail,
            Paint()
              ..shader = LinearGradient(
                colors: [Colors.white, color.withValues(alpha: 0)],
              ).createShader(Rect.fromCircle(center: c, radius: core)));
        break;
      case 5: // Nyx — hư không (trăng khuyết)
        final moon = Path()
          ..addOval(Rect.fromCircle(center: c, radius: core * 0.8));
        final cut = Path()
          ..addOval(Rect.fromCircle(
              center: c + Offset(core * 0.45, -core * 0.1), radius: core * 0.7));
        canvas.drawPath(
          Path.combine(PathOperation.difference, moon, cut),
          Paint()..color = Colors.white,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _NpcPainter old) =>
      old.world != world || old.color != color;
}

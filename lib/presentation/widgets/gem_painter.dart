import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/neon_theme.dart';
import '../../logic/gem_data.dart';

/// Vẽ gem TĨNH (Canvas thuần) DÙNG CHUNG cho các bàn widget (vd Versus) —
/// cùng bộ HÌNH LÁ BÀI + viền neon đôi như game chính (`gem_component.dart`),
/// để bàn 2 người không bị "kì quặc" so với game chính.
///
/// 0 cyan=tròn ●, 1 magenta=cơ ♥, 2 lime=chuồn ♣,
/// 3 yellow=sao ★, 4 orange=rô ♦, 5 purple=bích ♠.
void paintGem(
  Canvas canvas, {
  required GemColor color,
  required GemType type,
  required Offset center,
  required double cell,
}) {
  final c = NeonTheme.gemColors[color.index];
  final s = cell;
  final r = s * 0.40;
  final path = _shapePath(color.index, center, r);
  final bounds = path.getBounds();

  // glow mềm phía sau
  canvas.drawPath(
    path,
    Paint()
      ..color = (type == GemType.rainbow ? Colors.white : c)
          .withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
  );

  // thân gradient sáng giữa
  final light = Color.lerp(c, Colors.white, 0.6)!;
  final dark = Color.lerp(c, Colors.black, 0.35)!;
  canvas.drawPath(
    path,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 0.95,
        colors: [light, c, dark],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(bounds),
  );

  // viền neon đôi
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.09
      ..strokeJoin = StrokeJoin.round
      ..color = c.withValues(alpha: 0.6),
  );
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.95),
  );

  // đốm highlight
  canvas.drawCircle(
    Offset(center.dx - r * 0.32, center.dy - r * 0.34),
    s * 0.06,
    Paint()..color = Colors.white.withValues(alpha: 0.85),
  );

  if (type != GemType.normal) _paintSpecial(canvas, s, center, c, type);
}

void _paintSpecial(
    Canvas canvas, double s, Offset center, Color c, GemType type) {
  void neonBar(Offset a, Offset b) {
    canvas.drawLine(
        a,
        b,
        Paint()
          ..color = c
          ..strokeWidth = s * 0.15
          ..strokeCap = StrokeCap.round);
    canvas.drawLine(
        a,
        b,
        Paint()
          ..color = Colors.white
          ..strokeWidth = s * 0.06
          ..strokeCap = StrokeCap.round);
  }

  switch (type) {
    case GemType.stripedH:
      for (final fy in [-0.2, 0.2]) {
        neonBar(Offset(center.dx - s * 0.34, center.dy + s * fy),
            Offset(center.dx + s * 0.34, center.dy + s * fy));
      }
      break;
    case GemType.stripedV:
      for (final fx in [-0.2, 0.2]) {
        neonBar(Offset(center.dx + s * fx, center.dy - s * 0.34),
            Offset(center.dx + s * fx, center.dy + s * 0.34));
      }
      break;
    case GemType.bomb:
      canvas.drawCircle(center, s * 0.2,
          Paint()..color = Colors.black.withValues(alpha: 0.5));
      canvas.drawCircle(
          center,
          s * 0.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.06
            ..color = Colors.white);
      for (int i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        canvas.drawLine(
          Offset(center.dx + math.cos(a) * s * 0.22,
              center.dy + math.sin(a) * s * 0.22),
          Offset(center.dx + math.cos(a) * s * 0.32,
              center.dy + math.sin(a) * s * 0.32),
          Paint()
            ..color = Colors.white
            ..strokeWidth = s * 0.05
            ..strokeCap = StrokeCap.round,
        );
      }
      break;
    case GemType.rainbow:
      final colors = NeonTheme.gemColors;
      for (int i = 0; i < colors.length; i++) {
        final a = i / colors.length * math.pi * 2;
        canvas.drawCircle(
          Offset(center.dx + math.cos(a) * s * 0.22,
              center.dy + math.sin(a) * s * 0.22),
          s * 0.075,
          Paint()..color = colors[i],
        );
      }
      canvas.drawCircle(
          center, s * 0.1, Paint()..color = Colors.white.withValues(alpha: 0.9));
      break;
    case GemType.normal:
      break;
  }
}

// --- Hình lá bài (giống gem_component.dart) ---
Path _shapePath(int idx, Offset c, double r) {
  switch (idx) {
    case 0:
      return Path()..addOval(Rect.fromCircle(center: c, radius: r));
    case 1:
      return _heart(c, r);
    case 2:
      return _club(c, r);
    case 3:
      return _star(c, r * 1.18, r * 0.5, 5);
    case 4:
      return _diamondSuit(c, r);
    default:
      return _spade(c, r);
  }
}

Path _heart(Offset c, double r) {
  final p = Path();
  p.moveTo(c.dx, c.dy + r * 0.95);
  p.cubicTo(c.dx - r * 1.35, c.dy - r * 0.15, c.dx - r * 0.55, c.dy - r * 1.15,
      c.dx, c.dy - r * 0.4);
  p.cubicTo(c.dx + r * 0.55, c.dy - r * 1.15, c.dx + r * 1.35, c.dy - r * 0.15,
      c.dx, c.dy + r * 0.95);
  return p..close();
}

Path _spade(Offset c, double r) {
  final p = Path();
  p.moveTo(c.dx, c.dy - r * 1.0);
  p.cubicTo(c.dx + r * 1.35, c.dy + r * 0.15, c.dx + r * 0.55, c.dy + r * 1.0,
      c.dx, c.dy + r * 0.35);
  p.cubicTo(c.dx - r * 0.55, c.dy + r * 1.0, c.dx - r * 1.35, c.dy + r * 0.15,
      c.dx, c.dy - r * 1.0);
  p.close();
  p.moveTo(c.dx - r * 0.38, c.dy + r * 0.95);
  p.lineTo(c.dx + r * 0.38, c.dy + r * 0.95);
  p.lineTo(c.dx + r * 0.12, c.dy + r * 0.35);
  p.lineTo(c.dx - r * 0.12, c.dy + r * 0.35);
  p.close();
  return p;
}

Path _club(Offset c, double r) {
  final cr = r * 0.5;
  final p = Path()
    ..addOval(Rect.fromCircle(center: Offset(c.dx, c.dy - r * 0.42), radius: cr))
    ..addOval(Rect.fromCircle(
        center: Offset(c.dx - r * 0.55, c.dy + r * 0.18), radius: cr))
    ..addOval(Rect.fromCircle(
        center: Offset(c.dx + r * 0.55, c.dy + r * 0.18), radius: cr));
  p.moveTo(c.dx - r * 0.34, c.dy + r * 0.98);
  p.lineTo(c.dx + r * 0.34, c.dy + r * 0.98);
  p.lineTo(c.dx + r * 0.13, c.dy + r * 0.3);
  p.lineTo(c.dx - r * 0.13, c.dy + r * 0.3);
  p.close();
  return p;
}

Path _diamondSuit(Offset c, double r) {
  return Path()
    ..moveTo(c.dx, c.dy - r * 1.1)
    ..lineTo(c.dx + r * 0.82, c.dy)
    ..lineTo(c.dx, c.dy + r * 1.1)
    ..lineTo(c.dx - r * 0.82, c.dy)
    ..close();
}

Path _star(Offset c, double outer, double inner, int points) {
  final path = Path();
  for (int i = 0; i < points * 2; i++) {
    final rad = i.isEven ? outer : inner;
    final a = -math.pi / 2 + i * math.pi / points;
    final p = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

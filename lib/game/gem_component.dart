import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../core/neon_theme.dart';
import '../logic/gem_data.dart';
import 'effects.dart';

/// Ánh xạ GemColor (logic) sang màu neon thật (render).
Color neonColorOf(GemColor c) => NeonTheme.gemColors[c.index];

/// Mỗi màu gem có 1 HÌNH DẠNG neon riêng (đa dạng + dễ phân biệt màu):
/// 0 cyan=tròn, 1 magenta=kim cương, 2 lime=tam giác,
/// 3 yellow=lục giác, 4 orange=ngũ giác, 5 purple=ngôi sao.
class GemComponent extends PositionComponent {
  GemColor color;
  GemType type;
  int row;
  int col;

  double _pulse = 0; // pha dao động cho hiệu ứng nhấp nháy
  bool selected = false;
  bool hint = false; // nhấp nháy gợi ý khi người chơi bị stuck
  bool isIngredient = false; // Drop Down: item cần đưa xuống đáy

  GemComponent({
    required this.color,
    required this.type,
    required this.row,
    required this.col,
    required Vector2 position,
    required double cellSize,
  }) : super(
          position: position,
          size: Vector2.all(cellSize * 0.9),
          anchor: Anchor.center,
        ) {
    _pulse = (row * 7 + col * 13) % 100 / 100 * math.pi * 2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt * 3.0;
  }

  @override
  void render(Canvas canvas) {
    if (isIngredient) {
      _renderIngredient(canvas);
      return;
    }
    final c = neonColorOf(color);
    final s = size.x;
    final center = Offset(s / 2, s / 2);
    final r = s * 0.40;
    final pulseAmt = 0.5 + 0.5 * math.sin(_pulse);
    final isSpecial = type != GemType.normal;

    // 1) Glow ngoài (ảnh cache) — gem special sáng mạnh & nhịp nhanh hơn
    NeonFx.drawGlow(
      canvas,
      center,
      s * (selected ? 0.95 : (isSpecial ? 0.9 : 0.7)) +
          pulseAmt * s * (isSpecial ? 0.22 : 0.12),
      type == GemType.rainbow ? Colors.white : c,
      opacity: selected ? 1.0 : (isSpecial ? 0.95 : 0.75),
    );

    final path = _shapePath(color.index, center, r);
    final bounds = path.getBounds();

    // 2) Thân gem: gradient radial sáng giữa
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

    // 3) Viền neon đôi: ống màu dày mờ + lõi trắng mảnh → cảm giác "đèn neon"
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

    // 4) Đốm sáng highlight
    canvas.drawCircle(
      Offset(center.dx - r * 0.32, center.dy - r * 0.34),
      s * 0.07,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    // 5) Overlay special + vòng sáng xoay gây chú ý
    if (isSpecial) {
      _drawAttentionRing(
          canvas, center, s, type == GemType.rainbow ? Colors.white : c);
    }
    _renderSpecial(canvas, s, center, c);

    // Vòng chọn
    if (selected) {
      canvas.drawCircle(
        center,
        s * 0.48,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.05
          ..color = Colors.white.withValues(alpha: 0.9),
      );
    }

    // Gợi ý nhấp nháy khi stuck
    if (hint) {
      final blink = 0.35 + 0.65 * pulseAmt;
      NeonFx.drawGlow(canvas, center, s * 0.7, Colors.white, opacity: blink);
      canvas.drawCircle(
        center,
        s * 0.46,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.06
          ..color = Colors.white.withValues(alpha: blink),
      );
    }
  }

  /// Render ingredient (Drop Down): huy hiệu phát sáng + mũi tên xuống.
  void _renderIngredient(Canvas canvas) {
    final s = size.x;
    final center = Offset(s / 2, s / 2);
    final pulseAmt = 0.5 + 0.5 * math.sin(_pulse);
    const gold = Color(0xFFFFC83D);

    NeonFx.drawGlow(canvas, center, s * (0.8 + pulseAmt * 0.18), gold,
        opacity: 0.95);

    // đĩa tròn gradient
    canvas.drawCircle(
      center,
      s * 0.36,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [
            Color.lerp(gold, Colors.white, 0.7)!,
            gold,
            Color.lerp(gold, Colors.black, 0.3)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: s * 0.36)),
    );
    // viền neon
    canvas.drawCircle(
      center,
      s * 0.36,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.05
        ..color = Colors.white.withValues(alpha: 0.9),
    );

    // mũi tên xuống (chevron đôi)
    final arrow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF3A2400);
    for (final dy in [-0.12, 0.12]) {
      final p = Path()
        ..moveTo(center.dx - s * 0.16, center.dy + s * (dy - 0.04))
        ..lineTo(center.dx, center.dy + s * (dy + 0.12))
        ..lineTo(center.dx + s * 0.16, center.dy + s * (dy - 0.04));
      canvas.drawPath(p, arrow);
    }
  }

  /// Bộ lá bài: mỗi màu một chất.
  /// 0 cyan=tròn ●, 1 magenta=cơ ♥, 2 lime=chuồn ♣,
  /// 3 yellow=sao ★, 4 orange=rô ♦, 5 purple=bích ♠.
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

  /// Cơ ♥
  Path _heart(Offset c, double r) {
    final p = Path();
    p.moveTo(c.dx, c.dy + r * 0.95);
    p.cubicTo(c.dx - r * 1.35, c.dy - r * 0.15, c.dx - r * 0.55, c.dy - r * 1.15,
        c.dx, c.dy - r * 0.4);
    p.cubicTo(c.dx + r * 0.55, c.dy - r * 1.15, c.dx + r * 1.35, c.dy - r * 0.15,
        c.dx, c.dy + r * 0.95);
    return p..close();
  }

  /// Bích ♠ (cơ lật ngược + cuống)
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

  /// Chuồn ♣ (3 vòng tròn + cuống)
  Path _club(Offset c, double r) {
    final cr = r * 0.5;
    final p = Path()
      ..addOval(Rect.fromCircle(center: Offset(c.dx, c.dy - r * 0.42), radius: cr))
      ..addOval(
          Rect.fromCircle(center: Offset(c.dx - r * 0.55, c.dy + r * 0.18), radius: cr))
      ..addOval(
          Rect.fromCircle(center: Offset(c.dx + r * 0.55, c.dy + r * 0.18), radius: cr));
    p.moveTo(c.dx - r * 0.34, c.dy + r * 0.98);
    p.lineTo(c.dx + r * 0.34, c.dy + r * 0.98);
    p.lineTo(c.dx + r * 0.13, c.dy + r * 0.3);
    p.lineTo(c.dx - r * 0.13, c.dy + r * 0.3);
    p.close();
    return p;
  }

  /// Rô ♦ (thoi cao)
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

  /// Vòng cung sáng xoay quanh gem special → bắt mắt người chơi.
  void _drawAttentionRing(Canvas canvas, Offset center, double s, Color color) {
    final rect = Rect.fromCircle(center: center, radius: s * 0.52);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.045
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.9);
    for (int i = 0; i < 4; i++) {
      final start = _pulse * 1.6 + i * math.pi / 2;
      canvas.drawArc(rect, start, 0.55, false, paint);
    }
  }

  void _renderSpecial(Canvas canvas, double s, Offset center, Color c) {
    if (type == GemType.normal) return;
    final pulse = 0.6 + 0.4 * math.sin(_pulse * 1.8);

    // Vạch neon đậm: ống màu dày + lõi trắng (dùng cho striped).
    void neonBar(Offset a, Offset b) {
      canvas.drawLine(
          a,
          b,
          Paint()
            ..color = c
            ..strokeWidth = s * 0.16
            ..strokeCap = StrokeCap.round);
      canvas.drawLine(
          a,
          b,
          Paint()
            ..color = Colors.white
            ..strokeWidth = s * 0.07
            ..strokeCap = StrokeCap.round);
    }

    switch (type) {
      case GemType.stripedH:
        for (final fy in [-0.2, 0.2]) {
          neonBar(Offset(s * 0.16, center.dy + s * fy),
              Offset(s * 0.84, center.dy + s * fy));
        }
        break;
      case GemType.stripedV:
        for (final fx in [-0.2, 0.2]) {
          neonBar(Offset(center.dx + s * fx, s * 0.16),
              Offset(center.dx + s * fx, s * 0.84));
        }
        break;
      case GemType.bomb:
        // lõi tối + vòng sáng nhịp + tia năng lượng
        canvas.drawCircle(center, s * 0.2,
            Paint()..color = Colors.black.withValues(alpha: 0.5));
        canvas.drawCircle(
            center,
            s * 0.2 * pulse,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = s * 0.06
              ..color = Colors.white);
        for (int i = 0; i < 8; i++) {
          final a = i * math.pi / 4 + _pulse * 0.5;
          canvas.drawLine(
            Offset(center.dx + math.cos(a) * s * 0.22,
                center.dy + math.sin(a) * s * 0.22),
            Offset(center.dx + math.cos(a) * s * 0.34,
                center.dy + math.sin(a) * s * 0.34),
            Paint()
              ..color = Colors.white
              ..strokeWidth = s * 0.05
              ..strokeCap = StrokeCap.round,
          );
        }
        canvas.drawCircle(center, s * 0.07,
            Paint()..color = Colors.white.withValues(alpha: pulse));
        break;
      case GemType.rainbow:
        // vòng cầu vồng xoay + lõi trắng sáng
        final colors = NeonTheme.gemColors;
        for (int i = 0; i < colors.length; i++) {
          final a = i / colors.length * math.pi * 2 + _pulse;
          canvas.drawCircle(
            Offset(center.dx + math.cos(a) * s * 0.24,
                center.dy + math.sin(a) * s * 0.24),
            s * 0.08,
            Paint()..color = colors[i],
          );
        }
        canvas.drawCircle(center, s * 0.12 * pulse,
            Paint()..color = Colors.white.withValues(alpha: 0.9));
        break;
      case GemType.normal:
        break;
    }
  }
}

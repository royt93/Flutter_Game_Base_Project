import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../core/neon_theme.dart';
import '../logic/gem_data.dart';

/// Ánh xạ GemColor (logic) sang màu neon thật (render).
Color neonColorOf(GemColor c) => NeonTheme.gemColors[c.index];

/// Component hiển thị 1 viên gem neon với glow rực rỡ + pulsing.
class GemComponent extends PositionComponent {
  GemColor color;
  GemType type;
  int row;
  int col;

  double _pulse = 0; // pha dao động cho hiệu ứng nhấp nháy
  bool selected = false;

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
    _pulse = (row * 7 + col * 13) % 100 / 100 * math.pi * 2; // lệch pha
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt * 3.0;
  }

  @override
  void render(Canvas canvas) {
    final c = neonColorOf(color);
    final s = size.x;
    final rect = Rect.fromLTWH(0, 0, s, s);
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(s * 0.06),
      Radius.circular(s * 0.26),
    );

    final pulseAmt = 0.5 + 0.5 * math.sin(_pulse); // 0..1
    final glowBlur = (selected ? 26.0 : 14.0) + pulseAmt * 8;

    // 1) Glow ngoài (vầng sáng neon)
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = c.withValues(alpha: 0.9)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlur),
    );

    // 2) Thân gem: gradient radial sáng ở giữa
    final light = Color.lerp(c, Colors.white, 0.55)!;
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 0.95,
          colors: [light, c, Color.lerp(c, Colors.black, 0.35)!],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rrect.outerRect),
    );

    // 3) Viền sáng
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.04
        ..color = Colors.white.withValues(alpha: 0.85),
    );

    // 4) Đốm sáng highlight góc trên-trái
    canvas.drawCircle(
      Offset(s * 0.34, s * 0.32),
      s * 0.1,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    // 5) Overlay theo loại special
    _renderSpecial(canvas, s, c);

    // Vòng chọn khi được tap
    if (selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(s * 0.02), Radius.circular(s * 0.3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.06
          ..color = Colors.white,
      );
    }
  }

  void _renderSpecial(Canvas canvas, double s, Color c) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = s * 0.05
      ..style = PaintingStyle.stroke;
    switch (type) {
      case GemType.stripedH:
        for (final fy in [0.35, 0.5, 0.65]) {
          canvas.drawLine(Offset(s * 0.18, s * fy), Offset(s * 0.82, s * fy), p);
        }
        break;
      case GemType.stripedV:
        for (final fx in [0.35, 0.5, 0.65]) {
          canvas.drawLine(Offset(s * fx, s * 0.18), Offset(s * fx, s * 0.82), p);
        }
        break;
      case GemType.rainbow:
        // Vòng tròn cầu vồng phát sáng
        final colors = NeonTheme.gemColors;
        for (int i = 0; i < colors.length; i++) {
          final a = i / colors.length * math.pi * 2 + _pulse;
          canvas.drawCircle(
            Offset(s * 0.5 + math.cos(a) * s * 0.2, s * 0.5 + math.sin(a) * s * 0.2),
            s * 0.07,
            Paint()..color = colors[i],
          );
        }
        break;
      case GemType.normal:
        break;
    }
  }
}

import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../core/neon_theme.dart';

/// 1 ô màu trên bàn PopStar — viên "neon jewel": quầng bloom ngoài + thân
/// gradient (sáng đỉnh, đậm đáy) + gloss đỉnh + viền sáng. Không có variant
/// striped/rainbow/bomb (chỉ match-3 cần).
class BlockComponent extends PositionComponent {
  final int colorIndex;

  /// True khi ô đang được preview (thuộc nhóm người chơi giữ) → sáng rực thêm.
  bool highlighted = false;

  BlockComponent({
    required this.colorIndex,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size, anchor: Anchor.center);

  Color get _color =>
      NeonTheme.gemColors[colorIndex % NeonTheme.gemColors.length];

  @override
  void render(Canvas canvas) {
    final s = size.x;
    final inset = s * 0.06;
    final rect = Rect.fromLTWH(inset, inset, s - inset * 2, s - inset * 2);
    final radius = Radius.circular(s * 0.22);
    final rrect = RRect.fromRectAndRadius(rect, radius);
    final c = _color;

    // 1. quầng bloom ngoài
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = c.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.16),
    );

    // 2. thân gradient dọc: sáng ở đỉnh → đậm ở đáy
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(rect.left, rect.top),
          Offset(rect.left, rect.bottom),
          [
            Color.lerp(c, Colors.white, 0.38)!,
            c,
            Color.lerp(c, Colors.black, 0.30)!,
          ],
          const [0.0, 0.55, 1.0],
        ),
    );

    // 3. gloss sáng ở nửa trên
    final gloss = RRect.fromRectAndCorners(
      Rect.fromLTWH(
        rect.left + s * 0.12,
        rect.top + s * 0.08,
        rect.width - s * 0.24,
        rect.height * 0.30,
      ),
      topLeft: radius,
      topRight: radius,
      bottomLeft: Radius.circular(s * 0.12),
      bottomRight: Radius.circular(s * 0.12),
    );
    canvas.drawRRect(
      gloss,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    // 4. viền sáng
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.045
        ..color = Color.lerp(c, Colors.white, 0.5)!.withValues(alpha: 0.9),
    );

    // 5. preview highlight: quầng sáng trắng + viền trắng dày khi được chọn
    if (highlighted) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.22),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.07
          ..color = Colors.white.withValues(alpha: 0.95),
      );
    }
  }
}

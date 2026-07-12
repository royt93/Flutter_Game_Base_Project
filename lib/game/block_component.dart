import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../core/neon_theme.dart';
import '../logic/power_tile.dart';
import 'pop_star_game.dart';

/// 1 ô màu trên bàn PopStar — viên "neon jewel": quầng bloom ngoài + thân
/// gradient (sáng đỉnh, đậm đáy) + gloss đỉnh + viền sáng. Không có variant
/// striped/rainbow/bomb (chỉ match-3 cần).
class BlockComponent extends PositionComponent
    with HasGameReference<PopStarGame> {
  /// F6a: âm = obstacle còn (-colorIndex) độ bền, không phải màu — cần mutable
  /// vì `_syncObstacleBlocks` cập nhật lại sau mỗi lần bị chip.
  int colorIndex;

  /// True khi ô đang được preview (thuộc nhóm người chơi giữ) → sáng rực thêm.
  bool highlighted = false;

  /// F5: khác null nếu ô này là power tile (line-clear hàng/cột) — tap để
  /// kích hoạt thay vì tìm nhóm màu như ô thường.
  PowerTileKind? powerKind;

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

    // 0. F6a: obstacle (ice/crate) không phải màu — render riêng rồi thoát,
    // bỏ qua toàn bộ phần thân gem/preview/power-tile bên dưới.
    if (colorIndex < 0) {
      _renderObstacle(canvas, rrect, s, -colorIndex);
      return;
    }
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

    // 5. G6 combo heat: bàn càng "nóng" (combo cao) → rim ngả cam/trắng mạnh
    // hơn, nhưng chỉ cộng thêm lên viền — không thay màu thân nên vẫn phân
    // biệt được màu gốc.
    final heat = game.heat;
    if (heat > 0) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * (0.05 + 0.09 * heat)
          ..color = Color.lerp(
            NeonTheme.orange,
            Colors.white,
            heat * 0.5,
          )!.withValues(alpha: 0.25 + 0.55 * heat)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.1 * heat),
      );
    }

    // 6. preview highlight: quầng sáng trắng + viền trắng dày khi được chọn
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

    // 7. F5 power tile: quầng trắng mờ + icon báo loại hiệu ứng sẽ kích hoạt
    // khi tap (2 gạch song song = hàng/cột, quả bom = nổ 5x5, chấm nhiều màu =
    // rainbow xoá cả màu).
    if (powerKind != null) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.3),
      );
      final iconPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.07
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.95);
      final mid = s / 2;
      final half = s * 0.3;
      final gap = s * 0.08;
      switch (powerKind!) {
        case PowerTileKind.lineRow:
          canvas.drawLine(
            Offset(mid - half, mid - gap),
            Offset(mid + half, mid - gap),
            iconPaint,
          );
          canvas.drawLine(
            Offset(mid - half, mid + gap),
            Offset(mid + half, mid + gap),
            iconPaint,
          );
        case PowerTileKind.lineCol:
          canvas.drawLine(
            Offset(mid - gap, mid - half),
            Offset(mid - gap, mid + half),
            iconPaint,
          );
          canvas.drawLine(
            Offset(mid + gap, mid - half),
            Offset(mid + gap, mid + half),
            iconPaint,
          );
        case PowerTileKind.bomb:
          canvas.drawCircle(
            Offset(mid, mid + s * 0.04),
            s * 0.22,
            Paint()..color = Colors.white.withValues(alpha: 0.95),
          );
          canvas.drawLine(
            Offset(mid + s * 0.1, mid - s * 0.22),
            Offset(mid + s * 0.22, mid - s * 0.34),
            iconPaint,
          );
          canvas.drawCircle(
            Offset(mid + s * 0.24, mid - s * 0.36),
            s * 0.04,
            Paint()..color = NeonTheme.orange,
          );
        case PowerTileKind.rainbow:
          const dotColors = [
            Colors.redAccent,
            Colors.orangeAccent,
            Colors.yellowAccent,
            Colors.greenAccent,
            Colors.blueAccent,
            Colors.purpleAccent,
          ];
          for (var i = 0; i < dotColors.length; i++) {
            final angle = 2 * pi * i / dotColors.length - pi / 2;
            final dotCenter = Offset(
              mid + half * 0.85 * cos(angle),
              mid + half * 0.85 * sin(angle),
            );
            canvas.drawCircle(
              dotCenter,
              s * 0.07,
              Paint()..color = dotColors[i],
            );
          }
      }
    }
  }

  /// F6a: khối băng/thùng xám-xanh mờ + số chấm trắng = độ bền còn lại.
  void _renderObstacle(Canvas canvas, RRect rrect, double s, int durability) {
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFF9DB8C8).withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.1),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.06
        ..color = Colors.white.withValues(alpha: 0.85),
    );
    final mid = s / 2;
    final dotR = s * 0.07;
    final spacing = s * 0.2;
    final startX = mid - spacing * (durability - 1) / 2;
    for (var i = 0; i < durability; i++) {
      canvas.drawCircle(
        Offset(startX + spacing * i, mid),
        dotR,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
    }
  }
}

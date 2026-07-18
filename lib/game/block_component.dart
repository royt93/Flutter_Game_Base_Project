import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../core/neon_theme.dart';
import '../data/worlds.dart';
import '../logic/boss_tile.dart' show isBossTileId;
import '../logic/gift_tile.dart';
import '../logic/power_tile.dart';
import 'pop_star_game.dart';

/// I17: chất liệu render gem theo world — jelly (world đầu, mềm bóng),
/// crystal (world giữa, góc cạnh phản chiếu), metal (world cuối, ánh kim).
/// Chỉ đổi cách vẽ (paint), không đụng `colorGrid`/logic pop/hitbox.
enum TileMaterial { jelly, crystal, metal }

/// Chia đều 10 world (index trong [kWorlds]) thành 3 dải material — không
/// hardcode lại "20 màn/world" (đã có trong `worlds.dart`), chỉ dựa vào index
/// world thật để không lệch khi số world thay đổi.
TileMaterial materialForLevel(int id) {
  final index = kWorlds.indexOf(worldForLevel(id));
  if (index < 4) return TileMaterial.jelly;
  if (index < 7) return TileMaterial.crystal;
  return TileMaterial.metal;
}

double _radiusFactor(TileMaterial m) => switch (m) {
  TileMaterial.jelly => 0.22,
  TileMaterial.crystal => 0.10,
  TileMaterial.metal => 0.16,
};

/// I17: thân gradient + gloss + viền gem theo [material] — tách khỏi
/// [BlockComponent.render] để golden test vẽ trực tiếp qua `CustomPainter`,
/// không cần dựng cả Flame game (bước này không đụng `game.heat`/colorblind).
/// Giữ đúng 3 lệnh vẽ (drawRRect thân, drawRRect/Path gloss, drawRRect viền)
/// ở mọi variant — không thêm draw call so với bản gốc.
void paintTileBody(
  Canvas canvas,
  RRect rrect,
  Rect rect,
  double s,
  Color c,
  TileMaterial material,
) {
  switch (material) {
    case TileMaterial.jelly:
      // thân: gradient dọc mềm, sáng đỉnh → đậm đáy.
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
      // gloss: khối bo tròn sáng ở nửa trên (bóng nhựa jelly).
      final gloss = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          rect.left + s * 0.12,
          rect.top + s * 0.08,
          rect.width - s * 0.24,
          rect.height * 0.30,
        ),
        topLeft: Radius.circular(s * _radiusFactor(material)),
        topRight: Radius.circular(s * _radiusFactor(material)),
        bottomLeft: Radius.circular(s * 0.12),
        bottomRight: Radius.circular(s * 0.12),
      );
      canvas.drawRRect(
        gloss,
        Paint()..color = Colors.white.withValues(alpha: 0.22),
      );
      // viền: mềm, hoà vào màu thân.
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.045
          ..color = Color.lerp(c, Colors.white, 0.5)!.withValues(alpha: 0.9),
      );
    case TileMaterial.crystal:
      // thân: gradient chéo góc, stop cứng hơn = mặt cắt pha lê.
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(rect.left, rect.top),
            Offset(rect.right, rect.bottom),
            [
              Color.lerp(c, Colors.white, 0.6)!,
              c,
              Color.lerp(c, Colors.black, 0.4)!,
            ],
            const [0.0, 0.45, 1.0],
          ),
      );
      // gloss: 1 vệt chéo mỏng phản chiếu (facet), không phải khối bo tròn.
      canvas.save();
      canvas.translate(rect.left + rect.width / 2, rect.top + rect.height / 2);
      canvas.rotate(-pi / 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: s * 0.08,
            height: s * 0.9,
          ),
          Radius.circular(s * 0.04),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
      canvas.restore();
      // viền: mảnh, sáng gần trắng — cạnh sắc phản chiếu.
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.035
          ..color = Color.lerp(c, Colors.white, 0.75)!.withValues(alpha: 0.95),
      );
    case TileMaterial.metal:
      // thân: gradient ngang nhiều dải sáng/tối = ánh kim chải (brushed).
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(rect.left, rect.top),
            Offset(rect.right, rect.top),
            [
              Color.lerp(c, Colors.black, 0.35)!,
              Color.lerp(c, Colors.white, 0.55)!,
              Color.lerp(c, Colors.black, 0.25)!,
              Color.lerp(c, Colors.white, 0.35)!,
              Color.lerp(c, Colors.black, 0.3)!,
            ],
            const [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
      );
      // gloss: dải sáng ngang mỏng giữa thân (phản chiếu kim loại).
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left,
            rect.top + rect.height * 0.42,
            rect.width,
            rect.height * 0.1,
          ),
          Radius.circular(s * 0.02),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.4),
      );
      // viền: dày, ngả xám — cảm giác khung kim loại.
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.06
          ..color = Color.lerp(
            c,
            const Color(0xFFD9D9D9),
            0.6,
          )!.withValues(alpha: 0.85),
      );
  }
}

/// 1 ô màu trên bàn PopStar — viên "neon jewel": quầng bloom ngoài + thân
/// gradient (sáng đỉnh, đậm đáy) + gloss đỉnh + viền sáng. I17: thân/gloss/
/// viền đổi chất liệu theo [material]. Không có variant striped/rainbow/bomb
/// (chỉ match-3 cần).
class BlockComponent extends PositionComponent
    with HasGameReference<PopStarGame> {
  /// F6a: âm = obstacle còn (-colorIndex) độ bền, không phải màu — cần mutable
  /// vì `_syncObstacleBlocks` cập nhật lại sau mỗi lần bị chip.
  int colorIndex;

  /// True khi ô đang được preview (thuộc nhóm người chơi giữ) → sáng rực thêm.
  bool highlighted = false;

  /// I4: true khi ô thuộc nhóm gợi ý (predictive hint, tự trigger sau vài
  /// giây rảnh tay) — viền pulse nhạt, tách khỏi [highlighted] để không đụng
  /// hiệu ứng preview khi giữ/kéo.
  bool hinted = false;
  double _hintPhase = 0;

  /// F5: khác null nếu ô này là power tile (line-clear hàng/cột) — tap để
  /// kích hoạt thay vì tìm nhóm màu như ô thường.
  PowerTileKind? powerKind;

  /// I2: >0 nghĩa là ô đang bị chain tile khoá (còn bấy nhiêu lần ô cạnh cần
  /// nổ mới mở) — mutable vì `_syncLockBlocks` cập nhật lại sau mỗi lần bị
  /// chip qua `chipAdjacentLocks`.
  int lockCount;

  /// I29: khác null nếu ô này thuộc 1 boss tile (giá trị = HP còn lại) —
  /// đồng bộ riêng từ `PopStarGame.bossHp` vì HP không mã hoá trong
  /// [colorIndex] (chỉ mã ID, xem `logic/boss_tile.dart`).
  int? bossHp;

  /// I17: chất liệu render — mặc định [TileMaterial.jelly] (world đầu).
  final TileMaterial material;

  BlockComponent({
    required this.colorIndex,
    required Vector2 position,
    required Vector2 size,
    this.lockCount = 0,
    this.bossHp,
    this.material = TileMaterial.jelly,
  }) : super(position: position, size: size, anchor: Anchor.center);

  Color get _color =>
      NeonTheme.gemColors[colorIndex % NeonTheme.gemColors.length];

  // G8: quầng bloom (item 1 render) tốn blur mỗi frame cho MỌI ô bàn chơi dù
  // đứng yên. Bake sẵn 1 lần/màu thành bitmap tĩnh, mỗi frame chỉ blit
  // (drawImageRect) — rẻ hơn hẳn tính lại MaskFilter.blur. Kích thước tham
  // chiếu cố định, không phụ thuộc cellSize thật của level (khỏi build lại
  // cache khi đổi cỡ ô giữa các màn).
  static const double _bloomRef = 256.0;
  static const double _bloomMargin = 128.0;
  static final Map<int, ui.Image> _bloomCache = {};
  static Future<void>? _bloomCacheFuture;

  static Future<void> ensureBloomCache() {
    return _bloomCacheFuture ??= _buildBloomCache();
  }

  static Future<void> _buildBloomCache() async {
    final imgSize = (_bloomRef + _bloomMargin * 2).round();
    for (var i = 0; i < NeonTheme.gemColors.length; i++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final inset = _bloomRef * 0.06;
      final rect = Rect.fromLTWH(
        _bloomMargin + inset,
        _bloomMargin + inset,
        _bloomRef - inset * 2,
        _bloomRef - inset * 2,
      );
      final rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(_bloomRef * 0.22),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = NeonTheme.gemColors[i].withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _bloomRef * 0.16),
      );
      final picture = recorder.endRecording();
      _bloomCache[i] = await picture.toImage(imgSize, imgSize);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (hinted) _hintPhase += dt;
  }

  @override
  void render(Canvas canvas) {
    final s = size.x;
    final inset = s * 0.06;
    final rect = Rect.fromLTWH(inset, inset, s - inset * 2, s - inset * 2);
    final radius = Radius.circular(s * _radiusFactor(material));
    final rrect = RRect.fromRectAndRadius(rect, radius);

    // 0a. I1: gift tile — kiểm tra trước obstacle vì cũng mã hoá bằng giá
    // trị âm (xem `logic/gift_tile.dart`), không thì bị hiểu nhầm thành
    // obstacle cực bền (-giftTileValue chấm tròn).
    if (colorIndex == giftTileValue) {
      _renderGift(canvas, rrect, s);
      return;
    }
    // 0b. I29: boss tile — cũng mã hoá bằng giá trị âm (dải riêng
    // `<= bossTileIdBase`, xem `logic/boss_tile.dart`) nên PHẢI kiểm tra
    // trước nhánh obstacle bên dưới, không thì bị hiểu nhầm thành obstacle
    // cực bền.
    if (isBossTileId(colorIndex)) {
      _renderBoss(canvas, rrect, s, bossHp ?? 0);
      return;
    }
    // 0c. F6a: obstacle (ice/crate) không phải màu — render riêng rồi thoát,
    // bỏ qua toàn bộ phần thân gem/preview/power-tile bên dưới.
    if (colorIndex < 0) {
      _renderObstacle(canvas, rrect, s, -colorIndex);
      return;
    }
    final c = _color;

    // 1. quầng bloom ngoài — G8: blit bitmap cache sẵn (ensureBloomCache),
    // fallback vẽ blur trực tiếp nếu cache chưa kịp dựng.
    final bloomImg = _bloomCache[colorIndex % NeonTheme.gemColors.length];
    if (bloomImg != null) {
      final dstSize = s * (bloomImg.width / _bloomRef);
      canvas.drawImageRect(
        bloomImg,
        Rect.fromLTWH(
          0,
          0,
          bloomImg.width.toDouble(),
          bloomImg.height.toDouble(),
        ),
        Rect.fromCenter(
          center: Offset(s / 2, s / 2),
          width: dstSize,
          height: dstSize,
        ),
        Paint()..filterQuality = FilterQuality.low,
      );
    } else {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = c.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.16),
      );
    }

    // 2-4. thân gradient + gloss + viền — style theo material (I17).
    paintTileBody(canvas, rrect, rect, s, c, material);

    // 5. G6 combo heat: bàn càng "nóng" (combo cao) → rim ngả cam/trắng mạnh
    // hơn, nhưng chỉ cộng thêm lên viền — không thay màu thân nên vẫn phân
    // biệt được màu gốc.
    // ponytail: heat>0 đúng suốt combo streak (không hiếm) → MaskFilter.blur
    // sống trên MỌI ô mỗi frame là nguồn lag chính lúc chơi (rows*cols blur/
    // frame, trong khi bloom G8 đã bake cache). Bỏ blur, giữ solid stroke —
    // vẫn thấy "nóng" qua màu/độ dày, mất glow mềm.
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
          )!.withValues(alpha: 0.35 + 0.55 * heat),
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

    // 6b. I4: predictive hint — viền nhạt hơn preview, nhấp nháy chậm để
    // không lấn át highlight chủ động của người chơi.
    if (hinted) {
      final pulse = 0.5 + 0.5 * sin(_hintPhase * 3);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.2 + 0.2 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.2),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.05
          ..color = Colors.white.withValues(alpha: 0.35 + 0.35 * pulse),
      );
    }

    // 6c. I18: colorblind mode — symbol cố định theo colorIndex đè lên màu
    // nền, giúp phân biệt gem không chỉ dựa vào màu (đỏ-lục dễ nhầm).
    if (game.controller.colorblindMode.value) {
      _renderColorblindSymbol(canvas, s, colorIndex % 7);
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

    // 8. I2: chain tile khoá — phủ lớp tối + icon ổ khoá + chấm trắng đếm
    // lock còn lại, đè lên gem thật bên dưới (khác obstacle, không return
    // sớm vì màu vẫn phải hiển thị đúng).
    if (lockCount > 0) {
      _renderChainLock(canvas, rrect, s);
    }
  }

  /// I18: 7 symbol cố định ánh xạ 1-1 với colorIndex 0..6 — trắng viền đen để
  /// nổi rõ trên mọi màu nền gem.
  void _renderColorblindSymbol(Canvas canvas, double s, int shape) {
    final mid = s / 2;
    final r = s * 0.18;
    final fill = Paint()..color = Colors.white.withValues(alpha: 0.9);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.02
      ..color = Colors.black.withValues(alpha: 0.6);

    Path path;
    switch (shape) {
      case 0: // star
        path = Path();
        for (var i = 0; i < 10; i++) {
          final angle = pi / 5 * i - pi / 2;
          final radius = i.isEven ? r : r * 0.45;
          final point = Offset(
            mid + radius * cos(angle),
            mid + radius * sin(angle),
          );
          i == 0
              ? path.moveTo(point.dx, point.dy)
              : path.lineTo(point.dx, point.dy);
        }
        path.close();
      case 1: // circle
        canvas.drawCircle(Offset(mid, mid), r, fill);
        canvas.drawCircle(Offset(mid, mid), r, stroke);
        return;
      case 2: // triangle
        path = Path()
          ..moveTo(mid, mid - r)
          ..lineTo(mid + r * 0.87, mid + r * 0.5)
          ..lineTo(mid - r * 0.87, mid + r * 0.5)
          ..close();
      case 3: // square
        path = Path()
          ..addRect(
            Rect.fromCircle(center: Offset(mid, mid), radius: r * 0.75),
          );
      case 4: // diamond
        path = Path()
          ..moveTo(mid, mid - r)
          ..lineTo(mid + r, mid)
          ..lineTo(mid, mid + r)
          ..lineTo(mid - r, mid)
          ..close();
      case 5: // hexagon
        path = Path();
        for (var i = 0; i < 6; i++) {
          final angle = pi / 3 * i - pi / 2;
          final point = Offset(mid + r * cos(angle), mid + r * sin(angle));
          i == 0
              ? path.moveTo(point.dx, point.dy)
              : path.lineTo(point.dx, point.dy);
        }
        path.close();
      default: // cross
        final t = r * 0.4;
        path = Path()
          ..moveTo(mid - t, mid - r)
          ..lineTo(mid + t, mid - r)
          ..lineTo(mid + t, mid - t)
          ..lineTo(mid + r, mid - t)
          ..lineTo(mid + r, mid + t)
          ..lineTo(mid + t, mid + t)
          ..lineTo(mid + t, mid + r)
          ..lineTo(mid - t, mid + r)
          ..lineTo(mid - t, mid + t)
          ..lineTo(mid - r, mid + t)
          ..lineTo(mid - r, mid - t)
          ..lineTo(mid - t, mid - t)
          ..close();
    }
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  /// I1: hộp quà vàng-hồng + dải ruy băng chữ thập, khác hẳn obstacle/gem.
  void _renderGift(Canvas canvas, RRect rrect, double s) {
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = NeonTheme.gold.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.16),
    );
    canvas.drawRRect(rrect, Paint()..color = NeonTheme.gold);
    final ribbon = s * 0.16;
    final mid = s / 2;
    canvas.drawRect(
      Rect.fromLTWH(mid - ribbon / 2, 0, ribbon, s),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, mid - ribbon / 2, s, ribbon),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.045
        ..color = Colors.white.withValues(alpha: 0.9),
    );
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

  /// I29: khối boss tile — đỏ-tím "nguy hiểm" khác hẳn obstacle băng/thùng,
  /// hiển thị [hp] bằng số thay vì chấm (HP có thể tới 16, chấm sẽ rối như
  /// obstacle chỉ vài đơn vị).
  void _renderBoss(Canvas canvas, RRect rrect, double s, int hp) {
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = NeonTheme.red.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.16),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(rrect.left, rrect.top),
          Offset(rrect.right, rrect.bottom),
          [const Color(0xFF3A0A1E), NeonTheme.red, const Color(0xFF6B1030)],
          const [0.0, 0.5, 1.0],
        ),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.055
        ..color = Colors.white.withValues(alpha: 0.85),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: '$hp',
        style: TextStyle(
          color: Colors.white,
          fontSize: s * 0.32,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: s * 0.05,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(s / 2 - painter.width / 2, s / 2 - painter.height / 2),
    );
  }

  /// I2: chain tile — lớp tối bán trong suốt + icon ổ khoá + chấm trắng đếm
  /// lock còn lại (tái dùng ngôn ngữ hình ảnh "chấm đếm" của [_renderObstacle]).
  void _renderChainLock(Canvas canvas, RRect rrect, double s) {
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    final mid = s / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(mid, mid + s * 0.06),
          width: s * 0.3,
          height: s * 0.22,
        ),
        Radius.circular(s * 0.04),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(mid, mid - s * 0.06), radius: s * 0.12),
      pi,
      pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.05
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.9),
    );
    final dotR = s * 0.055;
    final spacing = s * 0.16;
    final startX = mid - spacing * (lockCount - 1) / 2;
    for (var i = 0; i < lockCount; i++) {
      canvas.drawCircle(
        Offset(startX + spacing * i, mid + s * 0.32),
        dotR,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
    }
  }
}

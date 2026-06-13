import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import '../core/neon_theme.dart';

/// Cache hiệu ứng dùng chung — pre-render 1 lần để tránh MaskFilter.blur mỗi frame
/// (blur per-frame là nguyên nhân lag chính trên mobile).
class NeonFx {
  NeonFx._();

  /// Đĩa sáng mềm (trắng → trong suốt) tái sử dụng cho mọi glow/orb.
  static ui.Image? softDisc;
  static bool _initStarted = false;

  static Future<void> ensureInit() async {
    if (_initStarted) return;
    _initStarted = true;
    softDisc = await _makeSoftDisc(128);
  }

  static Future<ui.Image> _makeSoftDisc(int size) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final c = size / 2.0;
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(c, c),
        c,
        const [Color(0xFFFFFFFF), Color(0x66FFFFFF), Color(0x00FFFFFF)],
        const [0.0, 0.45, 1.0],
      );
    canvas.drawCircle(Offset(c, c), c, paint);
    return recorder.endRecording().toImage(size, size);
  }

  /// Vẽ vầng sáng neon rẻ tiền bằng ảnh đĩa cache (không dùng MaskFilter).
  static void drawGlow(Canvas canvas, Offset center, double radius, Color color,
      {double opacity = 1.0}) {
    final disc = softDisc;
    if (disc == null) return;
    final rect = Rect.fromCenter(center: center, width: radius * 2, height: radius * 2);
    canvas.drawImageRect(
      disc,
      Rect.fromLTWH(0, 0, disc.width.toDouble(), disc.height.toDouble()),
      rect,
      Paint()
        ..colorFilter = ColorFilter.mode(
          color.withValues(alpha: opacity.clamp(0.0, 1.0)),
          BlendMode.modulate,
        )
        ..filterQuality = FilterQuality.low,
    );
  }
}

class _Orb {
  Vector2 pos;
  Vector2 vel;
  double radius;
  Color color;
  _Orb(this.pos, this.vel, this.radius, this.color);
}

class _Star {
  final Offset pos;
  final double phase;
  final double size;
  final double speed;
  final bool sparkle; // true = ngôi sao 4 cánh, false = chấm tròn
  final Color color;
  _Star(this.pos, this.phase, this.size, this.speed, this.sparkle, this.color);
}

/// Nền neon động & đẹp: lưới phát sáng mờ + orb gradient trôi + sao lấp lánh.
/// Tối ưu: orb dùng ảnh đĩa cache, lưới/sao là vẽ vector rẻ.
class NeonBackground extends PositionComponent {
  final Vector2 area;
  final List<Color> palette;
  final math.Random rnd;
  final List<_Orb> _orbs = [];
  final List<_Orb> _nebula = []; // đám mây sáng lớn tạo chiều sâu
  final List<_Star> _stars = [];
  double _time = 0;
  late final Paint _vignette;

  NeonBackground({required this.area, required this.palette, required this.rnd}) {
    _vignette = Paint()
      ..shader = ui.Gradient.radial(
        Offset(area.x / 2, area.y * 0.42),
        math.max(area.x, area.y) * 0.72,
        const [Color(0x00000000), Color(0x55000000), Color(0x99000000)],
        const [0.5, 0.82, 1.0],
      );
    for (int i = 0; i < 9; i++) {
      _orbs.add(_Orb(
        Vector2(rnd.nextDouble() * area.x, rnd.nextDouble() * area.y),
        Vector2(rnd.nextDouble() * 2 - 1, rnd.nextDouble() * 2 - 1)..scale(12),
        70 + rnd.nextDouble() * 100,
        palette[rnd.nextInt(palette.length)],
      ));
    }
    // nebula lớn, trôi rất chậm — tạo nền không gian sâu, lung linh
    for (int i = 0; i < 3; i++) {
      _nebula.add(_Orb(
        Vector2(rnd.nextDouble() * area.x, rnd.nextDouble() * area.y),
        Vector2(rnd.nextDouble() * 2 - 1, rnd.nextDouble() * 2 - 1)..scale(4),
        area.x * (0.4 + rnd.nextDouble() * 0.3),
        palette[rnd.nextInt(palette.length)],
      ));
    }
    for (int i = 0; i < 64; i++) {
      final sparkle = i % 5 == 0; // ~20% là sao 4 cánh
      _stars.add(_Star(
        Offset(rnd.nextDouble() * area.x, rnd.nextDouble() * area.y),
        rnd.nextDouble() * math.pi * 2,
        (sparkle ? 2.5 : 1.0) + rnd.nextDouble() * 2.2,
        0.8 + rnd.nextDouble() * 2.0,
        sparkle,
        palette[rnd.nextInt(palette.length)],
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    for (final o in [..._orbs, ..._nebula]) {
      o.pos.add(o.vel * dt);
      if (o.pos.x < -o.radius) o.pos.x = area.x + o.radius;
      if (o.pos.x > area.x + o.radius) o.pos.x = -o.radius;
      if (o.pos.y < -o.radius) o.pos.y = area.y + o.radius;
      if (o.pos.y > area.y + o.radius) o.pos.y = -o.radius;
    }
  }

  @override
  void render(Canvas canvas) {
    // nebula lớn (sâu, mờ) → orb vừa → sao → vignette
    for (final n in _nebula) {
      NeonFx.drawGlow(canvas, Offset(n.pos.x, n.pos.y), n.radius, n.color,
          opacity: 0.09);
    }
    for (final o in _orbs) {
      NeonFx.drawGlow(canvas, Offset(o.pos.x, o.pos.y), o.radius, o.color,
          opacity: 0.18);
    }
    _renderStars(canvas);
    canvas.drawRect(Rect.fromLTWH(0, 0, area.x, area.y), _vignette);
  }

  void _renderStars(Canvas canvas) {
    for (final s in _stars) {
      final tw = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(_time * s.speed + s.phase));
      if (s.sparkle) {
        // sao 4 cánh phát màu neon
        final paint = Paint()
          ..color = s.color.withValues(alpha: 0.8 * tw)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
        final r = s.size * (0.6 + 0.4 * tw);
        canvas.drawLine(
            Offset(s.pos.dx - r, s.pos.dy), Offset(s.pos.dx + r, s.pos.dy), paint);
        canvas.drawLine(
            Offset(s.pos.dx, s.pos.dy - r), Offset(s.pos.dx, s.pos.dy + r), paint);
        canvas.drawCircle(s.pos, 1.2,
            Paint()..color = Colors.white.withValues(alpha: 0.9 * tw));
      } else {
        canvas.drawCircle(
          s.pos,
          s.size,
          Paint()..color = Colors.white.withValues(alpha: 0.5 * tw),
        );
      }
    }
  }
}

/// Chớp sáng toàn màn hình (dùng cho rainbow / combo lớn). Tự huỷ.
class FlashOverlay extends PositionComponent {
  final Color color;
  final double peak;
  final double duration;
  double _t = 0;

  FlashOverlay({
    required Vector2 area,
    required this.color,
    this.peak = 0.3,
    this.duration = 0.4,
  }) : super(size: area);

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt / duration;
    if (_t >= 1) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final op = peak * (1 - _t).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = color.withValues(alpha: op),
    );
  }
}

/// Khung bàn chơi: panel bo góc + viền neon + các ô lõm (slot) kiểu khay đựng gem.
/// Đặt làm con của boardLayer để rung cùng gem (đồng bộ, không lệch).
class BoardFrame extends PositionComponent {
  final int rows;
  final int cols;
  final double cellSize;
  final Vector2 origin;

  BoardFrame({
    required this.rows,
    required this.cols,
    required this.cellSize,
    required this.origin,
  });

  @override
  void render(Canvas canvas) {
    final pad = cellSize * 0.16;
    final panel = RRect.fromLTRBR(
      origin.x - pad,
      origin.y - pad,
      origin.x + cols * cellSize + pad,
      origin.y + rows * cellSize + pad,
      Radius.circular(cellSize * 0.5),
    );

    // nền panel + viền neon đôi
    canvas.drawRRect(panel, Paint()..color = const Color(0xE60B0B1F));
    canvas.drawRRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF00F0FF).withValues(alpha: 0.5),
    );
    canvas.drawRRect(
      panel.inflate(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFBC4BFF).withValues(alpha: 0.3),
    );

    // ô vuông (radius 0); chỉ 4 ô góc bo tròn theo góc panel
    final cr = Radius.circular(cellSize * 0.4);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(
          origin.x + c * cellSize,
          origin.y + r * cellSize,
          cellSize,
          cellSize,
        ).deflate(cellSize * 0.02);
        final top = r == 0, bottom = r == rows - 1;
        final left = c == 0, right = c == cols - 1;
        final rr = RRect.fromRectAndCorners(
          rect,
          topLeft: top && left ? cr : Radius.zero,
          topRight: top && right ? cr : Radius.zero,
          bottomLeft: bottom && left ? cr : Radius.zero,
          bottomRight: bottom && right ? cr : Radius.zero,
        );
        final shade = (r + c).isEven ? 0.07 : 0.03;
        canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: shade));
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.white.withValues(alpha: 0.06),
        );
      }
    }
  }
}

/// Lớp jelly (obstacle): phủ ô có jelly bằng khối trong mờ phát sáng.
/// Đọc trực tiếp lưới jelly (cùng tham chiếu với game) nên tự cập nhật khi phá.
class JellyLayer extends PositionComponent {
  final List<List<int>> jelly;
  final int rows;
  final int cols;
  final double cellSize;
  final Vector2 origin;

  JellyLayer({
    required this.jelly,
    required this.rows,
    required this.cols,
    required this.cellSize,
    required this.origin,
  });

  @override
  void render(Canvas canvas) {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (jelly[r][c] <= 0) continue;
        final rect = Rect.fromLTWH(
          origin.x + c * cellSize,
          origin.y + r * cellSize,
          cellSize,
          cellSize,
        ).deflate(cellSize * 0.04);
        final rr = RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.26));
        canvas.drawRRect(
          rr,
          Paint()
            ..shader = ui.Gradient.linear(
              rect.topLeft,
              rect.bottomRight,
              [
                const Color(0xFF00F0FF).withValues(alpha: 0.28),
                const Color(0xFFBC4BFF).withValues(alpha: 0.28),
              ],
            ),
        );
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: 0.35),
        );
      }
    }
  }
}

/// Vòng sóng xung kích neon lan ra rồi tan — tự huỷ khi xong (không leak).
class ShockwaveComponent extends PositionComponent {
  final Color color;
  final double maxRadius;
  final double duration;
  double _t = 0;

  ShockwaveComponent({
    required Vector2 position,
    required this.color,
    required this.maxRadius,
    this.duration = 0.45,
  }) : super(position: position, anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt / duration;
    if (_t >= 1) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = _t.clamp(0.0, 1.0);
    final r = maxRadius * Curves.easeOutCubic.transform(p);
    final op = (1 - p);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + 6 * (1 - p)
        ..color = color.withValues(alpha: op),
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: op * 0.7),
    );
  }
}

/// Chữ combo bay lên + phóng to + mờ dần, tự huỷ.
class ComboTextComponent extends PositionComponent {
  final String text;
  final Color color;
  final double duration;
  final double fontSize;
  final double maxWidth; // giới hạn bề rộng để không tràn màn hình
  final bool epic; // WOMBO COMBO: đổi màu cầu vồng + rung mạnh
  double _t = 0;
  late final TextPaint _paint;

  ComboTextComponent({
    required this.text,
    required this.color,
    required Vector2 position,
    this.duration = 0.9,
    this.fontSize = 30,
    this.maxWidth = 9999,
    this.epic = false,
  }) : super(position: position, anchor: Anchor.center) {
    _paint = TextPaint(
      style: TextStyle(
        color: Colors.white,
        fontFamily: 'Orbitron',
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        shadows: [
          Shadow(color: color, blurRadius: 16),
          Shadow(color: color, blurRadius: 6),
        ],
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt / duration;
    position.y -= 36 * dt;
    if (_t >= 1) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = _t.clamp(0.0, 1.0);
    var scale = 0.6 + 0.7 * Curves.elasticOut.transform(p.clamp(0.0, 0.6) / 0.6);
    // epic: thêm rung scale + lắc xoay nhẹ
    final epicWobble = epic ? math.sin(_t * 40) * 0.04 : 0.0;
    scale += epicWobble;
    final op = p < 0.7 ? 1.0 : (1 - (p - 0.7) / 0.3);
    final m = _paint.getLineMetrics(text);
    if (m.width > 0 && m.width * scale > maxWidth) {
      scale = maxWidth / m.width;
    }

    // màu glow: epic đổi màu cầu vồng theo thời gian
    final glowColor = epic
        ? NeonTheme.gemColors[(_t * 18).floor() % NeonTheme.gemColors.length]
        : color;

    canvas.save();
    canvas.scale(scale);
    if (epic) canvas.rotate(math.sin(_t * 22) * 0.05);
    final tp = TextPaint(
      style: _paint.style.copyWith(
        color: Colors.white.withValues(alpha: op),
        shadows: [
          Shadow(color: glowColor, blurRadius: epic ? 26 : 16),
          Shadow(color: glowColor, blurRadius: epic ? 12 : 6),
        ],
      ),
    );
    tp.render(canvas, text, Vector2(-m.width / 2, -m.height / 2));
    canvas.restore();
  }
}

/// Tia laser neon nối 2 điểm (kích hoạt gem striped) — chớp sáng rồi tắt.
class BeamComponent extends PositionComponent {
  final Vector2 from;
  final Vector2 to;
  final Color color;
  final double duration;
  double _t = 0;

  BeamComponent({
    required this.from,
    required this.to,
    required this.color,
    this.duration = 0.3,
  });

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt / duration;
    if (_t >= 1) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = _t.clamp(0.0, 1.0);
    final op = math.sin(p * math.pi);
    final w = 3 + 10 * op;
    canvas.drawLine(
      Offset(from.x, from.y),
      Offset(to.x, to.y),
      Paint()
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: op * 0.6),
    );
    canvas.drawLine(
      Offset(from.x, from.y),
      Offset(to.x, to.y),
      Paint()
        ..strokeWidth = w * 0.4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: op),
    );
  }
}

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

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
  _Star(this.pos, this.phase, this.size, this.speed);
}

/// Nền neon động & đẹp: lưới phát sáng mờ + orb gradient trôi + sao lấp lánh.
/// Tối ưu: orb dùng ảnh đĩa cache, lưới/sao là vẽ vector rẻ.
class NeonBackground extends PositionComponent {
  final Vector2 area;
  final List<Color> palette;
  final math.Random rnd;
  final List<_Orb> _orbs = [];
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
    for (int i = 0; i < 7; i++) {
      _orbs.add(_Orb(
        Vector2(rnd.nextDouble() * area.x, rnd.nextDouble() * area.y),
        Vector2(rnd.nextDouble() * 2 - 1, rnd.nextDouble() * 2 - 1)..scale(10),
        70 + rnd.nextDouble() * 90,
        palette[rnd.nextInt(palette.length)],
      ));
    }
    for (int i = 0; i < 46; i++) {
      _stars.add(_Star(
        Offset(rnd.nextDouble() * area.x, rnd.nextDouble() * area.y),
        rnd.nextDouble() * math.pi * 2,
        1 + rnd.nextDouble() * 2.2,
        0.8 + rnd.nextDouble() * 2.0,
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    for (final o in _orbs) {
      o.pos.add(o.vel * dt);
      if (o.pos.x < -o.radius) o.pos.x = area.x + o.radius;
      if (o.pos.x > area.x + o.radius) o.pos.x = -o.radius;
      if (o.pos.y < -o.radius) o.pos.y = area.y + o.radius;
      if (o.pos.y > area.y + o.radius) o.pos.y = -o.radius;
    }
  }

  @override
  void render(Canvas canvas) {
    _renderGrid(canvas);
    for (final o in _orbs) {
      NeonFx.drawGlow(canvas, Offset(o.pos.x, o.pos.y), o.radius, o.color,
          opacity: 0.16);
    }
    _renderStars(canvas);
    canvas.drawRect(Rect.fromLTWH(0, 0, area.x, area.y), _vignette);
  }

  void _renderGrid(Canvas canvas) {
    const cells = 8;
    final stepX = area.x / cells;
    final stepY = area.y / cells;
    final paint = Paint()
      ..color = const Color(0xFF00F0FF).withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (int i = 1; i < cells; i++) {
      canvas.drawLine(Offset(stepX * i, 0), Offset(stepX * i, area.y), paint);
      canvas.drawLine(Offset(0, stepY * i), Offset(area.x, stepY * i), paint);
    }
  }

  void _renderStars(Canvas canvas) {
    for (final s in _stars) {
      final tw = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(_time * s.speed + s.phase));
      canvas.drawCircle(
        s.pos,
        s.size,
        Paint()..color = Colors.white.withValues(alpha: 0.5 * tw),
      );
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
  double _t = 0;
  late final TextPaint _paint;

  ComboTextComponent({
    required this.text,
    required this.color,
    required Vector2 position,
    this.duration = 0.9,
  }) : super(position: position, anchor: Anchor.center) {
    _paint = TextPaint(
      style: TextStyle(
        color: Colors.white,
        fontFamily: 'Orbitron',
        fontSize: 30,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        shadows: [Shadow(color: color, blurRadius: 12)],
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
    final scale = 0.6 + 0.7 * Curves.elasticOut.transform(p.clamp(0.0, 0.6) / 0.6);
    final op = p < 0.7 ? 1.0 : (1 - (p - 0.7) / 0.3);
    canvas.save();
    canvas.scale(scale);
    final m = _paint.getLineMetrics(text);
    final tp = TextPaint(
      style: _paint.style.copyWith(color: Colors.white.withValues(alpha: op)),
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

import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

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
        ..color = color.withValues(alpha: op)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // vòng trong sáng hơn
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
        fontSize: 30,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        shadows: [
          Shadow(color: color, blurRadius: 18),
          Shadow(color: color, blurRadius: 8),
        ],
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt / duration;
    position.y -= 36 * dt; // bay lên
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
    _paintWithOpacity(canvas, op, Offset(-m.width / 2, -m.height / 2));
    canvas.restore();
  }

  void _paintWithOpacity(Canvas canvas, double op, Offset offset) {
    final tp = TextPaint(
      style: _paint.style.copyWith(
        color: Colors.white.withValues(alpha: op),
      ),
    );
    tp.render(canvas, text, Vector2(offset.dx, offset.dy));
  }
}

/// Một quả cầu sáng trôi nổi trong nền.
class _Orb {
  Vector2 pos;
  Vector2 vel;
  double radius;
  Color color;
  _Orb(this.pos, this.vel, this.radius, this.color);
}

/// Nền neon động: các quả cầu sáng trôi chậm, wrap quanh màn hình. Không leak
/// (số lượng cố định, không tạo/huỷ component con).
class AmbientNeon extends PositionComponent {
  final Vector2 area;
  final List<Color> palette;
  final math.Random rnd;
  final List<_Orb> _orbs = [];

  AmbientNeon({required this.area, required this.palette, required this.rnd}) {
    for (int i = 0; i < 14; i++) {
      _orbs.add(_Orb(
        Vector2(rnd.nextDouble() * area.x, rnd.nextDouble() * area.y),
        Vector2(rnd.nextDouble() * 2 - 1, rnd.nextDouble() * 2 - 1)..scale(12),
        30 + rnd.nextDouble() * 60,
        palette[rnd.nextInt(palette.length)],
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
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
    for (final o in _orbs) {
      canvas.drawCircle(
        Offset(o.pos.x, o.pos.y),
        o.radius,
        Paint()
          ..color = o.color.withValues(alpha: 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
      );
    }
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
    final op = math.sin(p * math.pi); // sáng giữa, tắt 2 đầu
    final w = 3 + 10 * op;
    canvas.drawLine(
      Offset(from.x, from.y),
      Offset(to.x, to.y),
      Paint()
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: op)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
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

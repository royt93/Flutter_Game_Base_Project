import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:roy_casual_kit/presentation/game/tiled_terrain_collision.dart';

/// Something a bullet can damage. Bullets ray-march in 4px steps and test
/// [hitRect] on every step, so fast shots cannot tunnel through.
abstract interface class ArenaHittable {
  Rect get hitRect;
  bool get alive;
  void takeHit();
}

/// Static training target: 3 HP, flashes on hit, respawns 3s after it dies.
class ArenaTarget extends PositionComponent implements ArenaHittable {
  ArenaTarget({required Vector2 position, this.onHit, this.onDestroyed})
    : super(position: position, size: Vector2.all(40), anchor: Anchor.center);

  static const maxHp = 3;
  static const respawnSeconds = 3.0;
  static const _flashSeconds = 0.08;

  final void Function(ArenaTarget target)? onHit;
  final void Function(ArenaTarget target)? onDestroyed;

  int hp = maxHp;
  double _flash = 0;
  double _respawn = 0;

  @override
  bool get alive => hp > 0;

  @override
  Rect get hitRect => Rect.fromCenter(
    center: Offset(position.x, position.y),
    width: size.x,
    height: size.y,
  );

  void reset() {
    hp = maxHp;
    _flash = 0;
    _respawn = 0;
  }

  @override
  void takeHit() {
    if (!alive) return;
    hp--;
    _flash = _flashSeconds;
    onHit?.call(this);
    if (!alive) {
      _respawn = respawnSeconds;
      onDestroyed?.call(this);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flash > 0) _flash -= dt;
    if (!alive) {
      _respawn -= dt;
      if (_respawn <= 0) hp = maxHp;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!alive) return;
    final c = Offset(size.x / 2, size.y / 2);
    final flashing = _flash > 0;
    final rings = [
      (size.x / 2, const Color(0xffe53935)),
      (size.x / 3, const Color(0xffffffff)),
      (size.x / 6, const Color(0xff26c6da)),
    ];
    for (final (radius, color) in rings) {
      canvas.drawCircle(
        c,
        radius,
        Paint()..color = flashing ? const Color(0xffffffff) : color,
      );
    }
    // Remaining HP pips under the target.
    for (var i = 0; i < hp; i++) {
      canvas.drawCircle(
        Offset(c.dx + (i - 1) * 8, size.y + 4),
        2.5,
        Paint()..color = const Color(0xffffeb3b),
      );
    }
  }
}

/// Slow chaser: 2 HP, walks toward [chase] one axis at a time in small steps so
/// it slides along walls instead of sticking or tunnelling. Contact knocks the
/// monster back and reports a hit to its owner.
class ArenaMonster extends PositionComponent implements ArenaHittable {
  ArenaMonster({
    required Vector2 position,
    required this.chase,
    required this.terrain,
    this.onHit,
    this.onDestroyed,
    this.onTouchPlayer,
    this.respawnSeconds = 4.0,
    this.speed = ArenaMonster.baseSpeed,
  }) : super(position: position, size: Vector2.all(28), anchor: Anchor.center);

  static const maxHp = 2;
  static const baseSpeed = 60.0;
  static const defaultRespawnSeconds = 4.0;
  static const touchCooldownSeconds = 0.1;
  static const knockback = 36.0;

  final Vector2 Function() chase;
  final List<TerrainCollider> terrain;
  final void Function(ArenaMonster m)? onHit;
  final void Function(ArenaMonster m)? onDestroyed;
  final void Function(ArenaMonster m)? onTouchPlayer;
  final double respawnSeconds;
  final double speed;

  late final Vector2 home = position.clone();
  int hp = maxHp;
  double _respawn = 0;
  double _touchCooldown = 0;
  double _flash = 0;

  @override
  bool get alive => hp > 0;

  @override
  Rect get hitRect => _rectAt(position);

  Rect _rectAt(Vector2 c) =>
      Rect.fromCenter(center: Offset(c.x, c.y), width: size.x, height: size.y);

  bool _blockedAt(Vector2 c) {
    final r = _rectAt(c);
    return terrain.any((t) => terrainColliderOverlapsRect(t, r));
  }

  /// Moves [delta] in <=4px sub-steps, X then Y, stopping each axis at a wall.
  void _move(Vector2 delta) {
    final steps = (delta.length / 4).ceil().clamp(1, 4096);
    final step = delta / steps.toDouble();
    for (var i = 0; i < steps; i++) {
      final cx = Vector2(position.x + step.x, position.y);
      if (!_blockedAt(cx)) position.x = cx.x;
      final cy = Vector2(position.x, position.y + step.y);
      if (!_blockedAt(cy)) position.y = cy.y;
    }
  }

  void reset() {
    hp = maxHp;
    _respawn = 0;
    _touchCooldown = 0;
    _flash = 0;
    position.setFrom(home);
  }

  @override
  void takeHit() {
    if (!alive) return;
    hp--;
    _flash = 0.08;
    onHit?.call(this);
    if (!alive) {
      _respawn = respawnSeconds;
      onDestroyed?.call(this);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flash > 0) _flash -= dt;
    if (!alive) {
      if (respawnSeconds <= 0) return;
      _respawn -= dt;
      if (_respawn <= 0) {
        hp = maxHp;
        position.setFrom(home);
      }
      return;
    }
    if (_touchCooldown > 0) _touchCooldown -= dt;
    final player = chase();
    final to = player - position;
    final dist = to.length;
    final touching = hitRect.inflate(10).contains(Offset(player.x, player.y));
    if (touching && _touchCooldown <= 0) {
      _touchCooldown = touchCooldownSeconds;
      if (dist > 0) _move(-to / dist * knockback);
      onTouchPlayer?.call(this);
      return;
    }
    if (dist > 0) _move(to / dist * speed * dt);
  }

  @override
  void render(Canvas canvas) {
    if (!alive) return;
    final c = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(
      c,
      size.x / 2,
      Paint()
        ..color = _flash > 0
            ? const Color(0xffffffff)
            : const Color(0xff66bb6a),
    );
    for (final dx in [-5.0, 5.0]) {
      canvas.drawCircle(
        c.translate(dx, -3),
        3,
        Paint()..color = const Color(0xff1b5e20),
      );
    }
    canvas.drawArc(
      Rect.fromCenter(center: c.translate(0, 5), width: 12, height: 8),
      0,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xff1b5e20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

/// Breakable crate: 1 HP, blocks movement until it breaks, never respawns in a
/// session. Its [collider] lives in the shared terrain list while it stands.
class ArenaCrate extends PositionComponent implements ArenaHittable {
  ArenaCrate({required Vector2 position, this.onBroken})
    : collider = TerrainRectangle(position - Vector2.all(16), Vector2.all(32)),
      super(position: position, size: Vector2.all(32), anchor: Anchor.center);

  final TerrainRectangle collider;
  final void Function(ArenaCrate crate)? onBroken;
  bool _alive = true;

  @override
  bool get alive => _alive;

  @override
  Rect get hitRect => Rect.fromLTWH(
    collider.position.x,
    collider.position.y,
    collider.size.x,
    collider.size.y,
  );

  @override
  void takeHit() {
    if (!_alive) return;
    _alive = false;
    onBroken?.call(this);
  }

  @override
  void render(Canvas canvas) {
    if (!_alive) return;
    final r = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(r, Paint()..color = const Color(0xffc68642));
    canvas.drawRect(
      r.deflate(2),
      Paint()
        ..color = const Color(0xff7b4a1e)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final brace = Paint()
      ..color = const Color(0xff7b4a1e)
      ..strokeWidth = 3;
    canvas.drawLine(r.topLeft, r.bottomRight, brace);
    canvas.drawLine(r.topRight, r.bottomLeft, brace);
  }
}

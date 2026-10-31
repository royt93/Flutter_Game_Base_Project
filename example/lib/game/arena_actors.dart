import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:roy_casual_kit/presentation/game/tiled_terrain_collision.dart';

/// Something a bullet can damage. Bullets ray-march in 4px steps and test
/// [hitRect] on every step, so fast shots cannot tunnel through.
abstract interface class ArenaHittable {
  Rect get hitRect;
  bool get alive;
  void takeHit({int damage = 1});
}

enum ArenaPickupKind { heal, rapidFire }

class ArenaPickup extends PositionComponent {
  static const expirySeconds = 8.0;

  ArenaPickup({
    required Vector2 position,
    required this.kind,
    required this.onExpired,
    required this.onCollected,
    this.lifetime = expirySeconds,
  }) : super(position: position, size: Vector2.all(48), anchor: Anchor.center);

  final ArenaPickupKind kind;
  final VoidCallback onExpired;
  final ValueChanged<ArenaPickupKind> onCollected;
  double lifetime;
  bool _finished = false;

  Rect get hitRect => Rect.fromCenter(
    center: Offset(position.x, position.y),
    width: size.x,
    height: size.y,
  );

  void collect() {
    if (_finished) return;
    _finished = true;
    onCollected(kind);
    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_finished) return;
    lifetime -= dt;
    if (lifetime <= 0) {
      _finished = true;
      onExpired();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final heal = kind == ArenaPickupKind.heal;
    final color = heal ? const Color(0xffe85d75) : const Color(0xffffca28);
    final center = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(center, size.x / 2, Paint()..color = color);
    canvas.drawCircle(
      center,
      size.x / 2 - 3,
      Paint()
        ..color = const Color(0xffffffff)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final paint = Paint()
      ..color = const Color(0xffffffff)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    if (heal) {
      canvas.drawLine(center.translate(-9, 0), center.translate(9, 0), paint);
      canvas.drawLine(center.translate(0, -9), center.translate(0, 9), paint);
    } else {
      canvas.drawCircle(center, 5, paint..style = PaintingStyle.fill);
      canvas.drawLine(
        center.translate(0, -14),
        center.translate(0, -7),
        paint..style = PaintingStyle.stroke,
      );
      canvas.drawLine(center.translate(-3, 14), center.translate(-3, 7), paint);
      canvas.drawLine(center.translate(3, 14), center.translate(3, 7), paint);
    }
  }
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
  void takeHit({int damage = 1}) {
    if (!alive) return;
    hp = math.max(0, hp - damage);
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

enum _BossState { approach, telegraph, charge }

/// Chases [chase] in small wall-safe steps; bosses telegraph and charge.
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
    int? maxHp,
    this.isBoss = false,
    this.contactDamage = 1,
  }) : maxHp = maxHp ?? (isBoss ? bossHp : baseHp),
       super(
         position: position,
         size: Vector2.all(isBoss ? 56 : 28),
         anchor: Anchor.center,
       ) {
    hp = this.maxHp;
  }

  static const baseHp = 2;
  static const bossHp = 8;
  static const baseSpeed = 60.0;
  static const bossSpeed = 32.0;
  static const bossTelegraphSeconds = 1.0;
  static const bossChargeSeconds = 0.45;
  static const bossChargeSpeed = 160.0;
  static const bossChargeDamage = 2;

  final int maxHp;
  final bool isBoss;
  final int contactDamage;
  bool get isCharging => _bossState == _BossState.charge;
  bool get isTelegraphing => _bossState == _BossState.telegraph;
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
  int hp = 0;
  double _respawn = 0;
  _BossState _bossState = _BossState.approach;
  double _bossStateTimer = 0;
  Vector2 _chargeDirection = Vector2.zero();
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

  bool _touchesPlayer(Vector2 player, double padding) =>
      hitRect.inflate(padding).contains(Offset(player.x, player.y));

  bool _moveCharge(Vector2 delta, Vector2 player) {
    final steps = (delta.length / 4).ceil().clamp(1, 4096);
    final step = delta / steps.toDouble();
    for (var i = 0; i < steps; i++) {
      final candidateX = Vector2(position.x + step.x, position.y);
      if (!_blockedAt(candidateX)) position.x = candidateX.x;
      final candidateY = Vector2(position.x, position.y + step.y);
      if (!_blockedAt(candidateY)) position.y = candidateY.y;
      if (_touchesPlayer(player, 14)) return true;
    }
    return false;
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
    _bossState = _BossState.approach;
    _bossStateTimer = 0;
    _chargeDirection = Vector2.zero();
    position.setFrom(home);
  }

  @override
  void takeHit({int damage = 1}) {
    if (!alive) return;
    hp = math.max(0, hp - damage);
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
    if (isBoss) {
      _updateBoss(dt, to, dist);
    } else {
      _moveTowardPlayer(player, to, dist, speed * dt);
    }
  }

  void _updateBoss(double dt, Vector2 toPlayer, double distance) {
    _bossStateTimer += dt;
    switch (_bossState) {
      case _BossState.approach:
        if (distance > 0) _move(toPlayer / distance * speed * dt);
        if (distance <= 180) {
          _chargeDirection = distance > 0 ? toPlayer / distance : Vector2(1, 0);
          _bossState = _BossState.telegraph;
          _bossStateTimer = 0;
        }
      case _BossState.telegraph:
        if (_bossStateTimer >= bossTelegraphSeconds) {
          _bossState = _BossState.charge;
          _bossStateTimer = 0;
        }
      case _BossState.charge:
        final player = chase();
        final touched = _moveCharge(
          _chargeDirection * bossChargeSpeed * dt,
          player,
        );
        if (touched && _touchCooldown <= 0) {
          _touchCooldown = touchCooldownSeconds;
          onTouchPlayer?.call(this);
          _bossState = _BossState.approach;
          _bossStateTimer = 0;
        } else if (_bossStateTimer >= bossChargeSeconds) {
          _bossState = _BossState.approach;
          _bossStateTimer = 0;
        }
    }
  }

  void _moveTowardPlayer(
    Vector2 player,
    Vector2 toPlayer,
    double distance,
    double delta,
  ) {
    final touching = hitRect.inflate(10).contains(Offset(player.x, player.y));
    if (touching && _touchCooldown <= 0) {
      _touchCooldown = touchCooldownSeconds;
      if (distance > 0) _move(-toPlayer / distance * knockback);
      onTouchPlayer?.call(this);
      return;
    }
    if (distance > 0) _move(toPlayer / distance * delta);
  }

  @override
  void render(Canvas canvas) {
    if (!alive) return;
    final c = Offset(size.x / 2, size.y / 2);
    final bossTelegraphing = isBoss && _bossState == _BossState.telegraph;
    canvas.drawCircle(
      c,
      size.x / 2,
      Paint()
        ..color = _flash > 0
            ? const Color(0xffffffff)
            : isBoss
            ? const Color(0xff8e24aa)
            : const Color(0xff66bb6a),
    );
    if (isBoss) {
      canvas.drawCircle(
        c,
        size.x / 2 - 3,
        Paint()
          ..color = bossTelegraphing
              ? const Color(0xffff1744)
              : const Color(0xffffca28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = bossTelegraphing
              ? 3 + 2 * (0.5 + 0.5 * math.sin(_bossStateTimer * 10))
              : 3,
      );
      if (bossTelegraphing || isCharging) {
        final markerPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          c,
          c.translate(
            _chargeDirection.x * size.x * 0.48,
            _chargeDirection.y * size.y * 0.48,
          ),
          markerPaint,
        );
      }
    }
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
  void takeHit({int damage = 1}) {
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

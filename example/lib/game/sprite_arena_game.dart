import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/experimental.dart';
import 'package:flutter/foundation.dart';
import 'package:roy_casual_kit/presentation/game/roy_game.dart';
import 'package:roy_casual_kit/presentation/game/tiled_terrain_collision.dart';

class SpriteArenaGame extends RoyGame {
  SpriteArenaGame()
    : super(
        showClassicDemo: false,
        enablePlayableCharacter: true,
        arenaMapFileName: 'character_arena.tmx',
      );

  final attackEnabled = ValueNotifier(false);
  final _bullets = <ArenaBullet>{};
  bool _ready = false;

  @override
  void pauseEngine() {
    super.pauseEngine();
    attackEnabled.value = false;
  }

  @override
  void resumeEngine() {
    super.resumeEngine();
    attackEnabled.value = _ready;
  }

  void attack() {
    if (attackEnabled.value) player!.attack();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await Future.wait([arenaLoad!, playerLoad!]);
    player!.setSprites(
      idle: await loadSprite('survivor1_gun.png'),
      attack: await loadSprite('survivor1_machine.png'),
    );
    player!.position.setValues(480, 480);
    player!.onAttack = _shoot;
    camera.viewfinder.anchor = Anchor.center;
    camera.follow(player!, snap: true);
    camera.setBounds(
      Rectangle.fromLTWH(0, 0, arena!.width, arena!.height),
      considerViewport: true,
    );
    _ready = true;
    attackEnabled.value = !paused;
  }

  void _shoot() {
    if (!attackEnabled.value || _bullets.length >= 24) return;
    final player = this.player!;
    // Sprite barrel tip is (50, 31), relative to its (25.5, 21.5) pivot.
    final muzzle = Vector2(24.5, 9.5)..rotate(player.angle);
    final bullet = ArenaBullet(
      position: player.position + muzzle,
      direction: Vector2(math.cos(player.angle), math.sin(player.angle)),
      terrain: terrainColliders,
      onImpact: (at) => spawnSparkleBurst(at, count: 5),
      onRemoved: _bullets.remove,
    );
    _bullets.add(bullet);
    world.add(bullet);
  }
}

class ArenaBullet extends PositionComponent {
  ArenaBullet({
    required Vector2 position,
    required this.direction,
    required this.terrain,
    this.onImpact,
    this.onRemoved,
  }) : super(position: position, size: Vector2(14, 5), anchor: Anchor.center) {
    angle = math.atan2(direction.y, direction.x);
  }

  final Vector2 direction;
  final List<TerrainCollider> terrain;
  final void Function(Vector2 at)? onImpact;
  final void Function(ArenaBullet bullet)? onRemoved;

  @override
  void onRemove() {
    onRemoved?.call(this);
    super.onRemove();
  }

  double _remaining = 1.2;
  final _paint = Paint()..color = const Color(0xffffeb3b);

  @override
  void update(double dt) {
    super.update(dt);
    final travel = 560 * math.min(dt, _remaining);
    _remaining -= dt;
    final steps = (travel / 4).ceil().clamp(1, 4096);
    for (var i = 0; i < steps; i++) {
      final hitbox = Rect.fromCenter(
        center: Offset(position.x, position.y),
        width: 6,
        height: 6,
      );
      if (terrain.any(
        (collider) => terrainColliderOverlapsRect(collider, hitbox),
      )) {
        onImpact?.call(position.clone());
        removeFromParent();
        return;
      }
      position += direction * (travel / steps);
    }
    if (_remaining <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(2.5)),
      _paint,
    );
  }
}

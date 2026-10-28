import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/experimental.dart';
import 'package:flutter/foundation.dart';
import 'package:roy_casual_kit/core/audio_manager.dart';
import 'package:roy_casual_kit/core/haptics.dart';
import 'package:roy_casual_kit/presentation/widgets/common/game_joystick.dart';
import 'package:roy_casual_kit/presentation/game/roy_game.dart';
import 'package:roy_casual_kit/presentation/game/tiled_terrain_collision.dart';

import 'arena_actors.dart';

enum ArenaPhase { loading, playing, paused, failed }

class SpriteArenaGame extends RoyGame {
  SpriteArenaGame()
    : super(
        showClassicDemo: false,
        enablePlayableCharacter: true,
        arenaMapFileName: 'character_arena.tmx',
      );

  final phase = ValueNotifier(ArenaPhase.loading);
  bool get attackEnabled => phase.value == ArenaPhase.playing;
  final score = ValueNotifier(0);
  final targets = <ArenaTarget>[];
  final monsters = <ArenaMonster>[];
  final crates = <ArenaCrate>[];
  final _bullets = <ArenaBullet>{};
  bool _ready = false;

  static const _targetSpots = [
    (220.0, 400.0),
    (720.0, 360.0),
    (900.0, 700.0),
    (520.0, 820.0),
    (1240.0, 480.0),
    (1180.0, 900.0),
  ];

  @override
  void pauseEngine() {
    super.pauseEngine();
    player?.setMoveInput(GameJoystickDirection.idle, Offset.zero);
    if (_ready && phase.value != ArenaPhase.failed) {
      phase.value = ArenaPhase.paused;
    }
  }

  @override
  void resumeEngine() {
    super.resumeEngine();
    if (phase.value != ArenaPhase.failed) {
      phase.value = _ready ? ArenaPhase.playing : ArenaPhase.loading;
    }
  }

  void attack() {
    if (attackEnabled) player!.attack();
  }

  @override
  Future<void> onLoad() async {
    try {
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
      _spawnTargets();
      _spawnMonsters();
      _spawnCrates();
      _ready = true;
      phase.value = paused ? ArenaPhase.paused : ArenaPhase.playing;
    } catch (_) {
      phase.value = ArenaPhase.failed;
      rethrow;
    }
  }

  void _spawnTargets() {
    final start = player!.position;
    for (final (x, y) in _targetSpots) {
      final spot = Vector2(x, y);
      final box = Rect.fromCenter(center: Offset(x, y), width: 48, height: 48);
      final blocked = terrainColliders.any(
        (c) => terrainColliderOverlapsRect(c, box),
      );
      if (blocked || spot.distanceTo(start) < 96) continue;
      final target = ArenaTarget(
        position: spot,
        onHit: (t) {
          AudioManager.maybe?.playSfx('audio/tap.ogg', volume: 0.4);
        },
        onDestroyed: (t) {
          spawnSparkleBurst(t.position.clone(), count: 12);
          fireHaptic(HapticLevel.light);
          AudioManager.maybe?.playSfx('audio/victory.ogg', volume: 0.5);
          score.value += 10;
        },
      );
      targets.add(target);
      world.add(target);
    }
  }

  static const _monsterSpots = [
    (1100.0, 300.0),
    (300.0, 900.0),
    (1300.0, 1000.0),
  ];

  void _spawnMonsters() {
    final start = player!.position;
    for (final (x, y) in _monsterSpots) {
      final spot = Vector2(x, y);
      final box = Rect.fromCenter(center: Offset(x, y), width: 36, height: 36);
      final blocked = terrainColliders.any(
        (c) => terrainColliderOverlapsRect(c, box),
      );
      if (blocked || spot.distanceTo(start) < 200) continue;
      final monster = ArenaMonster(
        position: spot,
        chase: () => player!.position,
        terrain: terrainColliders,
        onHit: (m) {
          AudioManager.maybe?.playSfx('audio/tap.ogg', volume: 0.4);
        },
        onDestroyed: (m) {
          spawnSparkleBurst(m.position.clone(), count: 12);
          fireHaptic(HapticLevel.light);
          AudioManager.maybe?.playSfx('audio/victory.ogg', volume: 0.5);
          score.value += 25;
        },
        onTouchPlayer: (m) => fireHaptic(HapticLevel.light),
      );
      monsters.add(monster);
      world.add(monster);
    }
  }

  static const _crateSpots = [
    (360.0, 520.0),
    (640.0, 640.0),
    (980.0, 520.0),
    (760.0, 960.0),
    (1380.0, 700.0),
  ];

  void _spawnCrates() {
    final keepClear = <Rect>[
      Rect.fromCircle(
        center: Offset(player!.position.x, player!.position.y),
        radius: 96,
      ),
      for (final t in targets) t.hitRect.inflate(16),
      for (final m in monsters) m.hitRect.inflate(48),
    ];
    for (final (x, y) in _crateSpots) {
      final crate = ArenaCrate(
        position: Vector2(x, y),
        onBroken: (c) {
          terrainColliders.remove(c.collider);
          spawnSparkleBurst(c.position.clone(), count: 8);
          fireHaptic(HapticLevel.light);
          AudioManager.maybe?.playSfx('audio/tap.ogg', volume: 0.5);
          score.value += 5;
        },
      );
      final box = crate.hitRect;
      final blocked =
          terrainColliders.any((c) => terrainColliderOverlapsRect(c, box)) ||
          keepClear.any((k) => k.overlaps(box));
      if (blocked) continue;
      crates.add(crate);
      terrainColliders.add(crate.collider);
      world.add(crate);
    }
  }

  void _shoot() {
    if (!attackEnabled || _bullets.length >= 24) return;
    final player = this.player!;
    // Sprite barrel tip is (50, 31), relative to its (25.5, 21.5) pivot.
    final muzzle = Vector2(24.5, 9.5)..rotate(player.angle);
    final bullet = ArenaBullet(
      position: player.position + muzzle,
      direction: Vector2(math.cos(player.angle), math.sin(player.angle)),
      terrain: terrainColliders,
      hittables: () => [...targets, ...monsters, ...crates],
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
    this.hittables,
    this.onImpact,
    this.onRemoved,
  }) : super(position: position, size: Vector2(14, 5), anchor: Anchor.center) {
    angle = math.atan2(direction.y, direction.x);
  }

  final Vector2 direction;
  final List<TerrainCollider> terrain;
  final Iterable<ArenaHittable> Function()? hittables;
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
      ArenaHittable? victim;
      for (final h in hittables?.call() ?? const <ArenaHittable>[]) {
        if (h.alive && h.hitRect.overlaps(hitbox)) {
          victim = h;
          break;
        }
      }
      if (victim != null) {
        victim.takeHit();
        onImpact?.call(position.clone());
        removeFromParent();
        return;
      }
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

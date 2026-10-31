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

enum ArenaPhase { loading, playing, paused, gameOver, failed }

enum ArenaObjectiveId { defeatBossWave5, surviveWith3Lives, reachScore500 }

class ArenaObjective {
  const ArenaObjective({
    required this.id,
    required this.titleKey,
    required this.target,
    required this.progress,
    required this.completed,
    required this.bonusScore,
  });

  final ArenaObjectiveId id;
  final String titleKey;
  final int target;
  final int progress;
  final bool completed;
  final int bonusScore;

  ArenaObjective copyWith({int? progress, bool? completed}) => ArenaObjective(
    id: id,
    titleKey: titleKey,
    target: target,
    progress: progress ?? this.progress,
    completed: completed ?? this.completed,
    bonusScore: bonusScore,
  );
}

class SpriteArenaGame extends RoyGame {
  SpriteArenaGame({double Function()? pickupRoll})
    : _pickupRoll = pickupRoll ?? math.Random().nextDouble,
      super(
        showClassicDemo: false,
        enablePlayableCharacter: true,
        arenaMapFileName: 'character_arena.tmx',
      );

  final double Function() _pickupRoll;
  final phase = ValueNotifier(ArenaPhase.loading);
  bool get attackEnabled => phase.value == ArenaPhase.playing;
  final score = ValueNotifier(0);
  final lives = ValueNotifier(4);
  final wave = ValueNotifier(1);
  final roundOver = ValueNotifier(false);
  final targets = <ArenaTarget>[];
  final monsters = <ArenaMonster>[];
  final crates = <ArenaCrate>[];
  ArenaPickup? pickup;
  final rapidFireRemaining = ValueNotifier<double>(0);
  final pickupRemaining = ValueNotifier<double>(0);
  final bossHp = ValueNotifier<int?>(null);

  static List<ArenaObjective> get _initialObjectives => const [
    ArenaObjective(
      id: ArenaObjectiveId.defeatBossWave5,
      titleKey: 'sprite_arena_obj_boss_w5',
      target: 1,
      progress: 0,
      completed: false,
      bonusScore: 150,
    ),
    ArenaObjective(
      id: ArenaObjectiveId.surviveWith3Lives,
      titleKey: 'sprite_arena_obj_survive_lives',
      target: 1,
      progress: 0,
      completed: false,
      bonusScore: 100,
    ),
    ArenaObjective(
      id: ArenaObjectiveId.reachScore500,
      titleKey: 'sprite_arena_obj_score_500',
      target: 500,
      progress: 0,
      completed: false,
      bonusScore: 200,
    ),
  ];

  late final objectives = ValueNotifier<List<ArenaObjective>>(
    _initialObjectives,
  );
  int get completedObjectivesCount =>
      objectives.value.where((o) => o.completed).length;

  /// Phase 2 hook: called when boss wave 5 clears so UI can show upgrade selection.
  VoidCallback? onBossWaveCleared;

  final _bullets = <ArenaBullet>{};
  bool _ready = false;
  final _mapColliders = <TerrainCollider>[];
  double _damageCooldown = 0;
  bool _damagedThisUpdate = false;
  double _spawnCooldown = 0;
  bool _fireHeld = false;
  double _fireCooldown = 0;
  int _waveSize = 2;
  int _spawnedThisWave = 0;
  int _spawnCursor = 0;

  int get waveSize => _waveSize;
  bool get isBossWave => wave.value % 5 == 0;
  int get _waveMonsterCount => isBossWave ? 1 : _waveSize;
  static const activeMonsterCap = 3;
  static const spawnInterval = 1.2;
  static const playerMaxLives = 4;
  static const playerInvulnerabilitySeconds = 1.25;
  static const rapidFireDuration = 5.0;
  static const normalFireInterval = 0.2;
  static const rapidFireInterval = 0.08;
  static const pickupDropChance = 0.5;

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
    stopFiring();
    super.pauseEngine();
    player?.setMoveInput(GameJoystickDirection.idle, Offset.zero);
    if (_ready && phase.value == ArenaPhase.playing) {
      phase.value = ArenaPhase.paused;
    }
  }

  @override
  void resumeEngine() {
    if (roundOver.value || phase.value == ArenaPhase.failed) return;
    super.resumeEngine();
    if (phase.value == ArenaPhase.paused || phase.value == ArenaPhase.loading) {
      phase.value = _ready ? ArenaPhase.playing : ArenaPhase.loading;
    }
  }

  void attack() {
    fireOnce();
  }

  void startFiring() {
    if (!attackEnabled) return;
    _fireHeld = true;
    _fireOnce();
    _fireCooldown = fireInterval;
  }

  bool get isFiring => _fireHeld;

  void stopFiring() {
    _fireHeld = false;
    _fireCooldown = 0;
  }

  void cancelHeldFire() => stopFiring();

  void fireOnce() {
    if (attackEnabled) _fireOnce();
  }

  void _fireOnce() {
    if (!attackEnabled) return;
    player!.attack();
  }

  double get fireInterval =>
      rapidFireRemaining.value > 0 ? rapidFireInterval : normalFireInterval;

  void _tryDropPickup(Vector2 at) {
    if (_pickupRoll() >= pickupDropChance) return;
    final kind = _pickupRoll() < 0.5
        ? ArenaPickupKind.heal
        : ArenaPickupKind.rapidFire;
    spawnPickup(kind, at);
  }

  void spawnPickup(ArenaPickupKind kind, Vector2 at) {
    pickup?.removeFromParent();
    late final ArenaPickup created;
    created = ArenaPickup(
      position: at.clone(),
      kind: kind,
      onExpired: () {
        if (identical(pickup, created)) {
          pickup = null;
          pickupRemaining.value = 0;
        }
      },
      onCollected: (collectedKind) {
        if (identical(pickup, created)) {
          pickup = null;
          pickupRemaining.value = 0;
        }
        applyPickup(collectedKind);
      },
    );
    pickup = created;
    pickupRemaining.value = created.lifetime;
    world.add(created);
  }

  void _clearPickup() {
    pickup?.removeFromParent();
    pickup = null;
    pickupRemaining.value = 0;
  }

  void applyPickup(ArenaPickupKind kind) {
    if (kind == ArenaPickupKind.heal && lives.value < playerMaxLives) {
      lives.value++;
    } else {
      rapidFireRemaining.value = rapidFireDuration;
    }
  }

  void _completeObjective(ArenaObjectiveId id) {
    if (roundOver.value) return;
    final list = List<ArenaObjective>.from(objectives.value);
    final idx = list.indexWhere((o) => o.id == id);
    if (idx == -1 || list[idx].completed) return;

    final target = list[idx].target;
    final obj = list[idx].copyWith(progress: target, completed: true);
    list[idx] = obj;
    objectives.value = list;

    score.value += obj.bonusScore;
    fireHaptic(HapticLevel.medium);
    AudioManager.maybe?.playSfx('audio/victory.ogg', volume: 0.6);
  }

  void _onScoreChanged() {
    if (roundOver.value) return;
    final list = List<ArenaObjective>.from(objectives.value);
    final idx = list.indexWhere((o) => o.id == ArenaObjectiveId.reachScore500);
    if (idx == -1 || list[idx].completed) return;

    final target = list[idx].target;
    final current = score.value;
    final prog = math.min(current, target);
    if (prog >= target) {
      _completeObjective(ArenaObjectiveId.reachScore500);
    } else if (prog != list[idx].progress) {
      list[idx] = list[idx].copyWith(progress: prog);
      objectives.value = list;
    }
  }

  @override
  Future<void> onLoad() async {
    score.addListener(_onScoreChanged);
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
      _mapColliders.addAll(terrainColliders);
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

  @override
  void onRemove() {
    score.removeListener(_onScoreChanged);
    super.onRemove();
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
    _spawnedThisWave = 0;
    _spawnCursor = 0;
    _spawnCooldown = 0;
    while (_spawnedThisWave < math.min(_waveMonsterCount, activeMonsterCap) &&
        _spawnNextMonster()) {}
    if (_spawnedThisWave < _waveMonsterCount) {
      _spawnCooldown = spawnInterval;
    }
  }

  bool _spawnNextMonster() {
    final spots = _monsterSpots;
    final start = player!.position;
    for (var tries = 0; tries < spots.length; tries++) {
      final (x, y) = spots[_spawnCursor++ % spots.length];
      final spot = Vector2(x, y);
      final box = Rect.fromCenter(center: Offset(x, y), width: 36, height: 36);
      final blocked = terrainColliders.any(
        (c) => terrainColliderOverlapsRect(c, box),
      );
      final occupied = monsters.any((m) => m.alive && m.hitRect.overlaps(box));
      if (blocked || occupied || spot.distanceTo(start) < 200) continue;
      final boss = isBossWave;
      final monster = ArenaMonster(
        position: spot,
        chase: () => player!.position,
        terrain: terrainColliders,
        respawnSeconds: 0,
        speed: boss
            ? ArenaMonster.bossSpeed
            : math.min(84, ArenaMonster.baseSpeed + wave.value - 1),
        maxHp: boss ? ArenaMonster.bossHp : ArenaMonster.baseHp,
        isBoss: boss,
        contactDamage: boss ? ArenaMonster.bossChargeDamage : 1,
        onHit: (m) {
          if (m.isBoss) bossHp.value = m.hp;
          AudioManager.maybe?.playSfx('audio/tap.ogg', volume: 0.4);
        },
        onDestroyed: (m) {
          if (m.isBoss) {
            bossHp.value = 0;
            if (wave.value == 5) {
              _completeObjective(ArenaObjectiveId.defeatBossWave5);
            }
          }
          spawnSparkleBurst(m.position.clone(), count: 12);
          fireHaptic(HapticLevel.light);
          AudioManager.maybe?.playSfx('audio/victory.ogg', volume: 0.5);
          score.value += m.isBoss ? 100 : 25;
          if (m.isBoss) {
            spawnPickup(ArenaPickupKind.rapidFire, m.position);
          } else {
            _tryDropPickup(m.position);
          }
          _onMonsterDestroyed();
        },
        onTouchPlayer: (m) {
          fireHaptic(HapticLevel.light);
          _takePlayerHit(damage: m.contactDamage);
        },
      );
      monsters.add(monster);
      world.add(monster);
      if (boss) bossHp.value = monster.hp;
      _spawnedThisWave++;
      return true;
    }
    return false;
  }

  void _onMonsterDestroyed() {
    if (roundOver.value) return;
    _spawnCooldown = spawnInterval;
  }

  void _takePlayerHit({int damage = 1}) {
    if (!attackEnabled ||
        roundOver.value ||
        _damageCooldown > 0 ||
        _damagedThisUpdate) {
      return;
    }
    _damagedThisUpdate = true;
    _damageCooldown = playerInvulnerabilitySeconds;
    lives.value = math.max(0, lives.value - damage);
    if (lives.value == 0) {
      roundOver.value = true;
      _clearPickup();
      rapidFireRemaining.value = 0;
      stopFiring();
      phase.value = ArenaPhase.gameOver;
      player?.setMoveInput(GameJoystickDirection.idle, Offset.zero);
      pauseEngine();
    }
  }

  @override
  void update(double dt) {
    _damagedThisUpdate = false;
    if (attackEnabled && !roundOver.value) {
      _damageCooldown = math.max(0, _damageCooldown - dt);
      _spawnCooldown = math.max(0, _spawnCooldown - dt);
      if (pickup != null) {
        pickupRemaining.value = math.max(0, pickupRemaining.value - dt);
      }
      rapidFireRemaining.value = math.max(0, rapidFireRemaining.value - dt);
      _fireCooldown = math.max(0, _fireCooldown - dt);
      if (_fireHeld && _fireCooldown <= 0) {
        _fireOnce();
        _fireCooldown = fireInterval;
      }
    }
    super.update(dt);
    if (!attackEnabled || roundOver.value) return;
    if (pickup != null &&
        player != null &&
        pickup!.hitRect.overlaps(_playerHitRect)) {
      pickup!.collect();
    }
    if (_spawnCooldown > 0) return;
    final active = monsters.where((m) => m.alive).length;
    if (_spawnedThisWave < _waveMonsterCount && active < activeMonsterCap) {
      _spawnNextMonster();
      _spawnCooldown = spawnInterval;
    } else if (_spawnedThisWave == _waveMonsterCount && active == 0) {
      if (wave.value == 5) {
        if (lives.value >= 3) {
          _completeObjective(ArenaObjectiveId.surviveWith3Lives);
        }
        onBossWaveCleared?.call();
      }
      bossHp.value = null;
      wave.value++;
      _waveSize++;
      _spawnedThisWave = 0;
      _spawnCooldown = spawnInterval;
    }
  }

  Rect get _playerHitRect {
    final p = player!;
    return Rect.fromCenter(
      center: Offset(p.position.x, p.position.y),
      width: p.size.x * 0.5,
      height: p.size.y * 0.5,
    );
  }

  void restart() {
    if (!_ready) return;
    pauseEngine();
    pickup?.removeFromParent();
    pickup = null;
    pickupRemaining.value = 0;
    rapidFireRemaining.value = 0;
    bossHp.value = null;
    stopFiring();
    for (final bullet in _bullets.toList()) {
      bullet.removeFromParent();
    }
    for (final actor in [...monsters, ...crates]) {
      actor.removeFromParent();
    }
    for (final target in targets) {
      target.reset();
    }
    terrainColliders
      ..clear()
      ..addAll(_mapColliders);
    monsters.clear();
    crates.clear();
    player!.position.setValues(480, 480);
    player!.setMoveInput(GameJoystickDirection.idle, Offset.zero);
    score.value = 0;
    lives.value = playerMaxLives;
    wave.value = 1;
    roundOver.value = false;
    objectives.value = _initialObjectives;
    _damageCooldown = 0;
    _waveSize = 2;
    _spawnedThisWave = 0;
    _spawnCursor = 0;
    _spawnCooldown = 0;
    _spawnMonsters();
    _spawnCrates();
    phase.value = ArenaPhase.paused;
    resumeEngine();
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

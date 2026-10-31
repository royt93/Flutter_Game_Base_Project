import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roy_casual_kit/presentation/widgets/common/game_joystick.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roy_casual_kit/presentation/game/tiled_terrain_collision.dart';
import 'package:roy_casual_kit_example/game/arena_actors.dart';
import 'package:roy_casual_kit_example/game/sprite_arena_game.dart';

Future<SpriteArenaGame> loadArenaInto(
  WidgetTester tester,
  SpriteArenaGame game,
) async {
  await tester.runAsync(() async {
    rootBundle.evict('assets/tiles/character_arena.tmx');
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await Future<void>.sync(
      game.toBeLoaded,
    ).timeout(const Duration(seconds: 10));
  });
  await tester.pump();
  await tester.pump();
  return game;
}

Future<SpriteArenaGame> loadArena(WidgetTester tester) =>
    loadArenaInto(tester, SpriteArenaGame());

Future<void> advanceToWave(SpriteArenaGame game, int targetWave) async {
  for (var step = 0; step < 500 && game.wave.value < targetWave; step++) {
    for (final monster in game.monsters.where((m) => m.alive).toList()) {
      for (var hit = 0; hit < monster.hp; hit++) {
        monster.takeHit();
      }
    }
    game.update(SpriteArenaGame.spawnInterval);
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.put(
      StorageService(await SharedPreferences.getInstance()),
      permanent: true,
    );
  });
  tearDown(Get.reset);

  testWidgets('bullet moves in its facing direction and expires', (
    tester,
  ) async {
    final game = FlameGame();
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await game.toBeLoaded();
    final bullet = ArenaBullet(
      position: Vector2(80, 80),
      direction: Vector2(1, 0),
      terrain: [],
    );
    game.world.add(bullet);
    await tester.pump();
    await tester.pump();
    bullet.update(0.1);
    expect(bullet.position.x, closeTo(136, 0.001));
    expect(bullet.position.y, 80);
    bullet.update(1.2);
    await tester.pump();
    expect(game.world.children.whereType<ArenaBullet>(), isEmpty);
  });

  testWidgets('bullet cannot tunnel through a thin obstacle', (tester) async {
    final game = FlameGame();
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await game.toBeLoaded();
    final bullet = ArenaBullet(
      position: Vector2(80, 80),
      direction: Vector2(1, 0),
      terrain: [TerrainRectangle(Vector2(100, 0), Vector2(8, 200))],
    );
    game.world.add(bullet);
    await tester.pump();
    await tester.pump();
    bullet.update(0.5);
    expect(bullet.position.x, lessThanOrEqualTo(100));
    await tester.pump();
    expect(game.world.children.whereType<ArenaBullet>(), isEmpty);
  });

  testWidgets('bullet reports impact point when it hits an obstacle', (
    tester,
  ) async {
    final game = FlameGame();
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await game.toBeLoaded();
    final impacts = <Vector2>[];
    final bullet = ArenaBullet(
      position: Vector2(80, 80),
      direction: Vector2(1, 0),
      terrain: [TerrainRectangle(Vector2(100, 0), Vector2(8, 200))],
      onImpact: impacts.add,
    );
    game.world.add(bullet);
    await tester.pump();
    await tester.pump();
    bullet.update(0.5);
    expect(impacts, hasLength(1));
    expect(impacts.single.x, lessThanOrEqualTo(100));
  });

  void shootAt(SpriteArenaGame game, ArenaTarget t) {
    game.player!.position.setValues(t.position.x - 120, t.position.y);
    game.player!.angle = 0;
    game.player!.attack();
    game.update(0);
    game.update(0.3);
  }

  testWidgets('targets spawn clear of terrain and the player start', (
    tester,
  ) async {
    final game = await loadArena(tester);
    expect(game.targets, isNotEmpty);
    for (final t in game.targets) {
      expect(
        game.terrainColliders.any(
          (c) => terrainColliderOverlapsRect(c, t.hitRect),
        ),
        isFalse,
      );
      expect(t.position.distanceTo(game.player!.position), greaterThan(96));
    }
  });

  testWidgets('three hits destroy a target, score +10, respawn after 3s', (
    tester,
  ) async {
    final game = await loadArena(tester);
    final t = game.targets.first;
    shootAt(game, t);
    expect(t.hp, ArenaTarget.maxHp - 1);
    expect(game.score.value, 0);
    shootAt(game, t);
    shootAt(game, t);
    expect(t.alive, isFalse);
    expect(game.score.value, 10);
    game.update(2.9);
    expect(t.alive, isFalse);
    game.update(0.2);
    expect(t.alive, isTrue);
    expect(t.hp, ArenaTarget.maxHp);
  });

  testWidgets('a dead target is bullet-transparent and pause freezes respawn', (
    tester,
  ) async {
    final game = await loadArena(tester);
    final t = game.targets.first;
    for (var i = 0; i < 3; i++) {
      shootAt(game, t);
    }
    game.pauseEngine();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(t.alive, isFalse);
    game.resumeEngine();
    expect(t.alive, isFalse);
    shootAt(game, t);
    expect(game.score.value, 10);
  });

  testWidgets('fast bullet with a huge dt cannot tunnel through a target', (
    tester,
  ) async {
    final game = await loadArena(tester);
    final t = game.targets.first;
    game.player!.position.setValues(t.position.x - 120, t.position.y);
    game.player!.angle = 0;
    game.player!.attack();
    game.update(0);
    game.update(1.0);
    expect(t.hp, ArenaTarget.maxHp - 1);
  });

  testWidgets('monsters spawn clear of terrain and chase the player', (
    tester,
  ) async {
    final game = await loadArena(tester);
    expect(game.monsters, isNotEmpty);
    expect(game.monsters.length, lessThanOrEqualTo(3));
    for (var i = 0; i < game.monsters.length; i++) {
      final m = game.monsters[i];
      expect(
        game.terrainColliders.any(
          (c) => terrainColliderOverlapsRect(c, m.hitRect),
        ),
        isFalse,
      );
      for (var j = i + 1; j < game.monsters.length; j++) {
        expect(m.hitRect.overlaps(game.monsters[j].hitRect), isFalse);
      }
    }
    final m = game.monsters.first;
    final before = m.position.distanceTo(game.player!.position);
    for (var i = 0; i < 30; i++) {
      game.update(0.1);
    }
    expect(m.position.distanceTo(game.player!.position), lessThan(before));
  });

  testWidgets('monsters never end up inside a collider while chasing', (
    tester,
  ) async {
    final game = await loadArena(tester);
    for (var i = 0; i < 400; i++) {
      game.update(0.05);
      for (final m in game.monsters) {
        expect(
          game.terrainColliders.any(
            (c) => terrainColliderOverlapsRect(c, m.hitRect),
          ),
          isFalse,
        );
      }
    }
  });

  testWidgets('two hits remove a monster for +25 without respawning', (
    tester,
  ) async {
    final game = await loadArena(tester);
    final m = game.monsters.first;
    m.position.setValues(m.home.x, m.home.y);
    game.player!.position.setValues(m.position.x - 120, m.position.y);
    game.player!.angle = 0;
    for (var i = 0; i < 2; i++) {
      game.player!.position.setValues(m.position.x - 120, m.position.y);
      game.player!.attack();
      game.update(0);
      game.update(0.3);
    }
    expect(m.alive, isFalse);
    expect(game.score.value, 25);
    game.update(4.1);
    expect(m.alive, isFalse);
    expect(
      game.monsters.where((monster) => monster.alive).length,
      lessThanOrEqualTo(3),
    );
  });

  testWidgets('touching the player knocks the monster back with a cooldown', (
    tester,
  ) async {
    final game = await loadArena(tester);
    var touches = 0;
    final m = ArenaMonster(
      position: Vector2(600, 600),
      chase: () => game.player!.position,
      terrain: game.terrainColliders,
      onTouchPlayer: (_) => touches++,
    );
    game.world.add(m);
    await tester.pump();
    game.player!.position.setValues(612, 600);
    game.update(0.016);
    expect(touches, 1);
    expect(m.position.x, lessThan(600));
    game.update(0.016);
    expect(touches, 1);
  });

  testWidgets('survival starts with 4 lives and wave 1', (tester) async {
    final game = await loadArena(tester);
    expect(game.lives.value, 4);
    expect(game.wave.value, 1);
    expect(game.roundOver.value, isFalse);
  });

  testWidgets('drop chance is 50 percent and pickup kind is equally split', (
    tester,
  ) async {
    final rolls = <double>[0.49, 0.49, 0.49, 0.50];
    final game = SpriteArenaGame(pickupRoll: () => rolls.removeAt(0));
    await loadArenaInto(tester, game);
    final monster = game.monsters.first;
    monster.takeHit();
    monster.takeHit();
    expect(game.pickup?.kind, ArenaPickupKind.heal);
    monster.takeHit();
    expect(game.pickup?.kind, ArenaPickupKind.heal);
    final secondMonster = game.monsters.last;
    secondMonster.takeHit();
    secondMonster.takeHit();
    await tester.pump();
    expect(game.pickup?.kind, ArenaPickupKind.rapidFire);
    expect(game.pickupRemaining.value, ArenaPickup.expirySeconds);
  });

  testWidgets('drop chance at 0.5 fails without rolling a pickup kind', (
    tester,
  ) async {
    var calls = 0;
    final game = SpriteArenaGame(
      pickupRoll: () {
        calls++;
        return 0.5;
      },
    );
    await loadArenaInto(tester, game);
    final monster = game.monsters.first;
    monster.takeHit();
    monster.takeHit();
    expect(game.pickup, isNull);
    expect(calls, 1);
  });

  testWidgets('failed drop preserves existing pickup without extra kind roll', (
    tester,
  ) async {
    final rolls = <double>[0.1, 0.1, 0.5];
    final game = SpriteArenaGame(pickupRoll: () => rolls.removeAt(0));
    await loadArenaInto(tester, game);
    final first = game.monsters.first;
    first.takeHit();
    first.takeHit();
    final active = game.pickup;
    final second = game.monsters.last;
    second.takeHit();
    second.takeHit();
    expect(game.pickup, same(active));
    expect(rolls, isEmpty);
  });

  testWidgets('successful drop replaces the single active pickup', (
    tester,
  ) async {
    final rolls = <double>[0.1, 0.1, 0.1, 0.9];
    final game = SpriteArenaGame(pickupRoll: () => rolls.removeAt(0));
    await loadArenaInto(tester, game);
    final first = game.monsters.first;
    first.takeHit();
    first.takeHit();
    final oldPickup = game.pickup;
    final second = game.monsters.last;
    second.takeHit();
    second.takeHit();
    await tester.pump();
    expect(game.pickup, isNot(same(oldPickup)));
    expect(game.world.children.whereType<ArenaPickup>(), hasLength(1));
  });

  testWidgets('pickup expires and pause freezes its timer', (tester) async {
    final rolls = <double>[0, 0];
    final game = SpriteArenaGame(pickupRoll: () => rolls.removeAt(0));
    await loadArenaInto(tester, game);
    final monster = game.monsters.first;
    monster.takeHit();
    monster.takeHit();
    expect(game.pickup, isNotNull);
    game.update(3);
    expect(game.pickupRemaining.value, ArenaPickup.expirySeconds - 3);
    game.pauseEngine();
    await tester.pump(const Duration(seconds: 20));
    expect(game.pickupRemaining.value, ArenaPickup.expirySeconds - 3);
    game.resumeEngine();
    game.update(5);
    expect(game.pickup, isNull);
    expect(game.pickupRemaining.value, 0);
  });

  testWidgets('rapid-fire countdown expires and freezes during pause', (
    tester,
  ) async {
    final game = await loadArena(tester);
    game.rapidFireRemaining.value = SpriteArenaGame.rapidFireDuration;
    game.update(4.99);
    expect(game.rapidFireRemaining.value, closeTo(0.01, 0.001));
    game.pauseEngine();
    game.update(10);
    expect(game.rapidFireRemaining.value, closeTo(0.01, 0.001));
    game.resumeEngine();
    game.update(0.02);
    expect(game.rapidFireRemaining.value, 0);
  });

  testWidgets('player overlap collects pickup and removes it from world', (
    tester,
  ) async {
    final rolls = <double>[0, 0];
    final game = SpriteArenaGame(pickupRoll: () => rolls.removeAt(0));
    await loadArenaInto(tester, game);
    game.lives.value = 2;
    final monster = game.monsters.first;
    monster.takeHit();
    monster.takeHit();
    final dropped = game.pickup!;
    game.player!.position.setFrom(dropped.position);
    game.update(0.016);
    await tester.pump();
    expect(game.lives.value, 3);
    expect(game.pickup, isNull);
    expect(game.world.children.whereType<ArenaPickup>(), isEmpty);
  });

  testWidgets(
    'heal pickup caps lives and full-life heal converts to rapid fire',
    (tester) async {
      final game = await loadArenaInto(tester, SpriteArenaGame());
      game.lives.value = 2;
      game.applyPickup(ArenaPickupKind.heal);
      expect(game.lives.value, 3);
      game.lives.value = SpriteArenaGame.playerMaxLives;
      game.applyPickup(ArenaPickupKind.heal);
      expect(game.lives.value, SpriteArenaGame.playerMaxLives);
      expect(game.rapidFireRemaining.value, SpriteArenaGame.rapidFireDuration);
      game.rapidFireRemaining.value = 1;
      game.applyPickup(ArenaPickupKind.rapidFire);
      expect(game.rapidFireRemaining.value, SpriteArenaGame.rapidFireDuration);
    },
  );

  testWidgets('tap fires once and held fire uses normal then boosted cadence', (
    tester,
  ) async {
    final game = await loadArena(tester);
    var shots = 0;
    game.player!.onAttack = () => shots++;
    game.fireOnce();
    expect(shots, 1);
    game.startFiring();
    expect(shots, 2);
    game.update(SpriteArenaGame.normalFireInterval - 0.01);
    expect(shots, 2);
    game.update(0.02);
    expect(shots, 3);
    game.rapidFireRemaining.value = SpriteArenaGame.rapidFireDuration;
    game.startFiring();
    expect(shots, 4);
    game.update(SpriteArenaGame.rapidFireInterval);
    expect(shots, 5);
    game.update(1);
    expect(shots, 6);
    game.stopFiring();
    game.update(1);
    expect(shots, 6);
  });

  testWidgets('held fire remains under the 24 bullet cap', (tester) async {
    final game = await loadArena(tester);
    game.startFiring();
    for (var frame = 0; frame < 100; frame++) {
      game.update(SpriteArenaGame.rapidFireInterval);
      expect(
        game.world.children.whereType<ArenaBullet>().length,
        lessThanOrEqualTo(24),
      );
    }
    game.stopFiring();
  });

  testWidgets('pause cancels held fire until a new press', (tester) async {
    final game = await loadArena(tester);
    var shots = 0;
    game.player!.onAttack = () => shots++;
    game.startFiring();
    game.pauseEngine();
    await tester.pump(const Duration(seconds: 2));
    game.resumeEngine();
    game.update(2);
    expect(shots, 1);
  });

  testWidgets('monster contact removes one life with global invulnerability', (
    tester,
  ) async {
    final game = await loadArena(tester);
    final first = game.monsters.first;
    first.position.setFrom(game.player!.position);
    first.update(0.016);
    expect(game.lives.value, 3);
    final second = game.monsters.last;
    second.position.setFrom(game.player!.position);
    second.update(0.016);
    expect(game.lives.value, 3);
    first.position.setValues(1000, 1000);
    game.update(1.26);
    second.position.setFrom(game.player!.position);
    second.update(0.016);
    expect(game.lives.value, 2);
  });

  testWidgets('last hit ends survival and lifecycle resume cannot restart it', (
    tester,
  ) async {
    final game = await loadArena(tester);
    game.lives.value = 1;
    game.rapidFireRemaining.value = SpriteArenaGame.rapidFireDuration;
    game.startFiring();
    game.monsters.first.position.setFrom(game.player!.position);
    game.monsters.first.update(0.016);
    expect(game.lives.value, 0);
    expect(game.roundOver.value, isTrue);
    expect(game.phase.value, ArenaPhase.gameOver);
    game.lifecycleStateChange(AppLifecycleState.resumed);
    expect(game.phase.value, ArenaPhase.gameOver);
    expect(game.attackEnabled, isFalse);
    expect(game.isFiring, isFalse);
    expect(game.rapidFireRemaining.value, 0);
    game.attack();
    expect(game.world.children.whereType<ArenaBullet>(), isEmpty);
  });

  testWidgets('large frame damages player only once across monster contacts', (
    tester,
  ) async {
    final game = await loadArena(tester);
    game.player!.position.setValues(700, 700);
    for (final monster in game.monsters) {
      monster.position.setValues(700, 700);
    }
    final before = game.lives.value;
    game.update(2);
    expect(game.lives.value, before - 1);
  });

  testWidgets('wave 5 spawns a single boss while wave 4 is regular', (
    tester,
  ) async {
    final game = await loadArenaInto(
      tester,
      SpriteArenaGame(pickupRoll: () => 0.99),
    );
    for (var step = 0; step < 200 && game.wave.value < 4; step++) {
      for (final monster in game.monsters.where((m) => m.alive).toList()) {
        for (var hit = 0; hit < monster.hp; hit++) {
          monster.takeHit();
        }
      }
      game.update(SpriteArenaGame.spawnInterval);
    }
    expect(game.wave.value, 4);
    game.update(SpriteArenaGame.spawnInterval);
    expect(game.isBossWave, isFalse);
    expect(game.monsters.where((m) => m.alive), hasLength(1));
    for (var step = 0; step < 200 && game.wave.value < 5; step++) {
      for (final monster in game.monsters.where((m) => m.alive).toList()) {
        for (var hit = 0; hit < monster.hp; hit++) {
          monster.takeHit();
        }
      }
      game.update(SpriteArenaGame.spawnInterval);
    }
    expect(game.wave.value, 5);
    game.update(SpriteArenaGame.spawnInterval);
    final active = game.monsters.where((m) => m.alive).toList();
    expect(active, hasLength(1));
    expect(active.single.isBoss, isTrue);
    expect(active.single.hp, ArenaMonster.bossHp);
    expect(game.bossHp.value, ArenaMonster.bossHp);
    final player = game.player!;
    player.position.setFrom(active.single.position);
    active.single.update(0.01);
    expect(active.single.isTelegraphing, isTrue);
    active.single.update(ArenaMonster.bossTelegraphSeconds);
    active.single.update(0.1);
    expect(game.lives.value, 2);
    active.single.takeHit();
    expect(game.bossHp.value, ArenaMonster.bossHp - 1);
  });

  testWidgets(
    'boss death guarantees Rapid Fire and blocks early wave advance',
    (tester) async {
      final game = await loadArenaInto(
        tester,
        SpriteArenaGame(pickupRoll: () => 0.99),
      );
      for (var step = 0; step < 250 && game.wave.value < 5; step++) {
        for (final monster in game.monsters.where((m) => m.alive).toList()) {
          for (var hit = 0; hit < monster.hp; hit++) {
            monster.takeHit();
          }
        }
        game.update(SpriteArenaGame.spawnInterval);
      }
      expect(game.wave.value, 5);
      game.update(SpriteArenaGame.spawnInterval);
      final boss = game.monsters.singleWhere((m) => m.alive);
      final scoreBeforeBoss = game.score.value;
      for (var hit = 0; hit < ArenaMonster.bossHp; hit++) {
        boss.takeHit();
      }
      expect(game.pickup?.kind, ArenaPickupKind.rapidFire);
      expect(game.score.value, scoreBeforeBoss + 100 + 150 + 200);
      expect(game.wave.value, 5);
      game.update(SpriteArenaGame.spawnInterval - 0.01);
      expect(game.wave.value, 5);
      game.update(0.02);
      expect(game.wave.value, 6);
    },
  );

  testWidgets('wave advances only after full spawn interval', (tester) async {
    final game = await loadArena(tester);
    final initialMonsters = game.monsters.toList();
    for (final monster in initialMonsters) {
      monster.takeHit();
      monster.takeHit();
    }
    expect(game.wave.value, 1);
    game.update(SpriteArenaGame.spawnInterval - 0.01);
    expect(game.wave.value, 1);
    expect(game.monsters.where((m) => m.alive), isEmpty);
    game.update(0.02);
    expect(game.wave.value, 2);
    expect(game.waveSize, 3);
    expect(game.monsters.where((m) => m.alive), isEmpty);
    game.update(SpriteArenaGame.spawnInterval - 0.01);
    expect(game.monsters.where((m) => m.alive), isEmpty);
    game.update(0.02);
    expect(game.monsters.where((m) => m.alive).length, 1);
    game.update(SpriteArenaGame.spawnInterval);
    expect(game.monsters.where((m) => m.alive).length, 2);
  });

  testWidgets('long run keeps active cap and monster speed bounded', (
    tester,
  ) async {
    final game = await loadArena(tester);
    for (var frame = 0; frame < 1000 && game.wave.value < 35; frame++) {
      for (final monster in game.monsters.where((m) => m.alive).toList()) {
        monster.takeHit();
        monster.takeHit();
      }
      game.update(SpriteArenaGame.spawnInterval);
      final active = game.monsters.where((m) => m.alive).toList();
      expect(
        active.length,
        lessThanOrEqualTo(SpriteArenaGame.activeMonsterCap),
      );
      expect(active.every((m) => m.speed <= 84), isTrue);
    }
    expect(game.wave.value, 35);
    game.update(SpriteArenaGame.spawnInterval);
    var active = game.monsters.where((m) => m.alive).toList();
    expect(active, hasLength(1));
    expect(active.single.isBoss, isTrue);
    expect(active.single.speed, ArenaMonster.bossSpeed);
    active.single.takeHit();
    for (var hit = 0; hit < ArenaMonster.bossHp - 1; hit++) {
      active.single.takeHit();
    }
    game.update(SpriteArenaGame.spawnInterval);
    expect(game.wave.value, 36);
    for (var slot = 0; slot < SpriteArenaGame.activeMonsterCap; slot++) {
      game.update(SpriteArenaGame.spawnInterval);
    }
    active = game.monsters.where((m) => m.alive).toList();
    expect(active, hasLength(SpriteArenaGame.activeMonsterCap));
    expect(active.every((m) => m.speed == 84), isTrue);
  });

  testWidgets('all blocked spawn spots retry on cadence without hanging', (
    tester,
  ) async {
    final game = await loadArena(tester);
    final blockers = [
      for (final (x, y) in [(1100.0, 300.0), (300.0, 900.0), (1300.0, 1000.0)])
        TerrainRectangle(Vector2(x - 30, y - 30), Vector2.all(60)),
    ];
    for (final monster in game.monsters.toList()) {
      monster.takeHit();
      monster.takeHit();
    }
    game.terrainColliders.addAll(blockers);
    game.update(SpriteArenaGame.spawnInterval);
    expect(game.wave.value, 2);
    expect(game.monsters.where((m) => m.alive), isEmpty);
    game.update(SpriteArenaGame.spawnInterval);
    expect(game.monsters.where((m) => m.alive), isEmpty);
    game.terrainColliders.removeWhere(blockers.contains);
    game.update(SpriteArenaGame.spawnInterval);
    expect(game.monsters.where((m) => m.alive), hasLength(1));
  });

  testWidgets('wave advances after batch, kills do not respawn, wave grows', (
    tester,
  ) async {
    final game = await loadArena(tester);
    expect(game.wave.value, 1);
    expect(game.monsters.length, 2);
    for (final monster in game.monsters.toList()) {
      monster.takeHit();
      monster.takeHit();
    }
    game.update(SpriteArenaGame.spawnInterval);
    expect(game.wave.value, 2);
    expect(game.waveSize, 3);
    game.update(SpriteArenaGame.spawnInterval);
    expect(game.monsters.where((m) => m.alive).length, lessThanOrEqualTo(3));
    expect(game.monsters.where((m) => m.alive), isNotEmpty);
  });

  testWidgets('restart resets lives, wave, score, actors and colliders', (
    tester,
  ) async {
    final game = await loadArena(tester);
    final baselineColliders = game.terrainColliders.length;
    final baselineTargetCount = game.targets.length;
    final target = game.targets.first;
    target.takeHit();
    target.takeHit();
    game.player!.attack();
    game.update(0);
    expect(game.world.children.whereType<ArenaBullet>(), hasLength(1));
    game.score.value = 90;
    game.pickup = ArenaPickup(
      position: target.position.clone(),
      kind: ArenaPickupKind.rapidFire,
      onExpired: () {},
      onCollected: (_) {},
    );
    game.rapidFireRemaining.value = 3;
    game.startFiring();
    game.lives.value = 0;
    game.wave.value = 5;
    game.roundOver.value = true;
    game.pauseEngine();
    game.restart();
    await tester.pump();
    expect(game.phase.value, ArenaPhase.playing);
    expect(game.roundOver.value, isFalse);
    expect(game.lives.value, 4);
    expect(game.wave.value, 1);
    expect(game.score.value, 0);
    expect(game.rapidFireRemaining.value, 0);
    expect(game.pickup, isNull);
    expect(game.isFiring, isFalse);
    expect(game.terrainColliders.length, baselineColliders);
    expect(target.alive, isTrue);
    expect(target.hp, ArenaTarget.maxHp);
    expect(game.targets, hasLength(baselineTargetCount));
    expect(game.world.children.whereType<ArenaBullet>(), isEmpty);
    expect(
      game.world.children.whereType<ArenaTarget>(),
      hasLength(game.targets.length),
    );
    expect(
      game.world.children.whereType<ArenaCrate>(),
      hasLength(game.crates.length),
    );
    final crateCount = game.crates.length;
    game.restart();
    await tester.pump();
    expect(game.targets, hasLength(baselineTargetCount));
    expect(game.crates, hasLength(crateCount));
    expect(game.terrainColliders, hasLength(baselineColliders));
    expect(
      game.world.children.whereType<ArenaTarget>(),
      hasLength(baselineTargetCount),
    );
  });

  testWidgets('pause freezes wave transition timer', (tester) async {
    final game = await loadArena(tester);
    for (final monster in game.monsters.toList()) {
      monster.takeHit();
      monster.takeHit();
    }
    game.update(0.5);
    game.pauseEngine();
    await tester.pump(const Duration(seconds: 5));
    game.resumeEngine();
    game.update(0.69);
    expect(game.wave.value, 1);
    game.update(0.02);
    expect(game.wave.value, 2);
    expect(game.monsters.where((m) => m.alive), isEmpty);
  });

  testWidgets('pause freezes monsters', (tester) async {
    final game = await loadArena(tester);
    final m = game.monsters.first;
    final at = m.position.clone();
    game.pauseEngine();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(m.position, at);
  });

  testWidgets('crates spawn clear of everything and block like terrain', (
    tester,
  ) async {
    final game = await loadArena(tester);
    expect(game.crates, isNotEmpty);
    for (final c in game.crates) {
      expect(game.terrainColliders, contains(c.collider));
      for (final other in [
        for (final t in game.targets) t.hitRect,
        for (final m in game.monsters) m.hitRect,
      ]) {
        expect(other.overlaps(c.hitRect), isFalse);
      }
    }
    final c = game.crates.first;
    game.player!.position.setValues(c.position.x - 80, c.position.y);
    game.player!.setMoveInput(GameJoystickDirection.right, const Offset(1, 0));
    game.update(2);
    expect(game.player!.position.x, lessThan(c.position.x - 16));
  });

  testWidgets('one hit breaks a crate: collider removed, +5, path opens', (
    tester,
  ) async {
    final game = await loadArena(tester);
    final c = game.crates.first;
    final before = game.terrainColliders.length;
    game.player!.position.setValues(c.position.x - 120, c.position.y);
    game.player!.angle = 0;
    game.player!.attack();
    game.update(0);
    game.update(0.3);
    expect(c.alive, isFalse);
    expect(game.score.value, 5);
    expect(game.terrainColliders.length, before - 1);
    expect(game.terrainColliders, isNot(contains(c.collider)));
    game.player!.position.setValues(c.position.x - 40, c.position.y);
    game.player!.setMoveInput(GameJoystickDirection.right, const Offset(1, 0));
    game.update(0.5);
    expect(game.player!.position.x, greaterThan(c.position.x));
  });

  testWidgets('breaking every crate does not crash and stays broken', (
    tester,
  ) async {
    final game = await loadArena(tester);
    for (final c in game.crates.toList()) {
      c.takeHit();
    }
    game.update(10);
    expect(game.crates.every((c) => !c.alive), isTrue);
    expect(game.score.value, 5 * game.crates.length);
  });

  testWidgets(
    'real arena loads, camera follows and shots start at the barrel',
    (tester) async {
      final game = SpriteArenaGame();
      await tester.runAsync(() async {
        rootBundle.evict('assets/tiles/character_arena.tmx');
        await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
        await Future<void>.sync(
          game.toBeLoaded,
        ).timeout(const Duration(seconds: 10));
      });
      await tester.pump();
      await tester.pump();
      final player = game.player!;
      expect(player.hasSprites, isTrue);
      expect(game.arena!.size, Vector2(1536, 1152));
      expect(game.terrainColliders.length, greaterThan(100));
      final cameraStart = game.camera.viewfinder.position.clone();
      player.position += Vector2(100, 0);
      for (var i = 0; i < 3; i++) {
        game.update(0.016);
      }
      expect(game.camera.viewfinder.position.x, greaterThan(cameraStart.x));
      player.angle = 0;
      player.attack();
      game.update(0);
      final bullet = game.world.children.whereType<ArenaBullet>().single;
      expect(bullet.position.x, closeTo(player.position.x + 24.5, 0.001));
      expect(bullet.position.y, closeTo(player.position.y + 9.5, 0.001));
      player.position.setValues(180, 280);
      player.setMoveInput(GameJoystickDirection.left, const Offset(-1, 0));
      game.update(2);
      expect(player.position.x, greaterThanOrEqualTo(60.75));
      expect(player.position.x, lessThan(180));
    },
  );

  testWidgets(
    'paused attacks do not queue bullets; pending bullets count toward cap',
    (tester) async {
      final game = SpriteArenaGame();
      await tester.runAsync(() async {
        rootBundle.evict('assets/tiles/character_arena.tmx');
        await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
        await Future<void>.sync(
          game.toBeLoaded,
        ).timeout(const Duration(seconds: 10));
      });
      await tester.pump();
      await tester.pump();
      game.pauseEngine();
      for (var i = 0; i < 50; i++) {
        game.player!.attack();
      }
      game.resumeEngine();
      game.update(0);
      expect(game.world.children.whereType<ArenaBullet>(), isEmpty);
      for (var i = 0; i < 50; i++) {
        game.player!.attack();
      }
      game.update(0);
      expect(game.world.children.whereType<ArenaBullet>(), hasLength(24));
      game.update(2);
      game.update(0);
      expect(game.world.children.whereType<ArenaBullet>(), isEmpty);
      game.player!.attack();
      game.update(0);
      expect(game.world.children.whereType<ArenaBullet>(), hasLength(1));
    },
  );

  testWidgets('system background pauses attacks and foreground restores them', (
    tester,
  ) async {
    final game = SpriteArenaGame();
    await tester.runAsync(() async {
      rootBundle.evict('assets/tiles/character_arena.tmx');
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await Future<void>.sync(
        game.toBeLoaded,
      ).timeout(const Duration(seconds: 10));
    });
    await tester.pump();
    await tester.pump();
    expect(game.attackEnabled, isTrue);

    game.player!.setMoveInput(GameJoystickDirection.right, const Offset(1, 0));
    game.lifecycleStateChange(AppLifecycleState.paused);
    expect(game.player!.direction, GameJoystickDirection.idle);
    expect(game.paused, isTrue);
    expect(game.attackEnabled, isFalse);
    for (var i = 0; i < 50; i++) {
      game.attack();
    }
    game.update(0);
    expect(game.world.children.whereType<ArenaBullet>(), isEmpty);

    game.lifecycleStateChange(AppLifecycleState.resumed);
    expect(game.paused, isFalse);
    expect(game.attackEnabled, isTrue);
    game.attack();
    game.update(0);
    expect(game.world.children.whereType<ArenaBullet>(), hasLength(1));
    game.pauseEngine();
    game.lifecycleStateChange(AppLifecycleState.paused);
    game.lifecycleStateChange(AppLifecycleState.resumed);
    expect(game.phase.value, ArenaPhase.paused);
    expect(game.attackEnabled, isFalse);
  });

  testWidgets(
    'initial objectives has 3 items with 0 progress and not completed',
    (tester) async {
      final game = await loadArena(tester);
      expect(game.objectives.value, hasLength(3));
      expect(game.completedObjectivesCount, 0);
      for (final obj in game.objectives.value) {
        expect(obj.progress, 0);
        expect(obj.completed, isFalse);
      }
    },
  );

  testWidgets(
    'reaching score 500 completes reachScore500 and awards +200 bonus score without recursion',
    (tester) async {
      final game = await loadArena(tester);
      // Đặt score lên 490 -> progress cập nhật 490, chưa complete
      game.score.value = 490;
      final objBefore = game.objectives.value.firstWhere(
        (o) => o.id == ArenaObjectiveId.reachScore500,
      );
      expect(objBefore.progress, 490);
      expect(objBefore.completed, isFalse);

      // Đặt lên 500 -> complete, bonus +200 vào score (thành 700)
      game.score.value = 500;
      final objAfter = game.objectives.value.firstWhere(
        (o) => o.id == ArenaObjectiveId.reachScore500,
      );
      expect(objAfter.progress, 500);
      expect(objAfter.completed, isTrue);
      expect(game.score.value, 700); // 500 + 200
      expect(game.completedObjectivesCount, 1);
    },
  );

  testWidgets(
    'defeating boss at wave 5 completes defeatBossWave5 and awards +150 bonus score',
    (tester) async {
      final game = await loadArenaInto(
        tester,
        SpriteArenaGame(pickupRoll: () => 0.99),
      );
      await advanceToWave(game, 5);
      game.update(SpriteArenaGame.spawnInterval);
      final boss = game.monsters.singleWhere((m) => m.alive);
      final scoreBefore = game.score.value;
      for (var hit = 0; hit < ArenaMonster.bossHp; hit++) {
        boss.takeHit();
      }
      final obj = game.objectives.value.firstWhere(
        (o) => o.id == ArenaObjectiveId.defeatBossWave5,
      );
      expect(obj.completed, isTrue);
      expect(obj.progress, 1);
      // Điểm boss +100, bonus objective boss +150, bonus score500 +200 = +450
      expect(game.score.value, scoreBefore + 100 + 150 + 200);
    },
  );

  testWidgets(
    'clearing wave 5 with >=3 lives completes surviveWith3Lives and calls onBossWaveCleared',
    (tester) async {
      final game = await loadArenaInto(
        tester,
        SpriteArenaGame(pickupRoll: () => 0.99),
      );
      var bossClearedCalled = false;
      game.onBossWaveCleared = () => bossClearedCalled = true;
      game.lives.value = 3;
      await advanceToWave(game, 5);
      game.update(SpriteArenaGame.spawnInterval);
      final boss = game.monsters.singleWhere((m) => m.alive);
      for (var hit = 0; hit < ArenaMonster.bossHp; hit++) {
        boss.takeHit();
      }
      final scoreBefore = game.score.value;
      // Tick để wave 5 clear
      game.update(SpriteArenaGame.spawnInterval);
      expect(bossClearedCalled, isTrue);
      final obj = game.objectives.value.firstWhere(
        (o) => o.id == ArenaObjectiveId.surviveWith3Lives,
      );
      expect(obj.completed, isTrue);
      expect(game.score.value, scoreBefore + 100);
    },
  );

  testWidgets('restart resets objectives to initial 0-progress state', (
    tester,
  ) async {
    final game = await loadArena(tester);
    game.score.value = 500;
    expect(game.completedObjectivesCount, 1);
    game.restart();
    expect(game.completedObjectivesCount, 0);
    for (final obj in game.objectives.value) {
      expect(obj.progress, 0);
      expect(obj.completed, isFalse);
    }
  });

  test('arena includes visible props aligned with collision objects', () {
    final map = File('assets/tiles/character_arena.tmx').readAsStringSync();
    expect(map, contains('width="32" height="24"'));
    expect(map, contains('name="Props"'));
    expect(map, contains('1135'));
    expect(map, contains('1133'));
    expect(map, contains('1252'));
    expect(map, contains('name="Crate stack A" x="128" y="96"'));
    expect(map, contains('name="Rock obstacle" x="240" y="176"'));
  });
}

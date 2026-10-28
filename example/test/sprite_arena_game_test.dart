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

  Future<SpriteArenaGame> loadArena(WidgetTester tester) async {
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
    return game;
  }

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
    for (final m in game.monsters) {
      expect(
        game.terrainColliders.any(
          (c) => terrainColliderOverlapsRect(c, m.hitRect),
        ),
        isFalse,
      );
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

  testWidgets('two hits kill a monster for +25, it respawns home after 4s', (
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
    expect(m.alive, isTrue);
    expect(m.position.distanceTo(m.home), lessThan(1));
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

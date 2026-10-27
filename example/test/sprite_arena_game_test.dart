import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roy_casual_kit/presentation/widgets/common/game_joystick.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/game/tiled_terrain_collision.dart';
import 'package:roy_casual_kit_example/game/sprite_arena_game.dart';

void main() {
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

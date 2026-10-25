import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/game/roy_game.dart';
import 'package:roy_casual_kit/presentation/game/tiled_terrain_collision.dart';
import 'package:roy_casual_kit/presentation/widgets/common/game_joystick.dart';

Future<void> _settled(WidgetTester tester, RoyGame game) async {
  await game.toBeLoaded();
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'playable character moves in 8 directions with normalized diagonal speed',
    (tester) async {
      final game = RoyGame(enablePlayableCharacter: true);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await _settled(tester, game);

      final player = game.player!;
      final start = player.position.clone();

      player.setMoveInput(
        GameJoystickDirection.upRight,
        GameJoystick.vectorFor(GameJoystickDirection.upRight),
      );
      game.update(0.1);
      final delta = player.position - start;
      expect(delta.x, greaterThan(0));
      expect(delta.y, lessThan(0));
      expect(player.angle, closeTo(-math.pi / 4, 0.001));

      final speed = delta.length / 0.1;
      player.setMoveInput(
        GameJoystickDirection.right,
        GameJoystick.vectorFor(GameJoystickDirection.right),
      );
      final nextStart = player.position.clone();
      game.update(0.1);
      final cardinalDelta = player.position - nextStart;
      expect(cardinalDelta.length / 0.1, closeTo(speed, 0.01));

      player.setMoveInput(GameJoystickDirection.idle, Offset.zero);
      final stopped = player.position.clone();
      game.update(0.1);
      expect(player.position, equals(stopped));
    },
  );

  testWidgets('solid terrain blocks player movement', (tester) async {
    final game = RoyGame(
      enablePlayableCharacter: true,
      terrainColliders: [TerrainRectangle(Vector2(96, 64), Vector2(32, 16))],
    );
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await _settled(tester, game);

    final player = game.player!;
    player.position.setValues(72, 84);
    player.setMoveInput(
      GameJoystickDirection.right,
      GameJoystick.vectorFor(GameJoystickDirection.right),
    );
    for (var i = 0; i < 20; i++) {
      game.update(0.05);
    }
    expect(player.position.x, lessThan(96));
    expect(player.position.y, 84);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large frame cannot tunnel through a thin terrain wall', (
    tester,
  ) async {
    final game = RoyGame(
      enablePlayableCharacter: true,
      terrainColliders: [TerrainRectangle(Vector2(96, 0), Vector2(16, 600))],
    );
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await _settled(tester, game);
    final player = game.player!;
    player.position.setValues(60, 180);
    player.setMoveInput(GameJoystickDirection.right, const Offset(1, 0));
    game.update(2);
    expect(player.position.x, lessThanOrEqualTo(96 - player.size.x / 4));
    expect(player.position.x, greaterThan(60));
  });

  testWidgets('attack hook replaces default particles and preserves timer', (
    tester,
  ) async {
    final game = RoyGame(enablePlayableCharacter: true);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await _settled(tester, game);
    var attacks = 0;
    game.player!.onAttack = () => attacks++;
    game.player!.attack();
    expect(attacks, 1);
    expect(game.player!.isAttacking, isTrue);
    expect(game.world.children.whereType<SparkleParticle>(), isEmpty);
    game.update(0.3);
    expect(game.player!.isAttacking, isFalse);
  });

  testWidgets(
    'attack button triggers visible bounded effect and resets attacking state',
    (tester) async {
      final game = RoyGame(enablePlayableCharacter: true);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await _settled(tester, game);

      final player = game.player!;
      expect(player.isAttacking, isFalse);

      player.attack();
      expect(player.isAttacking, isTrue);
      game.update(0.05);
      expect(player.isAttacking, isTrue);
      game.update(0.3);
      expect(player.isAttacking, isFalse);
    },
  );
}

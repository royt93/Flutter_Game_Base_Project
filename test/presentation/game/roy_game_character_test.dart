import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/game/roy_game.dart';
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

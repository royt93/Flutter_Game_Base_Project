import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/game_joystick.dart';

void main() {
  test('normalizes diagonal and classifies all eight directions', () {
    for (final direction in GameJoystickDirection.values) {
      if (direction == GameJoystickDirection.idle) continue;
      final vector = GameJoystick.vectorFor(direction);
      expect(vector.distance, closeTo(1, 0.000001));
      expect(GameJoystick.directionFor(vector), direction);
    }
  });

  test('zero vector classifies as idle', () {
    expect(GameJoystick.directionFor(Offset.zero), GameJoystickDirection.idle);
  });

  testWidgets('drag emits normalized eight-way direction then neutral on end', (
    tester,
  ) async {
    final values = <GameJoystickDirection>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GameJoystick(
              semanticLabel: 'Move character',
              onDirectionChanged: (direction, vector) => values.add(direction),
            ),
          ),
        ),
      ),
    );

    final target = find.byType(GameJoystick);
    final center = tester.getCenter(target);
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(45, -45));
    await tester.pump();
    expect(values.last, GameJoystickDirection.upRight);

    await gesture.up();
    await tester.pump();
    expect(values.last, GameJoystickDirection.idle);

    final handle = tester.ensureSemantics();
    expect(tester.getSemantics(target).label, 'Move character');
    handle.dispose();
  });
}

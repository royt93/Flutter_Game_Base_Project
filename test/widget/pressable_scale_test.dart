import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/pressable_scale.dart';

void main() {
  testWidgets('tap invokes onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: PressableScale(
            onTap: () => tapped = true,
            child: const Text('X'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('X'));
    expect(tapped, isTrue);
  });

  testWidgets('scales down while pressed, back up on release', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: PressableScale(
            onTap: () {},
            child: const ColoredBox(
              color: Colors.blue,
              child: SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await tester.pump();
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      0.94,
    );

    await gesture.up();
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.0);
  });

  testWidgets(
    'FEAT-17: Reduce Motion bật → chuyển scale tức thời (duration = 0)',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Material(
              child: PressableScale(onTap: () {}, child: const Text('X')),
            ),
          ),
        ),
      );

      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
        Duration.zero,
      );
    },
  );

  testWidgets('disabled (onTap null) ignores tap without crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: PressableScale(onTap: null, child: Text('X'))),
      ),
    );

    await tester.tap(find.text('X'));
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/squash_stretch.dart';

Matrix4 _transformOf(WidgetTester tester) =>
    tester.widget<Transform>(find.byType(Transform)).transform;

void main() {
  testWidgets('tap-down starts a non-uniform squash (scaleX != scaleY)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SquashStretch(
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
      tester.getCenter(find.byType(SquashStretch)),
    );
    // First pump: the spring ticker's own first tick always reports
    // elapsed=0 (its reference start time), so a 2nd, later pump is what
    // actually advances the simulation into a mid-squash state.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    final m = _transformOf(tester);
    final scaleX = m.getColumn(0).x;
    final scaleY = m.getColumn(1).y;
    expect(scaleX, isNot(closeTo(scaleY, 1e-6)));
    expect(scaleX, isNot(closeTo(1.0, 1e-6)));

    await gesture.up();
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('release eventually settles back to exactly (1.0, 1.0)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SquashStretch(
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
      tester.getCenter(find.byType(SquashStretch)),
    );
    await tester.pump(const Duration(milliseconds: 30));
    await gesture.up();
    // Give the spring plenty of time to fully decay.
    await tester.pump(const Duration(seconds: 2));

    final m = _transformOf(tester);
    expect(m.getColumn(0).x, 1.0);
    expect(m.getColumn(1).y, 1.0);
  });

  testWidgets(
    'reduced motion skips the visual squash but the tap callback still fires',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Material(
              child: SquashStretch(
                onTap: () => tapped = true,
                child: const ColoredBox(
                  color: Colors.blue,
                  child: SizedBox(width: 40, height: 40),
                ),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SquashStretch)),
      );
      await tester.pump(const Duration(milliseconds: 40));

      final m = _transformOf(tester);
      expect(m.getColumn(0).x, 1.0);
      expect(m.getColumn(1).y, 1.0);

      // The down+up sequence above is itself a complete tap gesture — no
      // need for a separate tester.tap() call.
      await gesture.up();
      await tester.pump();
      expect(tapped, isTrue);
    },
  );

  testWidgets('disposal mid-animation does not throw', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SquashStretch(
            onTap: () {},
            child: const ColoredBox(
              color: Colors.blue,
              child: SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      ),
    );

    await tester.startGesture(tester.getCenter(find.byType(SquashStretch)));
    await tester.pump(const Duration(milliseconds: 20));

    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}

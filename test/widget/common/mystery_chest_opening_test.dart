import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/mystery_chest_opening.dart';

Finder findSunburstPainter() => find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is SunburstGodRays,
);

void main() {
  test('phase helper maps ordered intervals and clamps progress', () {
    expect(mysteryChestPhaseAt(0), MysteryChestPhase.idle);
    expect(mysteryChestPhaseAt(0.2), MysteryChestPhase.shaking);
    expect(mysteryChestPhaseAt(0.5), MysteryChestPhase.opened);
    expect(mysteryChestPhaseAt(0.8), MysteryChestPhase.revealed);
    expect(mysteryChestPhaseAt(2), MysteryChestPhase.revealed);
  });

  testWidgets('tap progresses through chest phases and reveals once', (
    tester,
  ) async {
    final key = GlobalKey<MysteryChestOpeningState>();
    var revealed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: MysteryChestOpening(
            key: key,
            duration: const Duration(milliseconds: 600),
            reward: const Text('Prize'),
            onRevealed: () => revealed++,
          ),
        ),
      ),
    );
    expect(key.currentState!.phase, MysteryChestPhase.idle);
    expect(findSunburstPainter(), findsNothing);

    final chest = find.byType(MysteryChestOpening);
    final gesture = await tester.startGesture(tester.getCenter(chest));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(key.currentState!.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(key.currentState!.phase, MysteryChestPhase.shaking);
    await tester.pump(const Duration(milliseconds: 170));
    expect(key.currentState!.phase, MysteryChestPhase.opened);
    expect(findSunburstPainter(), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 220));
    expect(key.currentState!.phase, MysteryChestPhase.revealed);
    expect(find.text('Prize'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 150));
    expect(revealed, 1);
    expect(key.currentState!.isAnimating, isFalse);
    await tester.tap(find.byType(MysteryChestOpening));
    await tester.pump();
    expect(revealed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced Motion reveals immediately and omits rotating rays', (
    tester,
  ) async {
    var revealed = 0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Material(
            child: MysteryChestOpening(
              reward: const Text('Prize'),
              onRevealed: () => revealed++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(MysteryChestOpening));
    await tester.pump();
    expect(find.text('Prize'), findsOneWidget);
    expect(findSunburstPainter(), findsNothing);
    expect(revealed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enabling Reduced Motion during opening snaps and completes', (
    tester,
  ) async {
    var reduced = false;
    late StateSetter update;
    var revealed = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: MaterialApp(
              home: Material(
                child: MysteryChestOpening(
                  duration: const Duration(seconds: 2),
                  onRevealed: () => revealed++,
                ),
              ),
            ),
          );
        },
      ),
    );
    await tester.tap(find.byType(MysteryChestOpening));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    update(() => reduced = true);
    await tester.pump();
    expect(findSunburstPainter(), findsNothing);
    expect(revealed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmount during opening disposes animation cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Material(child: MysteryChestOpening())),
    );
    await tester.tap(find.byType(MysteryChestOpening));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}

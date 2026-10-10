import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/item_fly_overlay.dart';

void main() {
  group('ItemFlyOverlay math & validation', () {
    test(
      'itemArcOffsetAt starts at from, ends at to, arcs through midpoint + curveOffset',
      () {
        const from = Offset(0, 100);
        const to = Offset(200, 100);
        const curve = Offset(0, -50);

        expect(itemArcOffsetAt(from, to, 0.0, curveOffset: curve), from);
        expect(itemArcOffsetAt(from, to, 1.0, curveOffset: curve), to);

        final mid = itemArcOffsetAt(from, to, 0.5, curveOffset: curve);
        expect(mid.dx, 100);
        expect(
          mid.dy,
          75,
        ); // (100 + 2*50 + 100) / 4 -> control.dy = 50 -> 0.25*100 + 0.5*50 + 0.25*100 = 75
      },
    );

    test(
      'itemScaleAt pops to 1.25 at midpoint and settles to 0.9 at landing',
      () {
        expect(itemScaleAt(0.0), 1.0);
        expect(itemScaleAt(0.5), 1.25);
        expect(itemScaleAt(1.0), closeTo(0.9, 0.001));
      },
    );

    test('validates constructor arguments at runtime', () {
      expect(
        () => ItemFlyOverlay(from: Offset.zero, to: Offset.zero, itemCount: 0),
        throwsArgumentError,
      );
      expect(
        () => ItemFlyOverlay(
          from: Offset.zero,
          to: Offset.zero,
          flightDuration: Duration.zero,
        ),
        throwsArgumentError,
      );
      expect(
        () => ItemFlyOverlay(from: Offset.zero, to: Offset.zero, itemSize: -5),
        throwsArgumentError,
      );
    });
  });

  group('ItemFlyOverlay widget tests', () {
    testWidgets('flies items, calls onItemArrive per item and onDone once', (
      tester,
    ) async {
      final arrivedIndices = <int>[];
      var done = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemFlyOverlay(
              from: const Offset(50, 50),
              to: const Offset(300, 300),
              itemCount: 3,
              flightDuration: const Duration(milliseconds: 200),
              stagger: const Duration(milliseconds: 50),
              itemBuilder: (context, i) => Text('Item $i'),
              onItemArrive: arrivedIndices.add,
              onDone: () => done = true,
            ),
          ),
        ),
      );

      expect(done, isFalse);

      // Prime the ticker timestamp before advancing virtual flight time.
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 210));
      expect(arrivedIndices, contains(0));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(arrivedIndices, [0, 1, 2]);
      expect(done, isTrue);
    });

    testWidgets(
      'ItemFlyOverlay.show inserts into Overlay and self-removes on completion',
      (tester) async {
        final targetKey = GlobalKey();
        var done = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(key: targetKey, width: 40, height: 40),
              ),
            ),
          ),
        );

        final context = targetKey.currentContext!;
        ItemFlyOverlay.show(
          context,
          from: const Offset(10, 10),
          toKey: targetKey,
          itemCount: 2,
          flightDuration: const Duration(milliseconds: 100),
          stagger: const Duration(milliseconds: 30),
          icon: Icons.star,
          onDone: () => done = true,
        );

        await tester.pump();
        expect(find.byType(ItemFlyOverlay), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 200));
        expect(done, isTrue);

        await tester.pump();
        expect(find.byType(ItemFlyOverlay), findsNothing);
      },
    );

    testWidgets('reduced motion completes instantly without pending frames', (
      tester,
    ) async {
      var done = false;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: ItemFlyOverlay(
                from: const Offset(10, 10),
                to: const Offset(100, 100),
                itemCount: 2,
                flightDuration: const Duration(milliseconds: 300),
                onDone: () => done = true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(done, isTrue);
    });

    testWidgets(
      'unmounting mid-flight disposes controller cleanly without throwing',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ItemFlyOverlay(
                from: const Offset(10, 10),
                to: const Offset(100, 100),
                itemCount: 3,
                flightDuration: const Duration(milliseconds: 500),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Unmount mid-flight
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox())),
        );

        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
      },
    );
  });
}

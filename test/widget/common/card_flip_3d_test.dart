import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/card_flip_3d.dart';

void main() {
  group('CardFlip3D math & validation', () {
    test('isCardFrontVisible calculates correct front/back hemisphere', () {
      expect(isCardFrontVisible(0.0), isTrue);
      expect(isCardFrontVisible(math.pi * 0.4), isTrue);
      expect(isCardFrontVisible(math.pi * 0.6), isFalse);
      expect(isCardFrontVisible(math.pi), isFalse);
      expect(isCardFrontVisible(math.pi * 1.4), isFalse);
      expect(isCardFrontVisible(math.pi * 1.6), isTrue);
      expect(isCardFrontVisible(2 * math.pi), isTrue);
    });

    test('cardFlipTransform sets perspective entry and rotation', () {
      final mHoriz = cardFlipTransform(
        angle: 0.0,
        perspective: 0.002,
        axis: Axis.horizontal,
      );
      expect(mHoriz.entry(3, 2), 0.002);

      final mVert = cardFlipTransform(
        angle: 0.0,
        perspective: 0.001,
        axis: Axis.vertical,
      );
      expect(mVert.entry(3, 2), 0.001);
    });

    test('validates arguments at runtime', () {
      expect(
        () => CardFlip3D(
          front: const Text('F'),
          back: const Text('B'),
          duration: Duration.zero,
        ),
        throwsArgumentError,
      );

      expect(
        () => CardFlip3D(
          front: const Text('F'),
          back: const Text('B'),
          gleamDuration: const Duration(milliseconds: -1),
        ),
        throwsArgumentError,
      );

      expect(
        () => CardFlip3D(
          front: const Text('F'),
          back: const Text('B'),
          perspective: -0.01,
        ),
        throwsArgumentError,
      );

      expect(
        () => CardFlip3D(
          front: const Text('F'),
          back: const Text('B'),
          perspective: double.nan,
        ),
        throwsArgumentError,
      );
    });
  });

  group('CardFlip3D widget tests', () {
    testWidgets('renders front initially, reveals back on flip with callbacks', (
      tester,
    ) async {
      var isFlipped = false;
      final flips = <bool>[];
      late StateSetter setFlip;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setFlip = setState;
                return Center(
                  child: CardFlip3D(
                    isFlipped: isFlipped,
                    onFlip: (f) => flips.add(f),
                    duration: const Duration(milliseconds: 300),
                    front: const Text('Card Front'),
                    back: const Text('Card Back'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Card Front').hitTestable(), findsOneWidget);
      expect(find.text('Card Back').hitTestable(), findsNothing);

      // Trigger flip to back
      setFlip(() => isFlipped = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150)); // Halfway point

      // Past halfway, back should face camera
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.text('Card Back'), findsOneWidget);
      expect(flips, [true]);

      // Complete gleam animation
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('CardFlip3DController triggers imperative flipping', (
      tester,
    ) async {
      final controller = CardFlip3DController();
      final flips = <bool>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CardFlip3D(
                controller: controller,
                onFlip: (f) => flips.add(f),
                duration: const Duration(milliseconds: 200),
                front: const Text('Front Face'),
                back: const Text('Back Face'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Front Face').hitTestable(), findsOneWidget);

      controller.flip();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));
      expect(flips, [true]);

      controller.flipToFront();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(flips, [true, false]);
    });

    testWidgets(
      'Reduced Motion flips instantly without animation and skips gleam',
      (tester) async {
        final controller = CardFlip3DController();

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: CardFlip3D(
                    controller: controller,
                    front: const Text('Front NoMotion'),
                    back: const Text('Back NoMotion'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Front NoMotion'), findsOneWidget);

        controller.flip();
        await tester.pump(); // 1 frame, no animation waiting
        expect(find.text('Back NoMotion'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('unmounting mid-flip disposes controllers cleanly', (
      tester,
    ) async {
      var isFlipped = false;
      late StateSetter setFlip;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setFlip = setState;
                return CardFlip3D(
                  isFlipped: isFlipped,
                  duration: const Duration(milliseconds: 500),
                  front: const Text('Front Dispose'),
                  back: const Text('Back Dispose'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      setFlip(() => isFlipped = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100)); // mid-flight

      // Unmount
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    });
  });
}

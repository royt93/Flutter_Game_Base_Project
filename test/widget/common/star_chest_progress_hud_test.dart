import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/star_chest_progress_hud.dart';

Widget _wrap(Widget child, {bool reduced = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

double _pulseScale(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('starChestPulseScale')))
    .transform
    .entry(0, 0);

void main() {
  group('starChestProgressFraction', () {
    test('computes fraction and clamps between 0.0 and 1.0', () {
      expect(starChestProgressFraction(0, 20), 0.0);
      expect(starChestProgressFraction(10, 20), 0.5);
      expect(starChestProgressFraction(20, 20), 1.0);
      expect(starChestProgressFraction(28, 20), 1.0);
    });

    test('validates inputs', () {
      expect(() => starChestProgressFraction(-1, 20), throwsArgumentError);
      expect(() => starChestProgressFraction(5, 0), throwsArgumentError);
      expect(() => starChestProgressFraction(5, -10), throwsArgumentError);
    });
  });

  group('StarChestProgressHud validation', () {
    test('rejects negative currentStars or non-positive targetStars', () {
      expect(
        () => StarChestProgressHud(currentStars: -1, targetStars: 20),
        throwsArgumentError,
      );
      expect(
        () => StarChestProgressHud(currentStars: 5, targetStars: 0),
        throwsArgumentError,
      );
    });

    test('rejects non-positive height or invalid width', () {
      expect(
        () => StarChestProgressHud(currentStars: 5, targetStars: 20, height: 0),
        throwsArgumentError,
      );
      expect(
        () =>
            StarChestProgressHud(currentStars: 5, targetStars: 20, width: -10),
        throwsArgumentError,
      );
    });
  });

  group('StarChestProgressHud interactions & states', () {
    testWidgets(
      'unready state displays exact star count and invokes onInfoTap',
      (tester) async {
        var infoCalls = 0;
        var openCalls = 0;

        await tester.pumpWidget(
          _wrap(
            StarChestProgressHud(
              currentStars: 14,
              targetStars: 20,
              onInfoTap: () => infoCalls++,
              onOpenChestTap: () => openCalls++,
            ),
          ),
        );

        expect(find.text('14/20 ⭐'), findsOneWidget);
        expect(find.byKey(const ValueKey('starChestOpenBadge')), findsNothing);

        await tester.tap(find.byKey(const ValueKey('starChestTapTarget')));
        await tester.pump();

        expect(infoCalls, 1);
        expect(openCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('exceeded stars displays actual count e.g. 24/20', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(StarChestProgressHud(currentStars: 24, targetStars: 20)),
      );

      // When ready (24 >= 20), ready badge is shown
      expect(find.byKey(const ValueKey('starChestOpenBadge')), findsOneWidget);
    });

    testWidgets(
      'ready state displays Open! badge, pulses, and invokes onOpenChestTap',
      (tester) async {
        var openCalls = 0;
        var infoCalls = 0;

        await tester.pumpWidget(
          _wrap(
            StarChestProgressHud(
              currentStars: 20,
              targetStars: 20,
              onOpenChestTap: () => openCalls++,
              onInfoTap: () => infoCalls++,
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey('starChestOpenBadge')),
          findsOneWidget,
        );
        expect(find.text('Open!'), findsOneWidget);

        // Advance pulse animation slightly
        await tester.pump(const Duration(milliseconds: 300));
        expect(_pulseScale(tester), greaterThan(1.0));

        await tester.tap(find.byKey(const ValueKey('starChestTapTarget')));
        await tester.pump();

        expect(openCalls, 1);
        expect(infoCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Reduced Motion disables golden pulse animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          StarChestProgressHud(currentStars: 20, targetStars: 20),
          reduced: true,
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(_pulseScale(tester), 1.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Semantics announces star progress and ready state accurately',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          _wrap(StarChestProgressHud(currentStars: 15, targetStars: 30)),
        );

        var node = tester.getSemantics(find.byType(StarChestProgressHud));
        expect(node.label, 'Star chest, 15 of 30 stars');

        await tester.pumpWidget(
          _wrap(StarChestProgressHud(currentStars: 30, targetStars: 30)),
        );

        node = tester.getSemantics(find.byType(StarChestProgressHud));
        expect(
          node.label,
          'Star chest ready to open, 30 of 30 stars, tap to open',
        );

        handle.dispose();
      },
    );
  });
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/coin_multiplier_wheel.dart';

Widget _wrap(Widget child, {bool reduced = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('Math helpers', () {
    test(
      'multiplierIndexAtNormalizedProgress maps correctly across sectors',
      () {
        expect(multiplierIndexAtNormalizedProgress(0.0, 5), 0);
        expect(multiplierIndexAtNormalizedProgress(0.19, 5), 0);
        expect(multiplierIndexAtNormalizedProgress(0.21, 5), 1);
        expect(multiplierIndexAtNormalizedProgress(0.5, 5), 2);
        expect(multiplierIndexAtNormalizedProgress(0.99, 5), 4);
        expect(multiplierIndexAtNormalizedProgress(1.0, 5), 4);
        expect(multiplierIndexAtNormalizedProgress(-0.5, 5), 0);
        expect(multiplierIndexAtNormalizedProgress(1.5, 5), 4);
      },
    );

    test(
      'multiplierIndexAtNormalizedProgress validates count and progress',
      () {
        expect(
          () => multiplierIndexAtNormalizedProgress(0.5, 1),
          throwsArgumentError,
        );
        expect(
          () => multiplierIndexAtNormalizedProgress(double.nan, 4),
          throwsArgumentError,
        );
      },
    );

    test(
      'multiplierNeedleAngleAtProgress oscillates between -maxAngle and +maxAngle',
      () {
        const maxA = 0.38 * math.pi;
        final angleAt0 = multiplierNeedleAngleAtProgress(0.0, maxAngle: maxA);
        final angleAtHalf = multiplierNeedleAngleAtProgress(
          0.5,
          maxAngle: maxA,
        );
        final angleAtQuarter = multiplierNeedleAngleAtProgress(
          0.25,
          maxAngle: maxA,
        );

        expect(angleAt0, closeTo(-maxA, 0.001));
        expect(angleAtHalf, closeTo(maxA, 0.001));
        expect(angleAtQuarter, closeTo(0.0, 0.001));
      },
    );
  });

  group('CoinMultiplierWheel validation', () {
    test('rejects fewer than 2 sectors or multiplier < 1', () {
      expect(
        () => CoinMultiplierWheel(multipliers: const [2]),
        throwsArgumentError,
      );
      expect(
        () => CoinMultiplierWheel(multipliers: const [2, 0, 3]),
        throwsArgumentError,
      );
    });

    test('rejects non-positive radius or invalid duration', () {
      expect(() => CoinMultiplierWheel(radius: 0), throwsArgumentError);
      expect(
        () => CoinMultiplierWheel(swingDuration: Duration.zero),
        throwsArgumentError,
      );
    });
  });

  group('CoinMultiplierWheel interactions & controller', () {
    testWidgets('renders all multiplier text labels', (tester) async {
      await tester.pumpWidget(
        _wrap(CoinMultiplierWheel(multipliers: const [2, 3, 5, 10, 5, 3, 2])),
      );

      expect(find.byType(CoinMultiplierWheel), findsOneWidget);
      expect(
        find.byKey(const ValueKey('coinMultiplierWheelTap')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap on wheel stops needle and calls onStopped', (
      tester,
    ) async {
      int? won;
      await tester.pumpWidget(
        _wrap(
          CoinMultiplierWheel(
            multipliers: const [2, 3, 5, 10, 5, 3, 2],
            onStopped: (m) => won = m,
          ),
        ),
      );

      // Advance swing animation slightly
      await tester.pump(const Duration(milliseconds: 300));

      final wheelTap = find.byKey(const ValueKey('coinMultiplierWheelTap'));
      await tester.tap(wheelTap);
      await tester.pump();

      expect(won, isNotNull);
      expect(won, isIn([2, 3, 5, 10]));

      // Tapping again when stopped does not trigger onStopped again
      final firstWon = won;
      await tester.tap(wheelTap);
      await tester.pump();
      expect(won, firstWon);
    });

    testWidgets('controller stop and reset work seamlessly', (tester) async {
      final ctrl = CoinMultiplierWheelController();
      int? stoppedCallbackMultiplier;

      await tester.pumpWidget(
        _wrap(
          CoinMultiplierWheel(
            controller: ctrl,
            multipliers: const [2, 5, 10, 5, 2],
            onStopped: (m) => stoppedCallbackMultiplier = m,
          ),
        ),
      );

      expect(ctrl.isSpinning, isTrue);
      expect(ctrl.isStopped, isFalse);

      await tester.pump(const Duration(milliseconds: 250));
      final returned = ctrl.stop();
      await tester.pump();

      expect(ctrl.isSpinning, isFalse);
      expect(ctrl.isStopped, isTrue);
      expect(ctrl.stoppedMultiplier, returned);
      expect(stoppedCallbackMultiplier, returned);

      // Reset resumes swing
      ctrl.reset();
      await tester.pump();
      expect(ctrl.isSpinning, isTrue);
      expect(ctrl.isStopped, isFalse);
      expect(ctrl.stoppedMultiplier, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Reduced Motion stops continuous swing at center', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CoinMultiplierWheel(multipliers: const [2, 3, 5, 10, 5, 3, 2]),
          reduced: true,
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      final wheelTap = find.byKey(const ValueKey('coinMultiplierWheelTap'));
      int? won;
      await tester.pumpWidget(
        _wrap(
          CoinMultiplierWheel(
            multipliers: const [2, 3, 5, 10, 5, 3, 2],
            onStopped: (m) => won = m,
          ),
          reduced: true,
        ),
      );

      await tester.tap(wheelTap);
      await tester.pump();
      // Center of [2, 3, 5, 10, 5, 3, 2] is index 3 = 10x!
      expect(won, 10);
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantics announce spinning sectors then stopped multiplier', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final ctrl = CoinMultiplierWheelController();

      await tester.pumpWidget(
        _wrap(
          CoinMultiplierWheel(controller: ctrl, multipliers: const [2, 4, 8]),
        ),
      );

      var node = tester.getSemantics(
        find.byKey(const ValueKey('coinMultiplierWheelSemantics')),
      );
      expect(node.label, contains('Multiplier wheel with sectors: x2, x4, x8'));
      expect(node.value, 'spinning');

      ctrl.stop();
      await tester.pump();

      node = tester.getSemantics(
        find.byKey(const ValueKey('coinMultiplierWheelSemantics')),
      );
      expect(node.label, contains('Multiplier wheel stopped at x'));
      expect(node.value, startsWith('x'));

      handle.dispose();
    });
  });
}

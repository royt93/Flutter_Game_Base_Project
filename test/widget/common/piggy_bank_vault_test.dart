import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/piggy_bank_vault.dart';

void main() {
  group('piggy bank calculations', () {
    test('fill ratio clamps between zero and one', () {
      expect(piggyBankFillRatio(amount: 25, capacity: 100), 0.25);
      expect(piggyBankFillRatio(amount: 150, capacity: 100), 1);
      expect(piggyBankFillRatio(amount: 0, capacity: 100), 0);
      expect(piggyBankIsFull(amount: 100, capacity: 100), isTrue);
      expect(piggyBankIsFull(amount: 99, capacity: 100), isFalse);
    });

    test('invalid capacity and negative amount reject', () {
      expect(
        () => piggyBankFillRatio(amount: 1, capacity: 0),
        throwsArgumentError,
      );
      expect(
        () => piggyBankFillRatio(amount: -1, capacity: 10),
        throwsArgumentError,
      );
    });
  });

  testWidgets('25%, 50% and 100% show amount; only full unlocked pulses', (
    tester,
  ) async {
    var amount = 250;
    var unlocked = true;
    var breaks = 0;
    late StateSetter update;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MaterialApp(
            home: Scaffold(
              body: PiggyBankVault(
                amount: amount,
                capacity: 1000,
                isUnlocked: unlocked,
                onBreak: () => breaks++,
                onUnlock: () {},
              ),
            ),
          );
        },
      ),
    );
    expect(find.text('250 / 1000 coins'), findsOneWidget);
    expect(find.byKey(const ValueKey('piggyBankPulse')), findsNothing);
    update(() => amount = 500);
    await tester.pump();
    expect(find.text('500 / 1000 coins'), findsOneWidget);
    expect(find.byKey(const ValueKey('piggyBankPulse')), findsNothing);

    update(() => amount = 1000);
    await tester.pump();
    expect(find.byKey(const ValueKey('piggyBankPulse')), findsOneWidget);
    var peakScale = 1.0;
    for (var i = 0; i < 9; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final scale = tester
          .widget<Transform>(
            find.byKey(const ValueKey('piggyBankPulseTransform')),
          )
          .transform
          .entry(0, 0);
      if (scale > peakScale) peakScale = scale;
    }
    expect(peakScale, greaterThan(1));
    await tester.tap(find.byKey(const Key('piggyBankBreak')));
    expect(breaks, 1);

    update(() => unlocked = false);
    await tester.pump();
    expect(find.byKey(const Key('piggyBankUnlock')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced Motion never starts pulse ticker', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: PiggyBankVault(
              amount: 100,
              capacity: 100,
              onBreak: null,
              onUnlock: null,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('piggyBankPulse')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

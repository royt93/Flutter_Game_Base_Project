import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/streak_repair_dialog.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_dialog.dart';

void main() {
  test('rejects invalid streak day and repair price', () {
    expect(
      () => StreakRepairDialog(streakDays: 0, onRepair: () {}, onSkip: () {}),
      throwsArgumentError,
    );
    expect(
      () => StreakRepairDialog(
        streakDays: 7,
        costGems: -1,
        onRepair: () {},
        onSkip: () {},
      ),
      throwsArgumentError,
    );
  });

  testWidgets('shows streak length and optional caller-owned repair price', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreakRepairDialog(
            streakDays: 14,
            costGems: 25,
            onRepair: () {},
            onSkip: () {},
          ),
        ),
      ),
    );

    expect(find.text('Streak Lost!'), findsOneWidget);
    expect(find.textContaining('14-day streak'), findsOneWidget);
    expect(find.text('Repair (25 gems)'), findsWidgets);
    expect(find.text('Start Over'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repair and skip actions call only their own callbacks', (
    tester,
  ) async {
    var repairs = 0;
    var skips = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreakRepairDialog(
            streakDays: 7,
            costGems: null,
            onRepair: () => repairs++,
            onSkip: () => skips++,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('streakRepairConfirm')));
    await tester.pump();
    expect(repairs, 1);
    expect(skips, 0);
    await tester.tap(find.byKey(const ValueKey('streakRepairSkip')));
    await tester.pump();
    expect(repairs, 1);
    expect(skips, 1);
  });

  testWidgets('show helper dismisses dialog after repair', (tester) async {
    var repairs = 0;
    var skips = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('openRepairDialog'),
              onPressed: () => StreakRepairDialog.show(
                context,
                streakDays: 9,
                costGems: 10,
                onRepair: () => repairs++,
                onSkip: () => skips++,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('openRepairDialog')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Streak Lost!'), findsOneWidget);
    final repairButton = tester.widget<NeonDialogButton>(
      find.byWidgetPredicate(
        (w) => w is NeonDialogButton && w.action.label == 'Repair (10 gems)',
      ),
    );
    repairButton.action.onTap();
    await tester.pump(const Duration(milliseconds: 300));
    expect(repairs, 1);
    expect(skips, 0);
    expect(find.text('Streak Lost!'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced Motion keeps icon at rest', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: StreakRepairDialog(
              streakDays: 3,
              onRepair: _noop,
              onSkip: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final transform = tester.widget<Transform>(
      find
          .ancestor(
            of: find.byIcon(Icons.ac_unit_rounded),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(transform.transform.entry(0, 0), 1);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}

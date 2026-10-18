import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_dialog.dart';

Widget _subject({
  int streakDays = 7,
  int shieldCount = 2,
  String missedDateLabel = 'Yesterday',
  VoidCallback? onUseShield,
  VoidCallback? onRepair,
  VoidCallback? onDismiss,
  String title = 'Streak Protected!',
  String? message,
  bool showActions = true,
  bool disableAnimations = false,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: child!,
  ),
  home: Scaffold(
    body: Center(
      child: SingleChildScrollView(
        child: StreakShieldCard(
          streakDays: streakDays,
          shieldCount: shieldCount,
          missedDateLabel: missedDateLabel,
          onUseShield: onUseShield,
          onRepair: onRepair,
          onDismiss: onDismiss,
          title: title,
          message: message,
          showActions: showActions,
        ),
      ),
    ),
  ),
);

void main() {
  group('StreakShieldCard validation', () {
    test('rejects negative streakDays or shieldCount', () {
      expect(
        () => StreakShieldCard(streakDays: -1, shieldCount: 1),
        throwsArgumentError,
      );
      expect(
        () => StreakShieldCard(streakDays: 5, shieldCount: -1),
        throwsArgumentError,
      );
    });

    test('rejects empty title and button labels', () {
      expect(
        () => StreakShieldCard(streakDays: 3, shieldCount: 1, title: '  '),
        throwsArgumentError,
      );
      expect(
        () =>
            StreakShieldCard(streakDays: 3, shieldCount: 1, useShieldLabel: ''),
        throwsArgumentError,
      );
      expect(
        () => StreakShieldCard(streakDays: 3, shieldCount: 1, repairLabel: ' '),
        throwsArgumentError,
      );
      expect(
        () => StreakShieldCard(
          streakDays: 3,
          shieldCount: 1,
          dismissLabel: '   ',
        ),
        throwsArgumentError,
      );
    });
  });

  group('StreakShieldCard rendering & actions', () {
    testWidgets('shows streak and shield metrics and invokes onUseShield', (
      tester,
    ) async {
      var shieldUsed = false;
      await tester.pumpWidget(
        _subject(
          streakDays: 14,
          shieldCount: 3,
          onUseShield: () => shieldUsed = true,
        ),
      );

      expect(find.text('14 days'), findsOneWidget);
      expect(find.text('3 left'), findsOneWidget);
      expect(find.byKey(const ValueKey('streakShieldUseBtn')), findsOneWidget);
      expect(find.byKey(const ValueKey('streakShieldRepairBtn')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('streakShieldUseBtn')));
      await tester.pump();
      expect(shieldUsed, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'shows Repair button when out of shields and invokes onRepair',
      (tester) async {
        var repaired = false;
        await tester.pumpWidget(
          _subject(
            streakDays: 10,
            shieldCount: 0,
            onUseShield: () {},
            onRepair: () => repaired = true,
          ),
        );

        expect(find.text('0 left'), findsOneWidget);
        expect(find.byKey(const ValueKey('streakShieldUseBtn')), findsNothing);
        expect(
          find.byKey(const ValueKey('streakShieldRepairBtn')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('streakShieldRepairBtn')));
        await tester.pump();
        expect(repaired, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('invokes onDismiss when provided', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        _subject(
          streakDays: 5,
          shieldCount: 1,
          onDismiss: () => dismissed = true,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('streakShieldDismissBtn')));
      await tester.pump();
      expect(dismissed, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantics includes streak and shield metrics', (tester) async {
      await tester.pumpWidget(_subject(streakDays: 8, shieldCount: 2));

      final semantics = tester.widget<Semantics>(
        find.byKey(const ValueKey('streakShieldCardSemantics')),
      );
      expect(semantics.properties.label, contains('8 day streak'));
      expect(
        semantics.properties.label,
        contains('2 freeze shields available'),
      );
    });

    testWidgets('static .show opens dialog overlay and handles actions', (
      tester,
    ) async {
      var shieldUsed = false;
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => StreakShieldCard.show(
                  context,
                  streakDays: 12,
                  shieldCount: 1,
                  onUseShield: () => shieldUsed = true,
                  onDismiss: () => dismissed = true,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Streak Protection'), findsOneWidget);
      expect(find.text('12 days'), findsOneWidget);

      final useAction = tester.widget<NeonDialogButton>(
        find.byWidgetPredicate(
          (w) => w is NeonDialogButton && w.action.label == 'Use Shield',
        ),
      );
      useAction.action.onTap();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(shieldUsed, isTrue);
      expect(dismissed, isFalse);
    });

    testWidgets('renders cleanly under reduced motion', (tester) async {
      await tester.pumpWidget(_subject(disableAnimations: true));
      expect(find.text('Current Streak'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unmount during entrance does not throw', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => StreakShieldCard.show(
                  context,
                  streakDays: 5,
                  shieldCount: 1,
                  onUseShield: () {},
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  });
}

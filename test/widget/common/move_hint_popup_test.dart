import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/move_hint_popup.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_dialog.dart';

Widget _wrap(Widget child, {bool reduced = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('MoveHintType', () {
    test('default colors and icons are distinct for each type', () {
      final icons = MoveHintType.values.map((t) => t.defaultIcon).toSet();
      expect(icons.length, MoveHintType.values.length);
      expect(MoveHintType.swap.defaultColor, isNotNull);
      expect(MoveHintType.booster.defaultColor, isNotNull);
      expect(MoveHintType.goal.defaultColor, isNotNull);
    });
  });

  group('MoveHintPopup validation', () {
    test('rejects empty title or message', () {
      expect(
        () => MoveHintPopup(
          type: MoveHintType.swap,
          title: '',
          message: 'Swap two tiles',
          onDismiss: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => MoveHintPopup(
          type: MoveHintType.swap,
          title: 'Hint',
          message: '   ',
          onDismiss: () {},
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative remainingHints', () {
      expect(
        () => MoveHintPopup(
          type: MoveHintType.swap,
          title: 'Hint',
          message: 'Valid message',
          remainingHints: -1,
          onDismiss: () {},
        ),
        throwsArgumentError,
      );
    });

    test('validates coordinate pairings and finiteness', () {
      final key = GlobalKey();
      expect(
        () => MoveHintPopup(
          type: MoveHintType.swap,
          title: 'Hint',
          message: 'Msg',
          fromKey: key, // missing toKey
          onDismiss: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => MoveHintPopup(
          type: MoveHintType.swap,
          title: 'Hint',
          message: 'Msg',
          from: const Offset(10, 20), // missing to
          onDismiss: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => MoveHintPopup(
          type: MoveHintType.swap,
          title: 'Hint',
          message: 'Msg',
          from: const Offset(double.nan, 20),
          to: const Offset(10, 20),
          onDismiss: () {},
        ),
        throwsArgumentError,
      );
    });
  });

  group('MoveHintPopup interactions & state', () {
    testWidgets('has hints: displays Try Hint button and invokes onHintTap', (
      tester,
    ) async {
      var hintTaps = 0;
      var dismissTaps = 0;

      await tester.pumpWidget(
        _wrap(
          MoveHintPopup(
            type: MoveHintType.swap,
            title: 'Swap Tiles',
            message: 'Swap the red and blue gems to make a match 3!',
            remainingHints: 2,
            onHintTap: () => hintTaps++,
            onDismiss: () => dismissTaps++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Swap Tiles'), findsOneWidget);
      expect(find.text('2 hints left'), findsOneWidget);
      expect(find.text('Try Hint'), findsWidgets);
      expect(find.text('Got it'), findsWidgets);

      await tester.pump(const Duration(milliseconds: 300));
      final actionButton = tester.widget<CommonButton>(
        find.byKey(const ValueKey('moveHintActionBtn')),
      );
      actionButton.onTap!.call();
      expect(hintTaps, 1);

      final dismissButton = tester.widget<CommonButton>(
        find.byKey(const ValueKey('moveHintDismissBtn')),
      );
      dismissButton.onTap!.call();
      expect(dismissTaps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'zero hints: switches to Get More (+) and invokes onEmptyHintTap',
      (tester) async {
        var emptyTaps = 0;

        await tester.pumpWidget(
          _wrap(
            MoveHintPopup(
              type: MoveHintType.booster,
              title: 'Use Hammer',
              message: 'Break this obstacle with a hammer booster.',
              remainingHints: 0,
              onEmptyHintTap: () => emptyTaps++,
              onDismiss: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Out of hints!'), findsOneWidget);
        expect(find.text('Get More (+)'), findsWidgets);

        await tester.pump(const Duration(milliseconds: 300));
        final actionButton = tester.widget<CommonButton>(
          find.byKey(const ValueKey('moveHintActionBtn')),
        );
        actionButton.onTap!.call();
        expect(emptyTaps, 1);
      },
    );

    testWidgets(
      'custom hint content takes precedence over default illustration',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            MoveHintPopup(
              type: MoveHintType.custom,
              title: 'Custom Hint',
              message: 'Look at the highlighted row.',
              hintContent: const Text('CUSTOM_ILLUSTRATION'),
              onDismiss: () {},
            ),
          ),
        );

        expect(find.text('CUSTOM_ILLUSTRATION'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('semantics announce title, message and hints count', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _wrap(
          MoveHintPopup(
            type: MoveHintType.goal,
            title: 'Goal Reminder',
            message: 'Focus on clearing 5 more cherries.',
            remainingHints: 3,
            onDismiss: () {},
          ),
        ),
      );

      final node = tester.getSemantics(
        find.byKey(const ValueKey('moveHintSemantics')),
      );
      expect(node.label, contains('Goal Reminder'));
      expect(node.label, contains('Focus on clearing 5 more cherries.'));
      expect(node.label, contains('3 hints remaining'));

      handle.dispose();
    });
  });

  group('MoveHintPopup.show overlay helper', () {
    testWidgets('opens via overlay and dismiss button closes', (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const ValueKey('openHintBtn'),
                onPressed: () => MoveHintPopup.show(
                  context,
                  type: MoveHintType.swap,
                  title: 'Swap Move',
                  message: 'Swap these two adjacent gems.',
                  remainingHints: 1,
                  onDismiss: () => dismissed = true,
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('openHintBtn')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Swap Move'), findsWidgets);

      final dismissButton = tester.widget<NeonDialogButton>(
        find.byWidgetPredicate(
          (w) => w is NeonDialogButton && w.action.label == 'Got it',
        ),
      );
      dismissButton.action.onTap();
      await tester.pump(const Duration(milliseconds: 300));
      expect(dismissed, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}

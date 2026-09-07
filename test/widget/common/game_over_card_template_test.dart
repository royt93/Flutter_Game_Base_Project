import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/game_over_card_template.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Material(child: Center(child: child)));

void main() {
  group('GameOverCardTemplate', () {
    testWidgets('renders title, message and stat lines', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GameOverCardTemplate(
            title: 'Out of moves!',
            message: 'So close.',
            statLines: const ['Score: 1,200'],
            primaryActionLabel: 'Retry',
            onPrimaryAction: () {},
          ),
        ),
      );

      expect(find.text('Out of moves!'), findsWidgets);
      expect(find.text('So close.'), findsOneWidget);
      expect(find.text('Score: 1,200'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping primary action calls onPrimaryAction', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          GameOverCardTemplate(
            title: 'Out of moves!',
            primaryActionLabel: 'Retry',
            onPrimaryAction: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.text('Retry').first);
      await tester.pump();
      expect(tapped, true);
    });

    testWidgets(
      'secondaryActionLabel null → no second button, không throw',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            GameOverCardTemplate(
              title: 'Out of moves!',
              primaryActionLabel: 'Retry',
              onPrimaryAction: () {},
            ),
          ),
        );

        expect(find.text('Home'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'secondaryActionLabel truyền vào → render nút thứ 2, tap gọi đúng callback',
      (tester) async {
        var secondaryTapped = false;
        await tester.pumpWidget(
          _wrap(
            GameOverCardTemplate(
              title: 'Out of moves!',
              primaryActionLabel: 'Retry',
              onPrimaryAction: () {},
              secondaryActionLabel: 'Home',
              onSecondaryAction: () => secondaryTapped = true,
            ),
          ),
        );

        expect(find.text('Home'), findsWidgets);
        await tester.tap(find.text('Home').first);
        await tester.pump();
        expect(secondaryTapped, true);
      },
    );

    testWidgets('message null → không render dòng message, không throw', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          GameOverCardTemplate(
            title: 'Out of moves!',
            primaryActionLabel: 'Retry',
            onPrimaryAction: () {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

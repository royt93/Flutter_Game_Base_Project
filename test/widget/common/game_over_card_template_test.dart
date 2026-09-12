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

    testWidgets(
      'ENH-34: có entrance animation (scale+fade, easeOutBack, 320ms)',
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

        final builder = tester.widget<TweenAnimationBuilder<double>>(
          find.byType(TweenAnimationBuilder<double>),
        );
        expect(builder.duration, const Duration(milliseconds: 320));
        expect(builder.curve, Curves.easeOutBack);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'ENH-34: Reduce Motion bật → entrance animation collapse (duration = 0)',
      (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: _wrap(
              GameOverCardTemplate(
                title: 'Out of moves!',
                primaryActionLabel: 'Retry',
                onPrimaryAction: () {},
              ),
            ),
          ),
        );

        final builder = tester.widget<TweenAnimationBuilder<double>>(
          find.byType(TweenAnimationBuilder<double>),
        );
        expect(builder.duration, Duration.zero);
        expect(tester.takeException(), isNull);
      },
    );

    group('ENH-51: button width tracks the card, not a fixed 240px', () {
      testWidgets(
        'card hẹp bất thường (200px) → không RenderFlex overflow',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Material(
                child: Center(
                  child: SizedBox(
                    width: 200,
                    child: GameOverCardTemplate(
                      title: 'Out of moves!',
                      primaryActionLabel: 'Retry',
                      onPrimaryAction: () {},
                      secondaryActionLabel: 'Home',
                      onSecondaryAction: () {},
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'card RỘNG hơn 240px → nút co giãn lấp đầy, không còn dừng ở '
        'mặc định cố định 240px của CommonButton',
        (tester) async {
          const cardWidth = 320.0;
          await tester.pumpWidget(
            MaterialApp(
              home: Material(
                child: Center(
                  child: SizedBox(
                    width: cardWidth,
                    child: GameOverCardTemplate(
                      title: 'Out of moves!',
                      primaryActionLabel: 'Retry',
                      onPrimaryAction: () {},
                    ),
                  ),
                ),
              ),
            ),
          );

          final buttonBox = tester.renderObject<RenderBox>(
            find
                .ancestor(
                  of: find.text('Retry').first,
                  matching: find.byType(SizedBox),
                )
                .first,
          );
          expect(
            buttonBox.size.width,
            greaterThan(240),
            reason: 'phải rộng hơn mặc định cố định 240px của CommonButton, '
                'lấp đầy chiều rộng card $cardWidth px (trừ padding)',
          );
          expect(tester.takeException(), isNull);
        },
      );
    });
  });
}

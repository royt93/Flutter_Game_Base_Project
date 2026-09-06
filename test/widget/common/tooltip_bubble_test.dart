import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/tooltip_bubble.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Material(child: Center(child: child)));

void main() {
  group('TooltipBubble', () {
    testWidgets('renders arbitrary child content', (tester) async {
      await tester.pumpWidget(
        _wrap(const TooltipBubble(child: Icon(Icons.star))),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'TooltipBubble.text() renders the given text via a plain Text child',
      (tester) async {
        await tester.pumpWidget(_wrap(TooltipBubble.text('Tap here')));

        expect(find.text('Tap here'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    for (final direction in TooltipPointerDirection.values) {
      testWidgets('renders without throwing, direction: $direction', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(TooltipBubble.text('Hi', direction: direction)),
        );

        expect(find.byType(CustomPaint), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('custom color is accepted without throwing', (tester) async {
      await tester.pumpWidget(
        _wrap(TooltipBubble.text('Hi', color: NeonTheme.lime)),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('nubAlign at either extreme (0, 1) does not throw', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(TooltipBubble.text('Hi', nubAlign: 0)));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_wrap(TooltipBubble.text('Hi', nubAlign: 1)));
      expect(tester.takeException(), isNull);
    });
  });
}

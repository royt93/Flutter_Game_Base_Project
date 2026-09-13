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

  group('ENH-38: RTL', () {
    // _BubblePainter is private — its `nubAlign` field (no leading
    // underscore) is still reachable via dynamic dispatch across the
    // library boundary, so no need to expose the type publicly just to
    // assert on the physical value the painter actually receives.
    double physicalNubAlign(WidgetTester tester) {
      final customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(TooltipBubble),
          matching: find.byType(CustomPaint),
        ),
      );
      final painter = customPaint.painter as dynamic;
      return painter.nubAlign as double;
    }

    testWidgets(
      'LTR: nubAlign=0 (reading-start) → painter nhận physical 0 (không đổi)',
      (tester) async {
        await tester.pumpWidget(_wrap(TooltipBubble.text('Hi', nubAlign: 0)));
        expect(physicalNubAlign(tester), 0);
      },
    );

    testWidgets(
      'RTL: nubAlign=0 (reading-start) → painter nhận physical 1 (đảo ngược, vì start = phải trong RTL)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Center(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: TooltipBubble.text('Hi', nubAlign: 0),
                ),
              ),
            ),
          ),
        );
        expect(physicalNubAlign(tester), 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'RTL: nubAlign=0.25 → painter nhận physical 0.75 (1 - nubAlign)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Center(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: TooltipBubble.text('Hi', nubAlign: 0.25),
                ),
              ),
            ),
          ),
        );
        expect(physicalNubAlign(tester), closeTo(0.75, 0.0001));
      },
    );
  });
}

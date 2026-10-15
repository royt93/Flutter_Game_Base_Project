import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/golden_shimmer_text.dart';

void main() {
  test('goldenShimmerOffsetAt maps progress 0..1 to -1..2', () {
    expect(goldenShimmerOffsetAt(0), -1);
    expect(goldenShimmerOffsetAt(0.5), 0.5);
    expect(goldenShimmerOffsetAt(1), 2);
    expect(goldenShimmerOffsetAt(-1), -1);
    expect(goldenShimmerOffsetAt(2), 2);
  });

  testWidgets(
    'renders StrokeText with accessible label and moving ShaderMask',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: GoldenShimmerText('JACKPOT 1,000,000', fontSize: 32),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ShaderMask), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(GoldenShimmerText)).label,
        'JACKPOT 1,000,000',
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ShaderMask), findsOneWidget);
      expect(find.text('JACKPOT 1,000,000'), findsWidgets);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'Reduced Motion disables shader ticker and renders static StrokeText',
    (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Material(
              child: GoldenShimmerText('NEW RECORD', fontSize: 28),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.text('NEW RECORD'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('TickerMode pauses and resumes shimmer', (tester) async {
    var tickerEnabled = true;
    late StateSetter update;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MaterialApp(
            home: Material(
              child: TickerMode(
                enabled: tickerEnabled,
                child: const GoldenShimmerText('GOLD', fontSize: 30),
              ),
            ),
          );
        },
      ),
    );
    await tester.pump();
    update(() => tickerEnabled = false);
    await tester.pump();
    expect(tester.takeException(), isNull);
    update(() => tickerEnabled = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pauses outside vertical viewport and resumes when visible', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 140,
          child: ListView(
            controller: controller,
            children: [
              const SizedBox(height: 240, child: Text('Spacer above')),
              const GoldenShimmerText('OFFSCREEN', fontSize: 24),
              const SizedBox(height: 500, child: Text('Spacer below')),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ShaderMask), findsOneWidget);

    controller.jumpTo(500);
    await tester.pump();
    expect(find.byType(ShaderMask), findsNothing);

    controller.jumpTo(250);
    await tester.pump();
    await tester.pump();
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('invalid non-positive duration throws ArgumentError', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: GoldenShimmerText(
            'BAD',
            fontSize: 20,
            duration: Duration.zero,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isA<ArgumentError>());
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_bg.dart';

void main() {
  testWidgets(
    'ENH-17: Reduce Motion bật → NeonBg không chạy ticker, vẫn render child',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const MaterialApp(home: NeonBg(child: Text('hello'))),
        ),
      );
      await tester.pump();

      expect(find.text('hello'), findsOneWidget);
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders child over the animated background', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: NeonBg(child: Text('hello'))),
    );
    await tester.pump();

    expect(find.text('hello'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('energyOf callback drives reactive glow without crash', (
    tester,
  ) async {
    var energy = 0.0;
    await tester.pumpWidget(
      MaterialApp(
        home: NeonBg(energyOf: () => energy, child: const SizedBox()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    energy = 1.0;
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
}

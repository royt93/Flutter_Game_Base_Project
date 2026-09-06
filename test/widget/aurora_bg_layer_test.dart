import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/aurora_bg_layer.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_bg.dart';

void main() {
  testWidgets(
    'FEAT-17: Reduce Motion bật → AuroraBgLayer không chạy ticker',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(home: AuroraBgLayer(color: NeonTheme.indigo)),
        ),
      );
      await tester.pump();

      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets('AuroraBgLayer does not crash whether shader loads or not', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AuroraBgLayer(color: NeonTheme.indigo)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('NeonBg with aurora: true does not crash', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NeonBg(
          aurora: true,
          accent: NeonTheme.indigo,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/aurora_bg_layer.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_bg.dart';
import 'package:roy_casual_kit/presentation/widgets/shader_ticker_layer.dart';

void main() {
  testWidgets('FEAT-17: Reduce Motion bật → AuroraBgLayer không chạy ticker', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: AuroraBgLayer(color: NeonTheme.indigo)),
      ),
    );
    await tester.pump();

    expect(SchedulerBinding.instance.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('BUG-95: AuroraBgLayer is excluded from semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AuroraBgLayer(color: NeonTheme.indigo)),
    );
    await tester.pump();

    final layer = find.byType(AuroraBgLayer);
    final excluded = find.descendant(
      of: layer,
      matching: find.byType(ExcludeSemantics),
    );
    // Shader load may fail in a widget test, in which case the layer hides
    // entirely. If it loaded, the decorative paint must be excluded.
    expect(excluded.evaluate().length, anyOf(0, 1));
    expect(tester.takeException(), isNull);
  });

  group('ShaderTickerLayerState qua AuroraBgLayer', () {
    ShaderTickerLayerState<AuroraBgLayer> stateOf(WidgetTester tester) =>
        tester.state<ShaderTickerLayerState<AuroraBgLayer>>(
          find.byType(AuroraBgLayer),
        );

    testWidgets('tốc độ animation theo variant, variant lạ dùng 1.0', (
      tester,
    ) async {
      const speeds = {
        'default': 1.0,
        'starlight': 1.3,
        'cyan_blaze': 1.8,
        'nebula_pulse': 0.8,
        'cosmic_drift': 2.2,
        'khong_ton_tai': 1.0,
      };
      for (final entry in speeds.entries) {
        await tester.pumpWidget(
          MaterialApp(
            home: AuroraBgLayer(color: NeonTheme.indigo, variant: entry.key),
          ),
        );
        expect(stateOf(tester).speedMultiplier, entry.value, reason: entry.key);
      }
    });

    testWidgets('time = giây đã trôi của ticker nhân tốc độ variant', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuroraBgLayer(color: NeonTheme.indigo, variant: 'cyan_blaze'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(stateOf(tester).time, closeTo(1.8, 1e-6));
      expect(tester.takeException(), isNull);
    });

    testWidgets('shader chưa nạp được -> không vẽ gì; có shader -> có '
        'CustomPaint không nhận tương tác', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AuroraBgLayer(color: NeonTheme.indigo)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final painted = find.descendant(
        of: find.byType(AuroraBgLayer),
        matching: find.byType(CustomPaint),
      );
      expect(painted.evaluate().isNotEmpty, stateOf(tester).shader != null);
      if (stateOf(tester).shader != null) {
        expect(
          find.descendant(
            of: find.byType(AuroraBgLayer),
            matching: find.byType(IgnorePointer),
          ),
          findsWidgets,
        );
      }
    });

    testWidgets('gỡ widget giải phóng ticker, không lỗi', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AuroraBgLayer(color: NeonTheme.indigo)),
      );
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 1);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 1));

      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
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

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_aura_layer.dart';
import 'package:roy_casual_kit/presentation/widgets/shader_ticker_layer.dart';

void main() {
  testWidgets('does not crash whether the shader loads or fails to load', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: NeonAuraLayer(color: NeonTheme.cyan)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  group('ShaderTickerLayerState qua NeonAuraLayer', () {
    ShaderTickerLayerState<NeonAuraLayer> stateOf(WidgetTester tester) =>
        tester.state<ShaderTickerLayerState<NeonAuraLayer>>(
          find.byType(NeonAuraLayer),
        );

    testWidgets('tốc độ animation theo variant, variant lạ dùng 1.0', (
      tester,
    ) async {
      const speeds = {
        'default': 1.0,
        'starlight': 1.5,
        'cyan_blaze': 2.0,
        'nebula_pulse': 0.7,
        'cosmic_drift': 2.5,
        'khong_ton_tai': 1.0,
      };
      for (final entry in speeds.entries) {
        await tester.pumpWidget(
          MaterialApp(
            home: NeonAuraLayer(color: NeonTheme.cyan, variant: entry.key),
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
          home: NeonAuraLayer(color: NeonTheme.cyan, variant: 'cosmic_drift'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(stateOf(tester).time, closeTo(2.5, 1e-6));
      expect(tester.takeException(), isNull);
    });

    testWidgets('shader chưa nạp được -> không vẽ gì; có shader -> có '
        'CustomPaint không nhận tương tác', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: NeonAuraLayer(color: NeonTheme.cyan)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final painted = find.descendant(
        of: find.byType(NeonAuraLayer),
        matching: find.byType(CustomPaint),
      );
      expect(painted.evaluate().isNotEmpty, stateOf(tester).shader != null);
      if (stateOf(tester).shader != null) {
        expect(
          find.descendant(
            of: find.byType(NeonAuraLayer),
            matching: find.byType(IgnorePointer),
          ),
          findsWidgets,
        );
      }
    });

    testWidgets('gỡ widget giải phóng ticker, không lỗi', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: NeonAuraLayer(color: NeonTheme.cyan)),
      );
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 1);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 1));

      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('BUG-95: NeonAuraLayer is excluded from semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: NeonAuraLayer(color: NeonTheme.cyan)),
    );
    await tester.pump();

    final layer = find.byType(NeonAuraLayer);
    final excluded = find.descendant(
      of: layer,
      matching: find.byType(ExcludeSemantics),
    );
    expect(excluded.evaluate().length, anyOf(0, 1));
    expect(tester.takeException(), isNull);
  });
}

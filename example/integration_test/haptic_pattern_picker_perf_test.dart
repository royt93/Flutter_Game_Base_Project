import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

final _options = [
  HapticPatternOption(
    id: 'soft',
    label: 'Soft',
    pattern: HapticPattern([const HapticPulse(level: HapticLevel.light)]),
  ),
  HapticPatternOption(
    id: 'reward',
    label: 'Reward',
    pattern: HapticPattern.reward,
  ),
  HapticPatternOption(
    id: 'error',
    label: 'Error',
    pattern: HapticPattern.error,
  ),
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('FEAT-174: toggle 3 pattern selections and preview states', (
    tester,
  ) async {
    var selected = 'soft';
    var previewCount = 0;
    var busy = false;
    final frames = <FrameTiming>[];
    void record(List<FrameTiming> batch) => frames.addAll(batch);

    Widget harness() => MaterialApp(
      home: Scaffold(
        body: Center(
          child: StatefulBuilder(
            builder: (context, setState) => HapticPatternPicker(
              options: _options,
              selectedId: selected,
              busy: busy,
              onSelect: (id) => setState(() => selected = id ?? 'soft'),
              onPreview: (_) => setState(() {
                previewCount++;
                busy = !busy;
              }),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(harness());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    SchedulerBinding.instance.addTimingsCallback(record);
    try {
      await tester.runAsync(() async {
        for (var i = 0; i < 100; i++) {
          selected = _options[i % _options.length].id;
          busy = i.isOdd;
          await tester.pumpWidget(harness());
          await tester.pump(const Duration(milliseconds: 20));
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(record);
    }
    expect(frames.length, greaterThan(100));
    expect(previewCount, lessThanOrEqualTo(100));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);

    final total = frames.map((f) => f.totalSpan.inMicroseconds).toList()
      ..sort();
    final work =
        frames
            .map(
              (f) => math.max(
                f.buildDuration.inMicroseconds,
                f.rasterDuration.inMicroseconds,
              ),
            )
            .toList()
          ..sort();
    double percentile(List<int> values, double p) =>
        values[(values.length * p).ceil() - 1] / 1000;
    final slow = work.where((us) => us > 16667).length;
    final result = {
      'options': _options.length,
      'updates': 100,
      'previews': previewCount,
      'frameCount': frames.length,
      'totalSpanMs': {
        'p50': percentile(total, .5),
        'p95': percentile(total, .95),
        'p99': percentile(total, .99),
      },
      'maxBuildRasterMs': {
        'p50': percentile(work, .5),
        'p95': percentile(work, .95),
        'p99': percentile(work, .99),
      },
      'budgetMs': 16.667,
      'slowFrames': slow,
      'slowFramePercent': slow * 100 / frames.length,
    };
    // ignore: avoid_print
    print('FEAT-174_METRICS ${jsonEncode(result)}');
  });
}

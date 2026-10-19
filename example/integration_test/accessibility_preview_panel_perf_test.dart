import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('FEAT-172: toggle scale and highlights for 100 target keys', (
    tester,
  ) async {
    final keys = List.generate(100, (_) => GlobalKey());
    final scale = ValueNotifier<double>(1);
    final frames = <FrameTiming>[];
    void record(List<FrameTiming> values) => frames.addAll(values);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccessibilityPreviewPanel(
            maxHeight: 700,
            targets: keys,
            preview: ValueListenableBuilder<double>(
              valueListenable: scale,
              builder: (_, width, _) => Wrap(
                children: [
                  for (var i = 0; i < keys.length; i++)
                    SizedBox(
                      key: keys[i],
                      width: 50 + width * 10,
                      height: 42,
                      child: Text('Target $i'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    SchedulerBinding.instance.addTimingsCallback(record);
    try {
      await tester.runAsync(() async {
        for (var i = 0; i < 100; i++) {
          scale.value = i.isEven ? 1.3 : 2;
          await Future<void>.delayed(const Duration(milliseconds: 33));
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(record);
    }
    expect(frames.length, greaterThan(100));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    scale.dispose();
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
    final report = {
      'targets': 100,
      'updates': 100,
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
    print('FEAT-172_METRICS ${jsonEncode(report)}');
  });
}

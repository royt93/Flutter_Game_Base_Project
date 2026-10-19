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
  testWidgets('FEAT-170: change selections among 100 titles', (tester) async {
    final selected = ValueNotifier<String?>(null);
    final frames = <FrameTiming>[];
    void record(List<FrameTiming> batch) => frames.addAll(batch);
    final options = [
      for (var i = 0; i < 100; i++)
        TitleOption(
          id: 'title_$i',
          label: i % 10 == 0
              ? 'A Very Long Player Title Number $i'
              : 'Title $i',
          locked: i % 5 == 4,
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<String?>(
            valueListenable: selected,
            builder: (_, value, _) => SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: TitleChipPicker(
                options: options,
                selectedId: value,
                onSelect: (id) => selected.value = id,
                onLockedTap: (_) {},
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
        for (var i = 0; i < 180; i++) {
          selected.value = 'title_${(i * 5) % 100}';
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
    selected.dispose();
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
      'titles': 100,
      'updates': 180,
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
    print('FEAT-170_METRICS ${jsonEncode(result)}');
  });
}

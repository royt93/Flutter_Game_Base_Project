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

  testWidgets('FEAT-164: rapid quest progress updates and unmount', (
    tester,
  ) async {
    final frames = <FrameTiming>[];
    void record(List<FrameTiming> values) => frames.addAll(values);
    var unmounts = 0;

    for (var cycle = 0; cycle < 3; cycle++) {
      final progress = ValueNotifier<int>(0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ValueListenableBuilder<int>(
                  valueListenable: progress,
                  builder: (_, value, _) => QuestProgressPill(
                    completed: value,
                    total: 180,
                    claimableCount: value ~/ 20,
                    onTap: () {},
                  ),
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
          for (var i = 1; i <= 180; i++) {
            progress.value = i;
            await Future<void>.delayed(const Duration(milliseconds: 16));
          }
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
      } finally {
        SchedulerBinding.instance.removeTimingsCallback(record);
      }
      expect(find.text('Quests 180/180'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
      progress.dispose();
      unmounts++;
      expect(tester.takeException(), isNull);
    }

    expect(frames.length, greaterThan(100));
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
    final slow = work.where((v) => v > 16667).length;
    final report = {
      'updates': 540,
      'unmounts': unmounts,
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
    print('FEAT-164_METRICS ${jsonEncode(report)}');
  });
}

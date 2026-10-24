import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('FEAT-140: count-up frame timings over repeated popup cycles', (
    tester,
  ) async {
    final timings = <FrameTiming>[];
    void record(List<FrameTiming> frames) => timings.addAll(frames);
    final rssAfterUnmount = <int>[];
    var collects = 0;

    Widget host() => MaterialApp(
      home: Scaffold(
        body: Center(
          child: OfflineEarningsPopup(
            key: UniqueKey(),
            coins: 1234567,
            elapsed: const Duration(hours: 4, minutes: 12),
            ratePerSecond: 81.5,
            onCollect: () => collects++,
            onDoubleTap: () {},
          ),
        ),
      ),
    );

    // Warm-up cycle: shader/layout caches are not part of the sample.
    await tester.pumpWidget(host());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1000)),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    SchedulerBinding.instance.addTimingsCallback(record);
    try {
      for (var cycle = 0; cycle < 30; cycle++) {
        await tester.pumpWidget(host());
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1000)),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        if (cycle % 6 == 5) rssAfterUnmount.add(ProcessInfo.currentRss);
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(record);
    }
    expect(timings.length, greaterThan(100));

    final total = timings.map((f) => f.totalSpan.inMicroseconds).toList()
      ..sort();
    final work =
        timings
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
    final report = <String, Object>{
      'mode': kProfileMode ? 'profile' : 'debug',
      'cycles': 30,
      'frameCount': timings.length,
      'totalSpanMs': {
        'p50': percentile(total, 0.50),
        'p95': percentile(total, 0.95),
        'p99': percentile(total, 0.99),
      },
      'maxBuildRasterMs': {
        'p50': percentile(work, 0.50),
        'p95': percentile(work, 0.95),
        'p99': percentile(work, 0.99),
      },
      'budgetMs': 16.667,
      'slowFramePercent': slow * 100 / timings.length,
      'jankCount': slow,
      'rssAfterUnmountBytes': rssAfterUnmount,
    };
    // ignore: avoid_print
    print('FEAT-140_METRICS ${jsonEncode(report)}');

    const budget = WorkloadPerformanceBudget(
      workloadName: 'offline_earnings',
      maxP95Ms: 64.0,
      maxSlowFramePercent: 60.0,
      minFrames: 50,
    );
    final evalResult = budget.evaluate(report);
    expect(
      evalResult.passed,
      isTrue,
      reason: evalResult.violations.map((v) => v.toString()).join('; '),
    );
  });
}

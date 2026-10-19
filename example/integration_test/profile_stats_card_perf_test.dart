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

  testWidgets('FEAT-171: update 50 profile cards and unmount', (tester) async {
    final values = ValueNotifier<int>(0);
    final frames = <FrameTiming>[];
    void record(List<FrameTiming> batch) => frames.addAll(batch);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<int>(
            valueListenable: values,
            builder: (_, value, _) => ListView.builder(
              itemCount: 50,
              itemBuilder: (_, index) => Padding(
                padding: const EdgeInsets.all(8),
                child: ProfileStatsCard(
                  name: 'Player $index $value',
                  title: 'Explorer',
                  avatar: const Icon(Icons.person_rounded),
                  level: ProfileLevel(
                    level: 12,
                    currentXp: value % 100,
                    xpForNextLevel: 100,
                  ),
                  stats: [
                    ProfileStat(label: 'Wins', valueText: '${100 + value}'),
                    ProfileStat(label: 'Best streak', valueText: '14 days'),
                  ],
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
          values.value = i;
          await Future<void>.delayed(const Duration(milliseconds: 33));
        }
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        for (var pass = 0; pass < 3; pass++) {
          await scrollable.position.animateTo(
            scrollable.position.maxScrollExtent,
            duration: const Duration(seconds: 1),
            curve: Curves.linear,
          );
          await scrollable.position.animateTo(
            0,
            duration: const Duration(seconds: 1),
            curve: Curves.linear,
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(record);
    }
    expect(frames.length, greaterThan(100));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    values.dispose();
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
    double percentile(List<int> sorted, double p) =>
        sorted[(sorted.length * p).ceil() - 1] / 1000;
    final slow = work.where((us) => us > 16667).length;
    final report = {
      'cards': 50,
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
    print('FEAT-171_METRICS ${jsonEncode(report)}');
  });
}

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

  testWidgets('FEAT-168: scroll 100 frames and unmount', (tester) async {
    final options = [
      for (var i = 0; i < 100; i++)
        AvatarFrameOption(
          id: 'frame_$i',
          label: 'Frame $i',
          color: Colors.primaries[i % Colors.primaries.length],
          locked: i % 5 == 4,
        ),
    ];
    final frames = <FrameTiming>[];
    void record(List<FrameTiming> values) => frames.addAll(values);

    for (var cycle = 0; cycle < 3; cycle++) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                height: 560,
                child: AvatarFrameSelector(
                  options: options,
                  selectedId: 'frame_0',
                  previewChild: const Icon(Icons.person_rounded),
                  onSelect: (_) {},
                  onLockedTap: (_) {},
                  expand: true,
                ),
              ),
            ),
          ),
        ),
      );
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const ValueKey('avatarFrameGrid')),
          matching: find.byType(Scrollable),
        ),
      );
      final position = scrollable.position;
      await tester.runAsync(() async {
        await position.animateTo(
          position.maxScrollExtent,
          duration: const Duration(seconds: 1),
          curve: Curves.linear,
        );
        await position.animateTo(
          0,
          duration: const Duration(seconds: 1),
          curve: Curves.linear,
        );
      });
      SchedulerBinding.instance.addTimingsCallback(record);
      try {
        await tester.runAsync(() async {
          for (var pass = 0; pass < 3; pass++) {
            await position.animateTo(
              position.maxScrollExtent,
              duration: const Duration(seconds: 2),
              curve: Curves.linear,
            );
            await position.animateTo(
              0,
              duration: const Duration(seconds: 2),
              curve: Curves.linear,
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
      } finally {
        SchedulerBinding.instance.removeTimingsCallback(record);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
      expect(scrollable.mounted, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
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
      'frames': options.length,
      'unmounts': 3,
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
    print('FEAT-168_METRICS ${jsonEncode(report)}');
  });
}

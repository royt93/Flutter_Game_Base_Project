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
  testWidgets('FEAT-163: scroll 100 friend requests and unmount', (
    tester,
  ) async {
    final frames = <FrameTiming>[];
    void record(List<FrameTiming> values) => frames.addAll(values);
    for (var cycle = 0; cycle < 3; cycle++) {
      final controller = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              controller: controller,
              itemCount: 100,
              itemBuilder: (_, index) => Padding(
                padding: const EdgeInsets.all(8),
                child: FriendRequestTile(
                  request: FriendRequestItem(
                    requestId: '$index',
                    name: 'Friend $index',
                    subtitle: 'Level ${index + 1}',
                    mutualFriendsCount: index,
                  ),
                  busyAction: index % 10 == 0
                      ? FriendRequestAction.accept
                      : null,
                  onAccept: (_) {},
                  onDecline: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(seconds: 1),
          curve: Curves.linear,
        );
        await controller.animateTo(
          0,
          duration: const Duration(seconds: 1),
          curve: Curves.linear,
        );
      });
      SchedulerBinding.instance.addTimingsCallback(record);
      try {
        await tester.runAsync(() async {
          await controller.animateTo(
            controller.position.maxScrollExtent,
            duration: const Duration(seconds: 4),
            curve: Curves.linear,
          );
          await controller.animateTo(
            0,
            duration: const Duration(seconds: 4),
            curve: Curves.linear,
          );
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
      } finally {
        SchedulerBinding.instance.removeTimingsCallback(record);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.hasClients, isFalse);
      controller.dispose();
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
      'requests': 100,
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
    print('FEAT-163_METRICS ${jsonEncode(report)}');
  });
}

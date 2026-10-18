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

  testWidgets(
    'FEAT-159: long grid frame timings and scroll resource disposal',
    (tester) async {
      final characters = List.generate(
        60,
        (index) => CharacterCollectionItem(
          id: 'character_$index',
          name: 'Character $index',
          rarity: ItemRarity.values[index % ItemRarity.values.length],
          isOwned: index.isEven,
          isSelected: index == 0,
        ),
      );
      final beforeOrphans = MemoryWatchdog.orphans().map((e) => e.id).toSet();
      final timings = <FrameTiming>[];
      void record(List<FrameTiming> frames) => timings.addAll(frames);
      final rssAfterUnmount = <int>[];
      var disposedPositions = 0;

      for (var cycle = 0; cycle < 5; cycle++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CharacterCollectionGrid(
                    characters: characters,
                    onCharacterTap: (_) {},
                    onSelect: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        final grid = find.byKey(const ValueKey('characterCollectionGrid'));
        final scrollable = tester.state<ScrollableState>(
          find.descendant(of: grid, matching: find.byType(Scrollable)),
        );
        final position = scrollable.position;
        final handle = MemoryWatchdog.track(
          WatchdogKind.controller,
          owner: 'CharacterCollectionGrid.ScrollPosition',
        );
        // Warm shader/layout caches before sampling real engine frames.
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
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        if (cycle == 0) {
          SchedulerBinding.instance.addTimingsCallback(record);
          try {
            await tester.runAsync(() async {
              for (var pass = 0; pass < 8; pass++) {
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
          expect(timings.length, greaterThan(100));
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 200));
        expect(scrollable.mounted, isFalse);
        if (kDebugMode) {
          expect(
            () => ChangeNotifier.debugAssertNotDisposed(position),
            throwsFlutterError,
          );
        }
        MemoryWatchdog.release(handle);
        disposedPositions++;
        expect(
          MemoryWatchdog.orphans().where((e) => !beforeOrphans.contains(e.id)),
          isEmpty,
        );
        rssAfterUnmount.add(ProcessInfo.currentRss);
        expect(tester.takeException(), isNull);
      }

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
        'characters': characters.length,
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
        'disposedScrollPositions': disposedPositions,
        'watchdogEnabled': kDebugMode,
        'newWatchdogOrphans': MemoryWatchdog.orphans()
            .where((e) => !beforeOrphans.contains(e.id))
            .length,
        'rssAfterUnmountBytes': rssAfterUnmount,
      };
      binding.reportData = {'FEAT-159': report};
      debugPrint('FEAT-159_METRICS ${jsonEncode(report)}');
    },
  );
}

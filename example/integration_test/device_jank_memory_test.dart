import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';
import 'package:roy_casual_kit_example/main.dart' as app;
import 'package:roy_casual_kit_example/screens/match3_lite_screen.dart';
import 'package:roy_casual_kit_example/screens/widget_showcase_screen.dart';

/// Manual physical-device run only; do not use an emulator for frame/memory data.
///
///   flutter test integration_test/device_jank_memory_test.dart \
///     -d DEVICE_ID --dart-define=E2E_TEST=true
///
/// Capture process memory immediately before and after this command with
/// `adb shell dumpsys meminfo com.galaxyjoy.roycasualkit` while the process is
/// still alive. The test prints independent FrameTiming summaries per scene.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('manual device frame profile: Match-3 and Widget Showcase', (
    tester,
  ) async {
    await app.app();
    await tester.pump(const Duration(seconds: 2));

    final energy =
        EnergyService.maybe ??
        Get.put<EnergyService>(EnergyService(maxEnergy: 5), permanent: true);
    await energy.grantInfiniteLives(const Duration(hours: 1));
    await StorageService.to.remove('match3_lite_save_v2');
    await StorageService.to.setBool(StorageKeys.onboardingSeenV1, true);
    Get.delete<OnboardingCoordinatorService>(force: true);
    Get.put(OnboardingCoordinatorService(), permanent: true);

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.push<void>(
      MaterialPageRoute(builder: (_) => const Match3LiteScreen()),
    );
    await tester.pump(const Duration(seconds: 1));
    final session = Get.find<GameSessionController>();
    final start = find.byWidgetPredicate(
      (w) => w is CommonButton && w.label == 'match3_start'.tr,
    );
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pump(const Duration(milliseconds: 500));
    for (var step = 0; step < 3; step++) {
      final label = step < 2
          ? 'match3_tutorial_next'.tr
          : 'match3_tutorial_done'.tr;
      final button = find.text(label).first;
      if (button.evaluate().isNotEmpty) {
        await tester.tap(button);
        await tester.pump(const Duration(milliseconds: 350));
      }
    }
    expect(session.snapshot.value.phase, GameSessionPhase.playing);

    final matchFrames = <FrameTiming>[];
    void recordMatch(List<FrameTiming> batch) => matchFrames.addAll(batch);
    SchedulerBinding.instance.addTimingsCallback(recordMatch);
    try {
      // Capture active play, a short board interaction, and pause/resume.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
      // Keep this a rendering-only scene: no taps, dialogs, ads, or platform
      // permission prompts during the measured window.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(recordMatch);
    }
    _printMetrics('match3', matchFrames);
    navigator.pop();
    await tester.pump(const Duration(milliseconds: 500));

    navigator.push<void>(
      MaterialPageRoute(builder: (_) => const WidgetShowcaseScreen()),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(WidgetShowcaseScreen), findsOneWidget);

    final showcaseFrames = <FrameTiming>[];
    void recordShowcase(List<FrameTiming> batch) =>
        showcaseFrames.addAll(batch);
    SchedulerBinding.instance.addTimingsCallback(recordShowcase);
    try {
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      await tester.runAsync(() async {
        for (var i = 0; i < 3; i++) {
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
      });
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(recordShowcase);
    }
    _printMetrics('widget_showcase', showcaseFrames);
    navigator.pop();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}

void _printMetrics(String scene, List<FrameTiming> frames) {
  if (frames.isEmpty) {
    // ignore: avoid_print
    print(
      'DEVICE_FRAME_METRICS ${jsonEncode({'scene': scene, 'frameCount': 0})}',
    );
    return;
  }
  final build = frames.map((f) => f.buildDuration.inMicroseconds).toList()
    ..sort();
  final raster = frames.map((f) => f.rasterDuration.inMicroseconds).toList()
    ..sort();
  final total = frames.map((f) => f.totalSpan.inMicroseconds).toList()..sort();
  double p(List<int> samples, double q) =>
      samples[(samples.length * q).ceil().clamp(1, samples.length) - 1] / 1000;
  final missed = total.where((us) => us > 16667).length;
  // ignore: avoid_print
  print(
    'DEVICE_FRAME_METRICS ${jsonEncode({
      'scene': scene,
      'frameCount': frames.length,
      'buildMs': {'p50': p(build, .50), 'p90': p(build, .90), 'p99': p(build, .99)},
      'rasterMs': {'p50': p(raster, .50), 'p90': p(raster, .90), 'p99': p(raster, .99)},
      'totalSpanMs': {'p50': p(total, .50), 'p90': p(total, .90), 'p99': p(total, .99)},
      'budgetMs': 16.667,
      'framesOverBudget': missed,
      'overBudgetPercent': missed * 100 / frames.length,
    })}',
  );
}

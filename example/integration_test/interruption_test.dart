import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';
import 'package:roy_casual_kit_example/main.dart' as app;
import 'package:roy_casual_kit_example/screens/match3_lite_screen.dart';

/// ENH-124: interruptions against the real Match-3 screen. Manual or weekly,
/// NOT part of push CI:
///
///   flutter test integration_test/interruption_test.dart -d DEVICE_ID \
///       --dart-define=E2E_TEST=true
///
/// Lifecycle states are delivered through the real binding
/// (`handleAppLifecycleStateChanged`), so `RoyLifecycleCoordinator` observes
/// them exactly as on a device. It cannot kill the process or place a call;
/// those stay manual (see `docs/qa/device_matrix.md`).

Future<void> _pumpFor(WidgetTester tester, int ms) async {
  for (var spent = 0; spent < ms; spent += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Delivers [state], then waits (up to 3s) for the session to reach
/// [expected] and prints how long that took: the hooks run in order after a
/// storage flush, so the latency is itself worth recording on a slow device.
Future<void> _sendAndExpect(
  WidgetTester tester,
  GameSessionController session,
  AppLifecycleState state,
  GameSessionPhase expected,
  String reason,
) async {
  final watch = Stopwatch()..start();
  tester.binding.handleAppLifecycleStateChanged(state);
  // While backgrounded the binding stops scheduling frames, so `pump` would
  // wait forever for one (a first run hung ~10 min here): wait in real time.
  final framesOn = state == AppLifecycleState.resumed;
  while (session.snapshot.value.phase != expected && watch.elapsedMilliseconds < 3000) {
    if (framesOn) {
      await tester.pump(const Duration(milliseconds: 50));
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }
  // ignore: avoid_print
  print('interruption: $reason -> ${session.snapshot.value.phase.name} in ${watch.elapsedMilliseconds}ms, hook failures: ${RoyLifecycleCoordinator.maybe?.failures.map((f) => f.name).toList()}');
  expect(session.snapshot.value.phase, expected, reason: reason);
}

Future<void> _sendQuiet(WidgetTester tester, AppLifecycleState state) async {
  tester.binding.handleAppLifecycleStateChanged(state);
  await Future<void>.delayed(const Duration(milliseconds: 100));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Match-3: lifecycle interruptions and rotation keep the session coherent', (
    tester,
  ) async {
    await app.app();
    await tester.pump(const Duration(seconds: 2));
    final EnergyService energy =
        EnergyService.maybe ??
        Get.put<EnergyService>(EnergyService(maxEnergy: 5), permanent: true);
    await energy.grantInfiniteLives(const Duration(hours: 1));
    await StorageService.to.remove('match3_lite_save_v2');
    // A first-time player: the tutorial appears and is walked through below,
    // because marking it seen does not stop `Match3LiteScreen` showing it.
    await StorageService.to.remove(StorageKeys.onboardingSeenV1);
    Get.delete<OnboardingCoordinatorService>(force: true);
    Get.put(OnboardingCoordinatorService(), permanent: true);

    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute<void>(builder: (_) => const Match3LiteScreen()));
    await _pumpFor(tester, 800);
    final session = Get.find<GameSessionController>();
    final lifecycle = RoyLifecycleCoordinator.maybe;
    expect(lifecycle, isNotNull, reason: 'the example boots the lifecycle module');

    final start = find.byWidgetPredicate(
      (w) => w is CommonButton && w.label == 'match3_start'.tr,
    );
    await tester.ensureVisible(start);
    await tester.tap(start);
    await _pumpFor(tester, 600);
    expect(session.snapshot.value.phase, GameSessionPhase.playing);
    for (var step = 0; step < 3; step++) {
      final label = step < 2 ? 'match3_tutorial_next'.tr : 'match3_tutorial_done'.tr;
      await tester.tap(find.text(label).first);
      await _pumpFor(tester, 400);
    }
    expect(find.byType(SpotlightOverlay), findsNothing);

    // Opening the screen can leave the binding `inactive` on a real device
    // (a system dialog taking focus), and the coordinator then ignores the
    // test's own `paused` as "still background". Record it, then start from
    // a known foreground state.
    // ignore: avoid_print
    print('interruption: lifecycle before forcing resumed = '
        '${WidgetsBinding.instance.lifecycleState}, '
        'coordinator=${lifecycle!.state.value.name}');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 300));
    expect(session.snapshot.value.phase, GameSessionPhase.playing);

    // 1. Background and back, five times: always ends playing.
    for (var i = 0; i < 5; i++) {
      await _sendAndExpect(tester, session, AppLifecycleState.paused, GameSessionPhase.paused, 'bg #$i');
      await _sendAndExpect(tester, session, AppLifecycleState.resumed, GameSessionPhase.playing, 'fg #$i');
    }

    // 2. The OS interrupting without a full pause (call banner, system sheet):
    //    inactive -> hidden -> paused is one pause, resumed restores it.
    await _sendQuiet(tester, AppLifecycleState.inactive);
    await _sendQuiet(tester, AppLifecycleState.hidden);
    await _sendAndExpect(tester, session, AppLifecycleState.paused, GameSessionPhase.paused, 'inactive>hidden>paused');
    await _sendAndExpect(tester, session, AppLifecycleState.resumed, GameSessionPhase.playing, 'resumed after system sheet');

    // 3. Rotation mid-game: the board must re-layout without an exception.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    await _pumpFor(tester, 1000);
    expect(tester.takeException(), isNull, reason: 'landscape');
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await _pumpFor(tester, 1000);
    expect(tester.takeException(), isNull, reason: 'portrait');
    await SystemChrome.setPreferredOrientations(const []);

    // 4. A player pause survives a background round trip.
    await tester.tap(find.byKey(const ValueKey('match3_pause')));
    await _pumpFor(tester, 800);
    expect(session.snapshot.value.phase, GameSessionPhase.paused);
    await _sendQuiet(tester, AppLifecycleState.paused);
    await _sendAndExpect(tester, session, AppLifecycleState.resumed, GameSessionPhase.paused, 'player pause survives round trip');

    expect(lifecycle.failures, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

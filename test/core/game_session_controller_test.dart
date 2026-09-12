import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/game_session_controller.dart';
import 'package:roy_casual_kit/core/lifecycle_coordinator.dart';

void main() {
  tearDown(() => Get.reset());

  test('valid flow reaches terminal state and rejects terminal exit', () {
    final c = GameSessionController();
    expect(c.markReady().isSuccess, isTrue);
    expect(c.start().isSuccess, isTrue);
    expect(c.win().isSuccess, isTrue);
    expect(c.start().isSuccess, isFalse);
    expect(c.pause(GamePauseReason.user).isSuccess, isFalse);
  });

  test('nested system/user pause resumes only after both reasons clear', () {
    final c = GameSessionController();
    c.markReady();
    c.start();
    c.pause(GamePauseReason.user);
    c.pause(GamePauseReason.system);
    expect(c.snapshot.value.pauseReasons, {
      GamePauseReason.user,
      GamePauseReason.system,
    });
    c.resume(GamePauseReason.system);
    expect(c.snapshot.value.phase, GameSessionPhase.paused);
    c.resume(GamePauseReason.user);
    expect(c.snapshot.value.phase, GameSessionPhase.playing);
  });

  test('lifecycle bridge and dispose remove callback', () async {
    final lifecycle = RoyLifecycleCoordinator();
    final c = GameSessionController(lifecycle: lifecycle);
    Get.put(c);
    c.markReady();
    c.start();
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);
    expect(c.snapshot.value.phase, GameSessionPhase.paused);
    Get.delete<GameSessionController>();
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(c.snapshot.value.phase, GameSessionPhase.paused);
  });

  testWidgets('consumer can render session state', (tester) async {
    final c = GameSessionController();
    await tester.pumpWidget(
      MaterialApp(home: Obx(() => Text(c.snapshot.value.phase.name))),
    );
    expect(find.text('loading'), findsOneWidget);
    c.markReady();
    await tester.pump();
    expect(find.text('ready'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/lifecycle_coordinator.dart';

void main() {
  tearDown(() => Get.reset());

  test('dispatches each transition once, in hook order', () async {
    final coordinator = RoyLifecycleCoordinator();
    Get.put(coordinator);
    final events = <String>[];
    coordinator.registerHook(
      'first',
      (event) async => events.add('first:$event'),
    );
    coordinator.registerHook(
      'second',
      (event) async => events.add('second:$event'),
    );
    coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
    coordinator.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await Future<void>.delayed(Duration.zero);
    expect(events, [
      'first:RoyLifecycleEvent.background',
      'second:RoyLifecycleEvent.background',
    ]);
  });

  test('isolates hook errors and timeout', () async {
    final coordinator = RoyLifecycleCoordinator(
      hookTimeout: const Duration(milliseconds: 5),
    );
    Get.put(coordinator);
    final events = <String>[];
    coordinator.registerHook('bad', (_) async => throw StateError('boom'));
    coordinator.registerHook(
      'slow',
      (_) async => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    coordinator.registerHook('last', (_) async => events.add('ran'));
    coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(events, ['ran']);
    expect(coordinator.failures.map((e) => e.name), ['bad', 'slow']);
  });

  testWidgets('observer tracks foreground and background', (tester) async {
    final coordinator = RoyLifecycleCoordinator();
    Get.put(coordinator);
    await tester.pumpWidget(const SizedBox());
    coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(coordinator.state.value, RoyLifecycleState.foreground);
    coordinator.didChangeAppLifecycleState(AppLifecycleState.hidden);
    expect(coordinator.state.value, RoyLifecycleState.background);
  });
}

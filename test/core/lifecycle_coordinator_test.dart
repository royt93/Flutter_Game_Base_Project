import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/lifecycle_coordinator.dart';
import 'package:roy_casual_kit/core/storage_service.dart';

void main() {
  tearDown(() => Get.reset());

  group('ENH-60: .maybe', () {
    test('trả về null khi chưa Get.put', () {
      expect(RoyLifecycleCoordinator.maybe, isNull);
    });

    test('trả về đúng instance khi đã đăng ký', () {
      final coordinator = RoyLifecycleCoordinator();
      Get.put(coordinator);
      expect(RoyLifecycleCoordinator.maybe, same(coordinator));
    });
  });

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

  test('detached được coi là background và chạy hook một lần', () async {
    final coordinator = RoyLifecycleCoordinator();
    Get.put(coordinator);
    final events = <RoyLifecycleEvent>[];
    coordinator.registerHook('h', (event) async => events.add(event));

    coordinator.didChangeAppLifecycleState(AppLifecycleState.detached);
    coordinator.didChangeAppLifecycleState(AppLifecycleState.paused); // cùng background: bỏ qua
    await Future<void>.delayed(Duration.zero);

    expect(coordinator.state.value, RoyLifecycleState.background);
    expect(events, [RoyLifecycleEvent.background]);
  });

  test('flush storage lỗi khi vào background: ghi vào failures, hook sau vẫn chạy', () async {
    Get.put<StorageService>(_FlushFailingStorage());
    final coordinator = RoyLifecycleCoordinator();
    Get.put(coordinator);
    final events = <String>[];
    coordinator.registerHook('after', (_) async => events.add('ran'));

    coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(coordinator.failures.map((f) => f.name), ['storage.flush']);
    expect(coordinator.failures.single.error, isA<StateError>());
    expect(events, ['ran']);
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

  group('D3: trimMemoryOnBackground', () {
    test('onTrimMemory được gọi khi app chuyển sang background', () async {
      var trimmed = false;
      final coordinator = RoyLifecycleCoordinator(
        trimMemoryOnBackground: true,
        onTrimMemory: () => trimmed = true,
      );
      Get.put(coordinator);

      coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);

      expect(trimmed, isTrue);
    });

    test('onTrimMemory không được gọi nếu trimMemoryOnBackground = false', () async {
      var trimmed = false;
      final coordinator = RoyLifecycleCoordinator(
        trimMemoryOnBackground: false,
        onTrimMemory: () => trimmed = true,
      );
      Get.put(coordinator);

      coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);

      expect(trimmed, isFalse);
    });

    testWidgets('không truyền onTrimMemory thì clear Flutter image cache mặc định', (
      tester,
    ) async {
      final imageCache = PaintingBinding.instance.imageCache;
      imageCache.maximumSize = 10;
      imageCache.maximumSizeBytes = 1024 * 1024;
      final coordinator = RoyLifecycleCoordinator(trimMemoryOnBackground: true);
      Get.put(coordinator);

      coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 50));

      expect(imageCache.currentSize, 0);
      expect(imageCache.liveImageCount, 0);
      expect(coordinator.failures, isEmpty);
    });

    test('onTrimMemory throw không làm vỡ lifecycle dispatch', () async {
      final coordinator = RoyLifecycleCoordinator(
        trimMemoryOnBackground: true,
        onTrimMemory: () => throw StateError('oom-clean-fail'),
      );
      Get.put(coordinator);

      coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.failures.map((f) => f.name), contains('memory.trim'));
    });
  });
}

class _FlushFailingStorage extends StorageService {
  _FlushFailingStorage() : super(null);

  @override
  Future<void> flush() => Future<void>.error(StateError('flush failed'));
}

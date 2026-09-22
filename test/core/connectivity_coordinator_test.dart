import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/connectivity_coordinator.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/retry_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTimer implements Timer {
  _FakeTimer(this.callback);
  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  late List<_FakeTimer> scheduled;
  Timer fakeCreateTimer(Duration delay, void Function() callback) {
    final timer = _FakeTimer(callback);
    scheduled.add(timer);
    return timer;
  }

  // FakeConnectivitySignal's broadcast StreamController delivers .add()
  // to listeners on a microtask, not synchronously — flush that first so
  // `scheduled` already reflects the debounce timer the just-set signal
  // value created, before picking "the latest" one to fire.
  Future<void> fireLatest() async {
    await Future<void>.delayed(Duration.zero);
    final timer = scheduled.last;
    if (!timer.cancelled) timer.callback();
  }

  setUp(() async {
    scheduled = [];
    SharedPreferences.setMockInitialValues({});
    Get.put(
      StorageService(await SharedPreferences.getInstance()),
      permanent: true,
    );
  });

  group('ConnectivityCoordinator: accessor', () {
    test('maybe trả về null khi chưa Get.put', () {
      expect(ConnectivityCoordinator.maybe, isNull);
    });
  });

  group(
    'ConnectivityCoordinator: interface up nhưng probe fail không báo online giả',
    () {
      test('interface up, probe thành công: online', () async {
        final signal = FakeConnectivitySignal();
        final coordinator = ConnectivityCoordinator(
          signal: signal,
          probe: () async => true,
          createTimer: fakeCreateTimer,
        );

        signal.setHasInterface(true);
        await fireLatest(); // debounce timer -> _handleInterfaceChange
        await Future<void>.delayed(Duration.zero); // để probe Future resolve

        expect(coordinator.state, ConnectivityState.online);
      });

      test(
        'interface up nhưng probe fail liên tục: KHÔNG BAO GIỜ báo online',
        () async {
          final signal = FakeConnectivitySignal();
          final coordinator = ConnectivityCoordinator(
            signal: signal,
            probe: () async => false,
            createTimer: fakeCreateTimer,
          );

          signal.setHasInterface(true);
          await fireLatest();
          await Future<void>.delayed(Duration.zero);

          expect(coordinator.state, isNot(ConnectivityState.online));
        },
      );

      test('interface xuống: offline ngay, không cần chờ probe', () async {
        final signal = FakeConnectivitySignal(initialHasInterface: true);
        final coordinator = ConnectivityCoordinator(
          signal: signal,
          probe: () async => true,
          createTimer: fakeCreateTimer,
        );
        await fireLatest();
        await Future<void>.delayed(Duration.zero);
        expect(coordinator.state, ConnectivityState.online);

        signal.setHasInterface(false);
        await fireLatest();

        expect(coordinator.state, ConnectivityState.offline);
      });
    },
  );

  group('ConnectivityCoordinator: debounce + hysteresis chống flap spam', () {
    test(
      'flap nhanh (true/false/true) trong debounce window: chỉ đánh giá giá trị cuối',
      () async {
        final signal = FakeConnectivitySignal();
        final coordinator = ConnectivityCoordinator(
          signal: signal,
          probe: () async => true,
          createTimer: fakeCreateTimer,
        );

        signal.setHasInterface(true);
        signal.setHasInterface(false);
        signal.setHasInterface(true);
        // Stream broadcast .add() giao tới listener qua microtask, không
        // đồng bộ — flush trước khi soi lại danh sách timer đã tạo.
        await Future<void>.delayed(Duration.zero);
        // 3 lần set -> 3 timer debounce được tạo, nhưng 2 timer đầu bị cancel
        // (bị timer mới cancel), chỉ timer CUỐI còn active.
        expect(scheduled.where((t) => !t.cancelled), hasLength(1));

        await fireLatest();
        await Future<void>.delayed(Duration.zero);

        expect(coordinator.state, ConnectivityState.online);
      },
    );

    test(
      '1 lần probe fail khi đang online: xuống degraded, chưa xuống offline ngay',
      () async {
        var shouldSucceed = true;
        final signal = FakeConnectivitySignal(initialHasInterface: true);
        final coordinator = ConnectivityCoordinator(
          signal: signal,
          probe: () async => shouldSucceed,
          failuresToGoOffline: 2,
          createTimer: fakeCreateTimer,
        );
        await fireLatest();
        await Future<void>.delayed(Duration.zero);
        expect(coordinator.state, ConnectivityState.online);

        shouldSucceed = false;
        // Mô phỏng periodic probe timer nổ (timer thứ 2 được tạo lúc lên
        // online — probeTimer).
        await fireLatest();
        await Future<void>.delayed(Duration.zero);

        expect(coordinator.state, ConnectivityState.degraded);
      },
    );

    test(
      'đủ failuresToGoOffline lần fail liên tiếp: xuống offline thật sự',
      () async {
        var shouldSucceed = true;
        final signal = FakeConnectivitySignal(initialHasInterface: true);
        final coordinator = ConnectivityCoordinator(
          signal: signal,
          probe: () async => shouldSucceed,
          failuresToGoOffline: 2,
          createTimer: fakeCreateTimer,
        );
        await fireLatest();
        await Future<void>.delayed(Duration.zero);
        shouldSucceed = false;
        await fireLatest(); // fail #1 -> degraded
        await Future<void>.delayed(Duration.zero);
        expect(coordinator.state, ConnectivityState.degraded);

        await fireLatest(); // fail #2 -> offline
        await Future<void>.delayed(Duration.zero);

        expect(coordinator.state, ConnectivityState.offline);
      },
    );

    test(
      'phục hồi sau degraded: probe thành công lại thì về online, reset bộ đếm fail',
      () async {
        var shouldSucceed = true;
        final signal = FakeConnectivitySignal(initialHasInterface: true);
        final coordinator = ConnectivityCoordinator(
          signal: signal,
          probe: () async => shouldSucceed,
          failuresToGoOffline: 2,
          createTimer: fakeCreateTimer,
        );
        await fireLatest();
        await Future<void>.delayed(Duration.zero);
        shouldSucceed = false;
        await fireLatest();
        await Future<void>.delayed(Duration.zero);
        expect(coordinator.state, ConnectivityState.degraded);

        shouldSucceed = true;
        await fireLatest();
        await Future<void>.delayed(Duration.zero);

        expect(coordinator.state, ConnectivityState.online);
      },
    );
  });

  group('ConnectivityCoordinator: lifecycle dispose không leak stream/timer', () {
    test(
      'onClose(): cancel hết debounce/probe timer và stream subscription',
      () async {
        final signal = FakeConnectivitySignal(initialHasInterface: true);
        final coordinator = ConnectivityCoordinator(
          signal: signal,
          probe: () async => true,
          createTimer: fakeCreateTimer,
        );
        await fireLatest();
        await Future<void>.delayed(Duration.zero);
        expect(coordinator.state, ConnectivityState.online);

        coordinator.onClose();

        expect(scheduled.every((t) => t.cancelled), isTrue);

        // Sau dispose, signal đổi nữa cũng không còn ảnh hưởng state.
        signal.setHasInterface(false);
        await Future<void>.delayed(Duration.zero);
        expect(coordinator.state, ConnectivityState.online);
      },
    );

    test(
      'onClose(): đóng stateStream, không throw khi gọi lần nữa từ caller khác',
      () async {
        final signal = FakeConnectivitySignal();
        final coordinator = ConnectivityCoordinator(
          signal: signal,
          probe: () async => true,
          createTimer: fakeCreateTimer,
        );

        coordinator.onClose();

        expect(await coordinator.stateStream.isEmpty, isTrue);
      },
    );
  });

  group('ConnectivityCoordinator: queue', () {
    test(
      'idempotencyKey trùng: thay thế task cũ, không chạy trùng 2 lần',
      () async {
        final signal = FakeConnectivitySignal();
        final coordinator = ConnectivityCoordinator(
          signal: signal,
          probe: () async => true,
          createTimer: fakeCreateTimer,
        );
        var oldRan = false;
        var newRan = false;
        coordinator.enqueue(
          QueuedTask(
            idempotencyKey: 'sync_score',
            run: () async => oldRan = true,
          ),
        );
        coordinator.enqueue(
          QueuedTask(
            idempotencyKey: 'sync_score',
            run: () async => newRan = true,
          ),
        );

        expect(coordinator.queueLength, 1);

        signal.setHasInterface(true);
        await fireLatest();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(oldRan, isFalse);
        expect(newRan, isTrue);
      },
    );

    test('vượt maxQueueSize: loại bỏ đúng task priority thấp nhất', () {
      final signal = FakeConnectivitySignal();
      final coordinator = ConnectivityCoordinator(
        signal: signal,
        probe: () async => true,
        maxQueueSize: 2,
        createTimer: fakeCreateTimer,
      );
      coordinator.enqueue(
        QueuedTask(idempotencyKey: 'a', priority: 5, run: () async {}),
      );
      coordinator.enqueue(
        QueuedTask(idempotencyKey: 'b', priority: 1, run: () async {}),
      );
      coordinator.enqueue(
        QueuedTask(idempotencyKey: 'c', priority: 10, run: () async {}),
      );

      expect(coordinator.queueLength, 2);
    });

    test('task hết hạn (expiresAtMs quá khứ): bị bỏ qua, không chạy', () async {
      final signal = FakeConnectivitySignal();
      final coordinator = ConnectivityCoordinator(
        signal: signal,
        probe: () async => true,
        createTimer: fakeCreateTimer,
      );
      var ran = false;
      coordinator.enqueue(
        QueuedTask(
          idempotencyKey: 'expired',
          run: () async => ran = true,
          expiresAtMs: 1,
        ),
      );

      signal.setHasInterface(true);
      await fireLatest();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(ran, isFalse);
      expect(coordinator.queueLength, 0);
    });

    test('online tự động drain theo priority cao trước', () async {
      final signal = FakeConnectivitySignal();
      final coordinator = ConnectivityCoordinator(
        signal: signal,
        probe: () async => true,
        createTimer: fakeCreateTimer,
      );
      final order = <String>[];
      coordinator.enqueue(
        QueuedTask(
          idempotencyKey: 'low',
          priority: 0,
          run: () async => order.add('low'),
        ),
      );
      coordinator.enqueue(
        QueuedTask(
          idempotencyKey: 'high',
          priority: 10,
          run: () async => order.add('high'),
        ),
      );

      signal.setHasInterface(true);
      await fireLatest();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(order, ['high', 'low']);
      expect(coordinator.queueLength, 0);
    });

    test('1 task lỗi hết retry không chặn task độc lập khác chạy', () async {
      final signal = FakeConnectivitySignal();
      final coordinator = ConnectivityCoordinator(
        signal: signal,
        probe: () async => true,
        retryPolicy: const RetryPolicy(maxAttempts: 1),
        retryExecutor: RetryExecutor(delayFn: (_) async {}),
        createTimer: fakeCreateTimer,
      );
      var okRan = false;
      coordinator.enqueue(
        QueuedTask(
          idempotencyKey: 'fails',
          priority: 10,
          run: () async => throw StateError('boom'),
        ),
      );
      coordinator.enqueue(
        QueuedTask(
          idempotencyKey: 'ok',
          priority: 0,
          run: () async => okRan = true,
        ),
      );

      signal.setHasInterface(true);
      await fireLatest();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(okRan, isTrue);
      expect(coordinator.queueLength, 0);
    });
  });

  group(
    'ConnectivityCoordinator: connectedStream bridge cho NetworkStatusBanner',
    () {
      test('emit true khi online, false khi offline', () async {
        final signal = FakeConnectivitySignal();
        final coordinator = ConnectivityCoordinator(
          signal: signal,
          probe: () async => true,
          createTimer: fakeCreateTimer,
        );
        final events = <bool>[];
        final sub = coordinator.connectedStream.listen(events.add);

        signal.setHasInterface(true);
        await fireLatest();
        await Future<void>.delayed(Duration.zero);
        signal.setHasInterface(false);
        await fireLatest();
        await Future<void>.delayed(Duration.zero);

        // checking (false) -> online (true) -> offline (false).
        expect(events, [false, true, false]);
        await sub.cancel();
      });
    },
  );

  group('BUG-43: probe ném exception không crash, không kẹt state', () {
    test(
      'probe ném SocketException 1 lần: coi như fail, chuyển degraded (không kẹt checking)',
      () async {
        final signal = FakeConnectivitySignal();
        final coordinator = ConnectivityCoordinator(
          signal: signal,
          probe: () async => throw const SocketExceptionStub(),
          createTimer: fakeCreateTimer,
        );

        signal.setHasInterface(true);
        await fireLatest();
        await Future<void>.delayed(Duration.zero);

        expect(coordinator.state, ConnectivityState.degraded);
      },
    );

    test(
      'probe ném exception đủ failuresToGoOffline lần: chuyển đúng sang offline',
      () async {
        final signal = FakeConnectivitySignal();
        final coordinator = ConnectivityCoordinator(
          signal: signal,
          probe: () async => throw const SocketExceptionStub(),
          createTimer: fakeCreateTimer,
          failuresToGoOffline: 2,
        );

        signal.setHasInterface(true);
        await fireLatest();
        await Future<void>.delayed(Duration.zero);
        expect(coordinator.state, ConnectivityState.degraded);

        // Timer periodic vừa được tạo lại sau probe đầu -> fire nó để mô
        // phỏng lần probe định kỳ thứ 2.
        scheduled.last.callback();
        await Future<void>.delayed(Duration.zero);

        expect(coordinator.state, ConnectivityState.offline);
      },
    );

    test(
      'probe ném exception không thoát ra ngoài Zone thành unhandled error',
      () async {
        final signal = FakeConnectivitySignal();
        final zoneErrors = <Object>[];

        await runZonedGuarded(
          () async {
            final coordinator = ConnectivityCoordinator(
              signal: signal,
              probe: () async => throw const SocketExceptionStub(),
              createTimer: fakeCreateTimer,
            );
            signal.setHasInterface(true);
            await fireLatest();
            await Future<void>.delayed(Duration.zero);
            expect(coordinator.state, ConnectivityState.degraded);
          },
          (error, stack) => zoneErrors.add(error),
        );

        expect(zoneErrors, isEmpty);
      },
    );

    test(
      '_probeInFlight được reset đúng sau khi probe throw — probe kế tiếp vẫn chạy bình thường',
      () async {
        var shouldThrow = true;
        final signal = FakeConnectivitySignal();
        final coordinator = ConnectivityCoordinator(
          signal: signal,
          probe: () async {
            if (shouldThrow) throw const SocketExceptionStub();
            return true;
          },
          createTimer: fakeCreateTimer,
        );

        signal.setHasInterface(true);
        await fireLatest();
        await Future<void>.delayed(Duration.zero);
        expect(coordinator.state, ConnectivityState.degraded);

        shouldThrow = false;
        scheduled.last.callback();
        await Future<void>.delayed(Duration.zero);

        expect(coordinator.state, ConnectivityState.online);
      },
    );
  });
}

/// Stub đứng thế cho `SocketException`/`TimeoutException` thật — không cần
/// import `dart:io` chỉ để ném 1 exception giả lập trong test.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();

  @override
  String toString() => 'SocketExceptionStub';
}

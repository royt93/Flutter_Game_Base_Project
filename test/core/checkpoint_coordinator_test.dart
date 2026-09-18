import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/checkpoint_coordinator.dart';
import 'package:roy_casual_kit/core/lifecycle_coordinator.dart';
import 'package:roy_casual_kit/core/storage_service.dart';

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

  late StorageService storage;
  late List<_FakeTimer> scheduled;
  Timer fakeCreateTimer(Duration delay, void Function() callback) {
    final timer = _FakeTimer(callback);
    scheduled.add(timer);
    return timer;
  }

  setUp(() {
    storage = StorageService(null);
    scheduled = [];
  });

  test('critical checkpoint flush ngay, không cần chờ timer', () async {
    final coordinator = CheckpointCoordinator(
      storage: storage,
      createTimer: fakeCreateTimer,
    );
    coordinator.registerParticipant(
      'player',
      snapshot: () => {'x': 1},
      restore: (_) {},
    );

    final result = await coordinator.requestCheckpoint(critical: true);

    expect(result.isSuccess, isTrue);
    expect(scheduled, isEmpty);
    expect(storage.getString('checkpoint_coordinator_v1'), isNotNull);
  });

  test('checkpoint không critical: không flush ngay, chỉ flush khi timer nổ', () async {
    final coordinator = CheckpointCoordinator(
      storage: storage,
      createTimer: fakeCreateTimer,
    );
    coordinator.registerParticipant(
      'player',
      snapshot: () => {'x': 1},
      restore: (_) {},
    );

    coordinator.requestCheckpoint();

    expect(storage.getString('checkpoint_coordinator_v1'), isNull);
    expect(scheduled, hasLength(1));

    scheduled.single.callback();
    await Future<void>.delayed(Duration.zero);

    expect(storage.getString('checkpoint_coordinator_v1'), isNotNull);
  });

  test('nhiều requestCheckpoint() liên tiếp coalesce thành 1 timer, dùng state mới nhất', () async {
    final coordinator = CheckpointCoordinator(
      storage: storage,
      createTimer: fakeCreateTimer,
    );
    var value = 1;
    coordinator.registerParticipant(
      'player',
      snapshot: () => {'x': value},
      restore: (_) {},
    );

    coordinator.requestCheckpoint();
    value = 2;
    coordinator.requestCheckpoint();
    value = 3;
    coordinator.requestCheckpoint();

    expect(scheduled, hasLength(3));
    expect(scheduled[0].cancelled, isTrue);
    expect(scheduled[1].cancelled, isTrue);
    expect(scheduled[2].cancelled, isFalse);

    scheduled.last.callback();
    await Future<void>.delayed(Duration.zero);

    expect(storage.getString('checkpoint_coordinator_v1'), contains('"x":3'));
  });

  test('critical hủy timer debounce đang chờ, flush ngay với state hiện tại', () async {
    final coordinator = CheckpointCoordinator(
      storage: storage,
      createTimer: fakeCreateTimer,
    );
    coordinator.registerParticipant(
      'player',
      snapshot: () => {'x': 9},
      restore: (_) {},
    );

    coordinator.requestCheckpoint();
    expect(scheduled, hasLength(1));

    final result = await coordinator.requestCheckpoint(critical: true);

    expect(result.isSuccess, isTrue);
    expect(scheduled.single.cancelled, isTrue);
    expect(storage.getString('checkpoint_coordinator_v1'), contains('"x":9'));
  });

  test('nhiều participant: commit chung 1 lần ghi, không mixed snapshot', () async {
    final coordinator = CheckpointCoordinator(
      storage: storage,
      createTimer: fakeCreateTimer,
    );
    coordinator.registerParticipant(
      'player',
      snapshot: () => {'hp': 10},
      restore: (_) {},
    );
    coordinator.registerParticipant(
      'inventory',
      snapshot: () => {'items': 3},
      restore: (_) {},
    );

    await coordinator.requestCheckpoint(critical: true);

    final raw = storage.getString('checkpoint_coordinator_v1');
    expect(raw, contains('"hp":10'));
    expect(raw, contains('"items":3'));
  });

  test('1 participant snapshot() throw: toàn bộ flush abort, checkpoint cũ giữ nguyên', () async {
    final coordinator = CheckpointCoordinator(
      storage: storage,
      createTimer: fakeCreateTimer,
    );
    coordinator.registerParticipant(
      'player',
      snapshot: () => {'hp': 10},
      restore: (_) {},
    );
    await coordinator.requestCheckpoint(critical: true);
    final before = storage.getString('checkpoint_coordinator_v1');

    coordinator.registerParticipant(
      'broken',
      snapshot: () => throw StateError('boom'),
      restore: (_) {},
    );
    final result = await coordinator.requestCheckpoint(critical: true);

    expect(result.isSuccess, isFalse);
    expect(storage.getString('checkpoint_coordinator_v1'), before);
  });

  test('restoreLatest(): gọi đúng restore() từng participant với snapshot đã commit', () async {
    final coordinator = CheckpointCoordinator(
      storage: storage,
      createTimer: fakeCreateTimer,
    );
    coordinator.registerParticipant(
      'player',
      snapshot: () => {'hp': 7},
      restore: (_) {},
    );
    await coordinator.requestCheckpoint(critical: true);

    Object? restored;
    coordinator.registerParticipant(
      'player',
      snapshot: () => {'hp': 7},
      restore: (data) => restored = data,
    );
    final result = coordinator.restoreLatest();

    expect(result.isSuccess, isTrue);
    expect((restored as Map)['hp'], 7);
  });

  test('restoreLatest(): current bị hỏng -> fallback sang previous (last-known-good)', () async {
    final coordinator = CheckpointCoordinator(
      storage: storage,
      createTimer: fakeCreateTimer,
    );
    coordinator.registerParticipant(
      'player',
      snapshot: () => {'hp': 1},
      restore: (_) {},
    );
    await coordinator.requestCheckpoint(critical: true); // -> current = hp:1

    coordinator.registerParticipant(
      'player',
      snapshot: () => {'hp': 2},
      restore: (_) {},
    );
    await coordinator.requestCheckpoint(
      critical: true,
    ); // -> previous = hp:1, current = hp:2

    // Làm hỏng current giả lập ghi dở/tampered.
    await storage.setString('checkpoint_coordinator_v1', '{not json');

    Object? restored;
    coordinator.registerParticipant(
      'player',
      snapshot: () => {'hp': 2},
      restore: (data) => restored = data,
    );
    final result = coordinator.restoreLatest();

    expect(result.isSuccess, isTrue);
    expect((restored as Map)['hp'], 1); // đúng previous, không phải current hỏng
  });

  test('restoreLatest(): cả current lẫn previous đều hỏng -> failure, không gọi restore nào', () async {
    final coordinator = CheckpointCoordinator(
      storage: storage,
      createTimer: fakeCreateTimer,
    );
    var restoreCalled = false;
    coordinator.registerParticipant(
      'player',
      snapshot: () => {'hp': 1},
      restore: (_) => restoreCalled = true,
    );

    final result = coordinator.restoreLatest();

    expect(result.isSuccess, isFalse);
    expect(restoreCalled, isFalse);
  });

  test('wasDirtyOnLoad: false sau flush bình thường, true nếu key dirty còn sót từ trước', () async {
    final clean = CheckpointCoordinator(
      storage: storage,
      createTimer: fakeCreateTimer,
    );
    clean.registerParticipant('player', snapshot: () => {}, restore: (_) {});
    await clean.requestCheckpoint(critical: true);
    expect(clean.wasDirtyOnLoad, isFalse);

    await storage.setBool('checkpoint_coordinator_v1_dirty', true);
    final restarted = CheckpointCoordinator(
      storage: storage,
      createTimer: fakeCreateTimer,
    );
    expect(restarted.wasDirtyOnLoad, isTrue);
  });

  test('background lifecycle event kích hoạt flush ngay (bypass debounce)', () async {
    final lifecycle = RoyLifecycleCoordinator();
    Get.put<RoyLifecycleCoordinator>(lifecycle);
    final coordinator = CheckpointCoordinator(
      storage: storage,
      createTimer: fakeCreateTimer,
      lifecycle: lifecycle,
    );
    coordinator.registerParticipant(
      'player',
      snapshot: () => {'hp': 5},
      restore: (_) {},
    );
    coordinator.requestCheckpoint(); // debounce, chưa flush

    lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);

    expect(storage.getString('checkpoint_coordinator_v1'), contains('"hp":5'));
  });

  test('.maybe: null khi chưa đăng ký', () {
    expect(CheckpointCoordinator.maybe, isNull);
  });
}

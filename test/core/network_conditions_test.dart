import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/connectivity_coordinator.dart';
import 'package:roy_casual_kit/core/offline_outbox_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/retry_policy.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';
import 'package:roy_casual_kit/core/versioned_json_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/conditioned_providers.dart';
import '../support/owned_storage.dart';

/// ENH-125: network conditions (latency, drop, hang, flapping, offline ->
/// online) against the kit's network seams, with a scripted fake and no real
/// sleeping. The kit has no network code of its own, so this proves how each
/// seam behaves when the thing behind it misbehaves, not that a real network
/// does.
class _Profile {
  const _Profile(this.name);
  final String name;
  Map<String, Object?> toJson() => {'name': name};
  static _Profile fromJson(Map<String, Object?> j) =>
      _Profile(j['name']! as String);
}

VersionedJsonStore<_Profile> _store(StorageService storage) =>
    VersionedJsonStore<_Profile>(
      storage: storage,
      key: 'profile',
      schemaVersion: 1,
      toJson: (p) => p.toJson(),
      fromJson: _Profile.fromJson,
      migrate: (fromVersion, json) => json,
    );

OfflineOutboxService _outbox(
  StorageService storage,
  ConditionedOutboxUploader uploader, {
  ConnectivityCoordinator? connectivity,
  RetryPolicy policy = const RetryPolicy(
    maxAttempts: 3,
    baseDelay: Duration.zero,
  ),
}) => OfflineOutboxService(
  storage: storage,
  uploader: uploader.call,
  connectivity: connectivity,
  retryPolicy: policy,
  retryExecutor: RetryExecutor(delayFn: (_) async {}, randomFn: () => 0.5),
)..onInit();

void main() {
  group('VersionedJsonStore.syncWithResult under network conditions', () {
    late StorageService storage;
    late VersionedJsonStore<_Profile> store;

    setUp(() async {
      storage = await ownedStorage();
      store = _store(storage);
    });

    test('download drops: SdkFailure(network), local save untouched, nothing uploaded', () async {
      await store.save(const _Profile('local'));
      final before = storage.getString('profile');
      final cloud = ConditionedCloudSaveProvider(
        download: NetworkScript([NetStep.fail]),
        remote: {'schemaVersion': 1, 'name': 'cloud', 'syncedAtMs': 1 << 50},
      );

      final result = await store.syncWithResult(cloud);

      expect(result, isA<SdkFailure<void>>());
      expect((result as SdkFailure<void>).kind, SdkErrorKind.network);
      expect(storage.getString('profile'), before);
      expect(cloud.uploaded, isEmpty);
    });

    test('upload drops: SdkFailure(network), local save intact, next sync retries and succeeds', () async {
      await store.save(const _Profile('local'));
      final before = storage.getString('profile');
      final cloud = ConditionedCloudSaveProvider(
        upload: NetworkScript([NetStep.fail]),
      );

      final first = await store.syncWithResult(cloud);
      expect((first as SdkFailure<void>).kind, SdkErrorKind.network);
      expect(storage.getString('profile'), before, reason: 'a failed upload must not touch local');
      expect(cloud.uploaded, isEmpty);

      final second = await store.syncWithResult(cloud);
      expect(second, isA<SdkSuccess<void>>());
      expect(cloud.uploaded, hasLength(1));
      expect(cloud.uploaded.single['name'], 'local');
    });

    test('flapping: fail, fail, then ok converges with exactly one upload', () async {
      await store.save(const _Profile('local'));
      final cloud = ConditionedCloudSaveProvider(
        upload: NetworkScript([NetStep.fail, NetStep.fail]),
      );

      final kinds = <Object>[];
      for (var i = 0; i < 3; i++) {
        final r = await store.syncWithResult(cloud);
        kinds.add(r is SdkFailure<void> ? r.kind : 'ok');
      }

      expect(kinds, [SdkErrorKind.network, SdkErrorKind.network, 'ok']);
      expect(cloud.uploadScript.calls, 3);
      expect(cloud.uploaded, hasLength(1));
    });

    test('a cloud save that downloads after a drop still wins on a later sync', () async {
      await store.save(const _Profile('local'));
      final cloud = ConditionedCloudSaveProvider(
        download: NetworkScript([NetStep.fail]),
        remote: {
          'schemaVersion': 1,
          'name': 'cloud',
          'syncedAtMs': DateTime.now().millisecondsSinceEpoch + 60000,
        },
      );

      expect((await store.syncWithResult(cloud)) is SdkFailure<void>, isTrue);
      expect(store.load()!.name, 'local');

      expect((await store.syncWithResult(cloud)) is SdkSuccess<void>, isTrue);
      expect(store.load()!.name, 'cloud');
    });

    testWidgets('a hung download never resolves on its own and does not corrupt local state', (tester) async {
      final s = StorageService(null);
      addTearDown(s.onClose);
      final st = _store(s);
      await st.save(const _Profile('local'));
      final before = s.getString('profile');
      final cloud = ConditionedCloudSaveProvider(
        download: NetworkScript([NetStep.hang]),
      );

      var done = false;
      unawaited(st.syncWithResult(cloud).whenComplete(() => done = true));
      await tester.pump(const Duration(hours: 24));

      expect(done, isFalse, reason: 'sync has no timeout of its own: the caller must supply one');
      expect(s.getString('profile'), before);
    });

    test('an OLDER cloud copy never overwrites a newer local save, even right after a failed download', () async {
      await store.save(const _Profile('local-newer'));
      final cloud = ConditionedCloudSaveProvider(
        download: NetworkScript([NetStep.fail]),
        remote: {'schemaVersion': 1, 'name': 'cloud-older', 'syncedAtMs': 1000},
      );

      await store.syncWithResult(cloud);
      final second = await store.syncWithResult(cloud);

      expect(second, isA<SdkSuccess<void>>());
      expect(store.load()!.name, 'local-newer');
      expect(cloud.uploaded.single['name'], 'local-newer', reason: 'the newer side is pushed to the cloud');
    });

    test('slow upload: local is already safe while the upload is still in flight', () async {
      await store.save(const _Profile('local'));
      final cloud = ConditionedCloudSaveProvider(
        upload: NetworkScript([NetStep.slow]),
      );

      final pending = store.syncWithResult(cloud);
      await pumpEventQueue();
      expect(cloud.uploadScript.parked, hasLength(1));
      expect(store.load()!.name, 'local');
      expect(cloud.uploaded, isEmpty);

      cloud.uploadScript.release();
      expect(await pending, isA<SdkSuccess<void>>());
      expect(cloud.uploaded, hasLength(1));
    });

    test('a download that returns a corrupt payload after a retry leaves local alone', () async {
      await store.save(const _Profile('local'));
      final cloud = ConditionedCloudSaveProvider(
        download: NetworkScript([NetStep.fail]),
        remote: {'schemaVersion': 'x', 'name': 7, 'syncedAtMs': 'soon'},
      );

      await store.syncWithResult(cloud);
      final second = await store.syncWithResult(cloud);

      expect(second, isA<SdkSuccess<void>>());
      expect(store.load()!.name, 'local');
    });
  });

  group('OfflineOutboxService under network conditions', () {
    late StorageService storage;

    setUp(() async {
      storage = await ownedStorage();
    });

    test('fail twice then ok inside one drain: delivered once, removed, backoff taken twice', () async {
      final delays = <Duration>[];
      final uploader = ConditionedOutboxUploader(
        NetworkScript([NetStep.fail, NetStep.fail]),
      );
      final service = OfflineOutboxService(
        storage: storage,
        uploader: uploader.call,
        retryPolicy: const RetryPolicy(maxAttempts: 3, jitterFraction: 0),
        retryExecutor: RetryExecutor(
          delayFn: (d) async => delays.add(d),
          randomFn: () => 0.5,
        ),
      )..onInit();

      service.enqueue(idempotencyKey: 'k1', payload: const {'v': 1});
      await service.drain();

      expect(uploader.script.calls, 3);
      expect(uploader.acked, ['k1']);
      expect(service.items, isEmpty);
      expect(delays, [
        const Duration(milliseconds: 200),
        const Duration(milliseconds: 400),
      ], reason: 'exponential backoff: base then doubled, none before the first try');
    });

    test('backoff inside a drain never exceeds maxDelay however many attempts fail', () async {
      final delays = <Duration>[];
      final uploader = ConditionedOutboxUploader(
        NetworkScript(List.filled(7, NetStep.fail)),
      );
      final service = OfflineOutboxService(
        storage: storage,
        uploader: uploader.call,
        retryPolicy: const RetryPolicy(
          maxAttempts: 8,
          baseDelay: Duration(seconds: 1),
          maxDelay: Duration(seconds: 4),
          jitterFraction: 0,
        ),
        retryExecutor: RetryExecutor(
          delayFn: (d) async => delays.add(d),
          randomFn: () => 0.5,
        ),
      )..onInit();

      service.enqueue(idempotencyKey: 'k1', payload: const {});
      await service.drain();

      expect(uploader.acked, ['k1']);
      expect(delays.reduce((a, b) => a > b ? a : b), const Duration(seconds: 4));
      expect(delays.last, const Duration(seconds: 4));
    });

    test('with jitter the delay is still bounded by maxDelay and stays near the cap, not near the raw exponential', () async {
      final delays = <Duration>[];
      final uploader = ConditionedOutboxUploader(
        NetworkScript(List.filled(7, NetStep.fail)),
      );
      final service = OfflineOutboxService(
        storage: storage,
        uploader: uploader.call,
        retryPolicy: const RetryPolicy(
          maxAttempts: 8,
          baseDelay: Duration(seconds: 1),
          maxDelay: Duration(seconds: 4),
          jitterFraction: 0.5,
        ),
        // randomValue 0 is the LOWEST jitter: the delay falls to cap * (1 - jitter).
        retryExecutor: RetryExecutor(
          delayFn: (d) async => delays.add(d),
          randomFn: () => 0,
        ),
      )..onInit();

      service.enqueue(idempotencyKey: 'k1', payload: const {});
      await service.drain();

      // Attempts 5..8 would be 16s, 32s, 64s, 128s uncapped; capped at 4s they
      // all fall to 4s * 0.5 = 2s. Uncapped they would be 8s, 16s, 32s, 64s.
      expect(delays.sublist(3), everyElement(const Duration(seconds: 2)));
    });

    test('retries exhausted: item stays queued and a later drain delivers it', () async {
      final uploader = ConditionedOutboxUploader(
        NetworkScript([NetStep.fail, NetStep.fail, NetStep.fail]),
      );
      final service = _outbox(storage, uploader);
      service.enqueue(idempotencyKey: 'k1', payload: const {'v': 1});

      await service.drain();
      expect(service.items.map((i) => i.idempotencyKey), ['k1']);
      expect(uploader.acked, isEmpty);

      await service.drain();
      expect(uploader.acked, ['k1']);
      expect(service.items, isEmpty);
    });

    test('a failure on the first item does not stop independent later items', () async {
      final uploader = ConditionedOutboxUploader(
        NetworkScript([NetStep.fail, NetStep.fail, NetStep.fail]),
      );
      final service = _outbox(storage, uploader);
      service.enqueue(idempotencyKey: 'a', payload: const {}, priority: 5);
      service.enqueue(idempotencyKey: 'b', payload: const {}, priority: 1);

      await service.drain();

      expect(uploader.acked, ['b'], reason: 'a exhausted its retries; b must still go');
      expect(service.items.map((i) => i.idempotencyKey), ['a']);
    });

    testWidgets('a hung upload never acks and never drops the item', (tester) async {
      final s = StorageService(null);
      addTearDown(s.onClose);
      final uploader = ConditionedOutboxUploader(NetworkScript([NetStep.hang]));
      final service = _outbox(s, uploader);
      service.enqueue(idempotencyKey: 'k1', payload: const {});

      unawaited(service.drain());
      await tester.pump(const Duration(hours: 1));

      expect(uploader.acked, isEmpty);
      expect(service.items.map((i) => i.idempotencyKey), ['k1']);
    });

    testWidgets('per-attempt timeout is terminal: no second attempt while the first may still land', (tester) async {
      final s = StorageService(null);
      addTearDown(s.onClose);
      final uploader = ConditionedOutboxUploader(NetworkScript([NetStep.hang]));
      final service = _outbox(
        s,
        uploader,
        policy: const RetryPolicy(
          maxAttempts: 3,
          baseDelay: Duration.zero,
          timeout: Duration(seconds: 5),
        ),
      );
      service.enqueue(idempotencyKey: 'k1', payload: const {});

      unawaited(service.drain());
      await tester.pump(const Duration(seconds: 30));

      expect(uploader.script.calls, 1, reason: 'BUG-96: a timed-out attempt is never retried');
      expect(service.items.map((i) => i.idempotencyKey), ['k1']);
    });

    test('offline -> online drains the queue once, highest priority first, no duplicates', () async {
      final signal = FakeConnectivitySignal();
      final connectivity = ConnectivityCoordinator(
        signal: signal,
        probe: () async => true,
        createTimer: (_, cb) => Timer(Duration.zero, cb),
      );
      final uploader = ConditionedOutboxUploader();
      final service = _outbox(storage, uploader, connectivity: connectivity);
      addTearDown(() {
        service.onClose();
        connectivity.onClose();
        signal.dispose();
      });

      service.enqueue(idempotencyKey: 'low', payload: const {}, priority: 1);
      service.enqueue(idempotencyKey: 'high', payload: const {}, priority: 9);
      service.enqueue(idempotencyKey: 'mid', payload: const {}, priority: 5);
      await pumpEventQueue();
      expect(uploader.script.calls, 0, reason: 'offline: nothing may be attempted');

      signal.setHasInterface(true);
      await pumpEventQueue();

      expect(uploader.acked, ['high', 'mid', 'low']);
      expect(service.items, isEmpty);
    });

    test('flapping connectivity: every flap back online re-drains, nothing is delivered twice', () async {
      final signal = FakeConnectivitySignal();
      final connectivity = ConnectivityCoordinator(
        signal: signal,
        probe: () async => true,
        createTimer: (_, cb) => Timer(Duration.zero, cb),
      );
      final uploader = ConditionedOutboxUploader(
        NetworkScript([NetStep.fail, NetStep.fail, NetStep.fail]),
      );
      final service = _outbox(storage, uploader, connectivity: connectivity);
      addTearDown(() {
        service.onClose();
        connectivity.onClose();
        signal.dispose();
      });

      service.enqueue(idempotencyKey: 'k1', payload: const {});
      for (var i = 0; i < 3; i++) {
        signal.setHasInterface(true);
        await pumpEventQueue();
        signal.setHasInterface(false);
        await pumpEventQueue();
      }

      expect(uploader.acked, ['k1'], reason: 'the first three attempts failed; a later flap delivered it exactly once');
      expect(service.items, isEmpty);
    });

    test('the queue survives a restart that happens while offline and drains on reconnect', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final firstStorage = StorageService(prefs);
      addTearDown(firstStorage.onClose);
      final first = _outbox(firstStorage, ConditionedOutboxUploader());
      expect(
        first.enqueue(idempotencyKey: 'k1', payload: const {'v': 1}),
        isA<SdkSuccess<void>>(),
      );
      await pumpEventQueue();
      first.onClose();

      final secondStorage = StorageService(prefs);
      addTearDown(secondStorage.onClose);
      final uploader = ConditionedOutboxUploader();
      final second = _outbox(secondStorage, uploader);
      expect(second.items.map((i) => i.idempotencyKey), ['k1']);

      await second.drain();
      expect(uploader.acked, ['k1']);
      expect(second.items, isEmpty);
    });
  });

  group('RetryExecutor under network conditions', () {
    test('latency is modelled as an awaited gate, not a sleep: nothing completes until released', () async {
      final script = NetworkScript([NetStep.slow]);
      final run = RetryExecutor(delayFn: (_) async {}).run(() => script.apply('x'));
      var done = false;
      unawaited(run.then((_) => done = true));
      await pumpEventQueue();
      expect(done, isFalse);

      script.release();
      await pumpEventQueue();
      expect(done, isTrue);
    });

    test('backoff schedule for N failures follows 0, base, 2*base, 4*base capped at maxDelay', () async {
      final delays = <Duration>[];
      final script = NetworkScript(List.filled(5, NetStep.fail));
      final result = await RetryExecutor(
        delayFn: (d) async => delays.add(d),
        randomFn: () => 0.5,
      ).run(
        () => script.apply('x'),
        policy: const RetryPolicy(
          maxAttempts: 6,
          baseDelay: Duration(milliseconds: 100),
          maxDelay: Duration(milliseconds: 500),
          jitterFraction: 0,
        ),
      );

      expect(result, isA<SdkSuccess<void>>());
      expect(delays, [
        const Duration(milliseconds: 100),
        const Duration(milliseconds: 200),
        const Duration(milliseconds: 400),
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 500),
      ]);
    });
  });
}

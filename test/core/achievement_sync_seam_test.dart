import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/achievement_service.dart';
import 'package:roy_casual_kit/core/achievement_sync_seam.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSeam implements AchievementSyncSeam {
  Map<String, int>? remote;
  Object? pullError;
  Object? pushError;
  final pushed = <Map<String, int>>[];

  @override
  Future<Map<String, int>?> pullProgress() async {
    if (pullError != null) throw pullError!;
    return remote;
  }

  @override
  Future<void> pushProgress(Map<String, int> progress) async {
    if (pushError != null) throw pushError!;
    pushed.add(Map.of(progress));
    final merged = Map<String, int>.of(remote ?? {});
    for (final entry in progress.entries) {
      if (entry.value > (merged[entry.key] ?? 0)) {
        merged[entry.key] = entry.value;
      }
    }
    remote = merged;
  }
}

class _ConcurrentSeam extends _FakeSeam {
  final bothPulled = Completer<void>();
  var pulls = 0;

  @override
  Future<Map<String, int>?> pullProgress() async {
    final snapshot = Map<String, int>.of(remote ?? {});
    if (++pulls == 2) bothPulled.complete();
    await bothPulled.future;
    return snapshot;
  }
}

class _DelayedStorage extends StorageService {
  _DelayedStorage() : super(null);
  final firstWrite = Completer<void>();
  var writes = 0;

  @override
  Future<void> setString(String key, String value) async {
    if (++writes == 1) await firstWrite.future;
    await super.setString(key, value);
  }
}

class _FailingStorage extends StorageService {
  _FailingStorage(super.prefs);
  bool fail = false;

  @override
  Future<void> setString(String key, String value) {
    if (fail) throw StateError('disk full');
    return super.setString(key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  late _FailingStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = _FailingStorage(await SharedPreferences.getInstance());
    Get.put<StorageService>(storage, permanent: true);
  });

  group('AchievementService.mergeProgressDurably', () {
    test(
      'raises to max(local, remote), never lowers, reports raised count',
      () async {
        final service = AchievementService()
          ..register('a', 10)
          ..register('b', 10);
        service.incrementProgress('a', 5);
        service.incrementProgress('b', 2);

        final result = await service.mergeProgressDurably({
          'a': 3,
          'b': 7,
          'c': 4,
        });

        expect((result as SdkSuccess<int>).value, 2);
        expect(service.progressOf('a'), 5);
        expect(service.progressOf('b'), 7);
        expect(service.progressSnapshot['c'], 4);
      },
    );

    test('save metadata never becomes achievement progress', () async {
      final service = AchievementService();
      await service.mergeProgressDurably({
        'win': 3,
        'schemaVersion': 8,
        'syncedAtMs': 99,
      });
      expect(service.progressSnapshot, {'win': 3});
      expect(AchievementService().progressSnapshot, {'win': 3});
      for (final id in ['schemaVersion', 'syncedAtMs']) {
        expect(() => service.register(id, 1), throwsArgumentError);
        expect(() => service.incrementProgress(id, 1), throwsArgumentError);
        expect(() => service.progressOf(id), throwsArgumentError);
        expect(() => service.thresholdOf(id), throwsArgumentError);
      }
    });

    test('skips empty ids and negative values', () async {
      final service = AchievementService();
      final result = await service.mergeProgressDurably({
        '': 9,
        ' ': 9,
        'x': -1,
      });
      expect((result as SdkSuccess<int>).value, 0);
      expect(service.progressSnapshot, isEmpty);
    });

    test(
      'fires onUnlock once for an achievement the merge completes',
      () async {
        final service = AchievementService()..register('win', 5);
        final unlocked = <String>[];
        final sub = service.onUnlock.listen(unlocked.add);
        addTearDown(sub.cancel);

        await service.mergeProgressDurably({'win': 9});
        await service.mergeProgressDurably({'win': 12});
        await Future<void>.delayed(Duration.zero);

        expect(unlocked, ['win']);
      },
    );

    test('persists merged progress across a restart', () async {
      final service = AchievementService()..register('win', 5);
      await service.mergeProgressDurably({'win': 4});

      final reloaded = AchievementService()..register('win', 5);
      expect(reloaded.progressOf('win'), 4);
    });

    test(
      'storage failure returns SdkFailure(storage) and keeps in-memory progress',
      () async {
        final service = AchievementService()..register('win', 5);
        storage.fail = true;

        final result = await service.mergeProgressDurably({'win': 3});

        expect(result, isA<SdkFailure<int>>());
        expect((result as SdkFailure<int>).kind, SdkErrorKind.storage);
        expect(service.progressOf('win'), 3);
      },
    );

    test('retry persists the same merge after a storage failure', () async {
      final service = AchievementService();
      storage.fail = true;
      expect(
        await service.mergeProgressDurably({'win': 3}),
        isA<SdkFailure<int>>(),
      );
      storage.fail = false;
      expect(
        await service.mergeProgressDurably({'win': 3}),
        isA<SdkSuccess<int>>(),
      );
      expect(AchievementService().progressOf('win'), 3);
    });

    test(
      'retry still reports storage failure when equal progress is not saved',
      () async {
        final service = AchievementService();
        storage.fail = true;
        await service.mergeProgressDurably({'win': 3});
        expect(
          await service.mergeProgressDurably({'win': 3}),
          isA<SdkFailure<int>>(),
        );
      },
    );

    test(
      'merge preserves nonempty achievement ids exactly like registration',
      () async {
        final service = AchievementService()..register(' win ', 3);
        await service.mergeProgressDurably({' win ': 3});
        expect(service.isCompleted(' win '), isTrue);
        expect(service.progressSnapshot, {' win ': 3});
        final reloaded = AchievementService()..register(' win ', 3);
        expect(reloaded.isCompleted(' win '), isTrue);
        expect(reloaded.progressSnapshot, {' win ': 3});
      },
    );

    test(
      'unchanged merge awaits queued local increments before returning',
      () async {
        final delayed = _DelayedStorage();
        final service = AchievementService(storage: delayed);
        service.incrementProgress('win', 1);
        service.incrementProgress('win', 1);
        var finished = false;
        final merge = service.mergeProgressDurably({'win': 2}).then((result) {
          finished = true;
          return result;
        });
        await Future<void>.delayed(Duration.zero);
        expect(finished, isFalse);
        delayed.firstWrite.complete();
        expect(await merge, isA<SdkSuccess<int>>());
        expect(AchievementService(storage: delayed).progressOf('win'), 2);
      },
    );

    test('progressSnapshot is unmodifiable and detached from later writes', () {
      final service = AchievementService()..register('win', 5);
      service.incrementProgress('win', 1);
      final snapshot = service.progressSnapshot;
      expect(() => snapshot['win'] = 99, throwsUnsupportedError);
      service.incrementProgress('win', 1);
      expect(snapshot['win'], 1);
    });
  });

  group('AchievementSyncCoordinator', () {
    test('no seam registered: nothing to sync, local untouched', () async {
      final service = AchievementService()..register('a', 3);
      service.incrementProgress('a', 1);
      final result = await AchievementSyncCoordinator(service: service).sync();
      expect((result as SdkSuccess<int>).value, 0);
      expect(service.progressOf('a'), 1);
    });

    test('pulls, merges by max, then pushes the merged map', () async {
      final service = AchievementService()
        ..register('a', 10)
        ..register('b', 10);
      service.incrementProgress('a', 6);
      final seam = _FakeSeam()..remote = {'a': 2, 'b': 8};

      final result = await AchievementSyncCoordinator(
        service: service,
        seam: seam,
      ).sync();

      expect((result as SdkSuccess<int>).value, 1);
      expect(seam.pushed.single, {'a': 6, 'b': 8});
    });

    test('remote has nothing yet: uploads local progress', () async {
      final service = AchievementService()..register('a', 10);
      service.incrementProgress('a', 4);
      final seam = _FakeSeam();

      final result = await AchievementSyncCoordinator(
        service: service,
        seam: seam,
      ).sync();

      expect((result as SdkSuccess<int>).value, 0);
      expect(seam.pushed.single, {'a': 4});
    });

    test(
      'empty cloud still requires local persistence before upload',
      () async {
        final service = AchievementService();
        final seam = _FakeSeam();
        storage.fail = true;
        final result = await AchievementSyncCoordinator(
          service: service,
          seam: seam,
        ).sync();
        expect(result, isA<SdkFailure<int>>());
        expect((result as SdkFailure<int>).kind, SdkErrorKind.storage);
        expect(seam.pushed, isEmpty);
      },
    );

    test('resolves the seam from Get when none is passed', () async {
      final service = AchievementService()..register('a', 10);
      final seam = _FakeSeam()..remote = {'a': 5};
      Get.put<AchievementSyncSeam>(seam);

      await AchievementSyncCoordinator(service: service).sync();

      expect(service.progressOf('a'), 5);
      expect(seam.pushed.single, {'a': 5});
    });

    test(
      'pull failure: retryable network failure, local progress and push untouched',
      () async {
        final service = AchievementService()..register('a', 10);
        service.incrementProgress('a', 3);
        final seam = _FakeSeam()..pullError = StateError('offline');

        final result = await AchievementSyncCoordinator(
          service: service,
          seam: seam,
        ).sync();

        final failure = result as SdkFailure<int>;
        expect(failure.kind, SdkErrorKind.network);
        expect(failure.retryable, isTrue);
        expect(failure.cause, same(seam.pullError));
        expect(failure.stackTrace, isNotNull);
        expect(service.progressOf('a'), 3);
        expect(seam.pushed, isEmpty);
      },
    );

    test(
      'push failure: merged progress kept, retryable network failure reported',
      () async {
        final service = AchievementService()..register('a', 10);
        final seam = _FakeSeam()
          ..remote = {'a': 7}
          ..pushError = StateError('timeout');

        final result = await AchievementSyncCoordinator(
          service: service,
          seam: seam,
        ).sync();

        final failure = result as SdkFailure<int>;
        expect(failure.kind, SdkErrorKind.network);
        expect(failure.retryable, isTrue);
        expect(service.progressOf('a'), 7);
      },
    );

    test(
      'local persist failure after pull: storage failure returned, nothing pushed',
      () async {
        final service = AchievementService()..register('a', 10);
        final seam = _FakeSeam()..remote = {'a': 7};
        storage.fail = true;

        final result = await AchievementSyncCoordinator(
          service: service,
          seam: seam,
        ).sync();

        expect((result as SdkFailure<int>).kind, SdkErrorKind.storage);
        expect(seam.pushed, isEmpty);
      },
    );

    test(
      'two devices converge to the same map after syncing both ways',
      () async {
        final cloud = _FakeSeam();
        final deviceA = AchievementService()
          ..register('x', 10)
          ..register('y', 10);
        deviceA.incrementProgress('x', 6);
        await AchievementSyncCoordinator(service: deviceA, seam: cloud).sync();

        final deviceB = AchievementService(storageKey: 'other_device')
          ..register('x', 10)
          ..register('y', 10);
        deviceB.incrementProgress('x', 2);
        deviceB.incrementProgress('y', 9);
        await AchievementSyncCoordinator(service: deviceB, seam: cloud).sync();
        await AchievementSyncCoordinator(service: deviceA, seam: cloud).sync();

        expect(deviceA.progressSnapshot, {'x': 6, 'y': 9});
        expect(deviceB.progressSnapshot, {'x': 6, 'y': 9});
      },
    );

    test(
      'concurrent device uploads preserve both progress maps remotely',
      () async {
        final cloud = _ConcurrentSeam();
        final first = AchievementService(storageKey: 'device_first');
        final second = AchievementService(storageKey: 'device_second');
        first.incrementProgress('x', 6);
        second.incrementProgress('y', 9);
        final results = await Future.wait([
          AchievementSyncCoordinator(service: first, seam: cloud).sync(),
          AchievementSyncCoordinator(service: second, seam: cloud).sync(),
        ]);
        expect(results.every((result) => result.isSuccess), isTrue);
        expect(cloud.remote, {'x': 6, 'y': 9});
      },
    );

    test(
      'maybe returns null when unregistered and the instance when registered',
      () {
        expect(AchievementSyncSeam.maybe, isNull);
        final seam = _FakeSeam();
        Get.put<AchievementSyncSeam>(seam);
        expect(AchievementSyncSeam.maybe, same(seam));
      },
    );
  });
}

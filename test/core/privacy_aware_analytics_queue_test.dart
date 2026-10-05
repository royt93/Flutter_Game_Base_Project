import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/consent_state_service.dart';
import 'package:roy_casual_kit/core/privacy_aware_analytics_queue.dart';
import 'package:roy_casual_kit/core/sdk_event_schema_registry.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/retry_policy.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingAnalyticsStorage extends StorageService {
  _FailingAnalyticsStorage(super.prefs);

  @override
  Future<void> setString(String key, String value) {
    if (key == StorageKeys.analyticsQueueV1) {
      throw StateError('disk full');
    }
    return super.setString(key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late ConsentStateService consent;
  late SdkEventSchemaRegistry registry;
  var id = 0;
  var now = 1000;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    Get.put(storage, permanent: true);
    consent = ConsentStateService(policyVersion: 1);
    Get.put(consent, permanent: true);
    registry = SdkEventSchemaRegistry()
      ..register(
        EventSchema(
          name: 'level_start',
          version: 1,
          params: {
            'level': const EventParamSchema(
              type: EventParamType.int,
              required: true,
            ),
            'email': const EventParamSchema(
              type: EventParamType.string,
              pii: true,
            ),
          },
          unknownFieldPolicy: UnknownFieldPolicy.reject,
        ),
      );
    id = 0;
    now = 1000;
  });

  tearDown(Get.reset);

  /// Revokes consent by rewriting its stored state only (no `revision`
  /// bump), so the queue's background worker cannot react to it.
  void revokeSilently(ConsentCategory category) {
    final state =
        jsonDecode(storage.getString(StorageKeys.consentStateV1)!)
            as Map<String, dynamic>;
    (state[category.name] as Map<String, dynamic>)['status'] = 'denied';
    unawaited(storage.setString(StorageKeys.consentStateV1, jsonEncode(state)));
  }

  PrivacyAwareAnalyticsQueue queue({
    required AnalyticsBatchUploader uploader,
    int capacity = 100,
    int batchSize = 20,
    double samplingRate = 1,
    RetryPolicy retryPolicy = const RetryPolicy(
      maxAttempts: 2,
      baseDelay: Duration.zero,
      jitterFraction: 0,
    ),
  }) => PrivacyAwareAnalyticsQueue(
    storage: storage,
    consent: consent,
    registry: registry,
    uploader: uploader,
    capacity: capacity,
    batchSize: batchSize,
    defaultSamplingRate: samplingRate,
    retryPolicy: retryPolicy,
    retryExecutor: RetryExecutor(delayFn: (_) async {}, randomFn: () => 0.5),
    idGenerator: () => 'id-${id++}',
    nowMs: () => now++,
    sessionSeed: () => 'session',
  );

  test(
    'unknown/denied consent drops before schema and never persists',
    () async {
      final q = queue(uploader: (_) async {});

      expect(await q.enqueueDurably('level_start', {'level': 1}), isFalse);
      consent.deny(ConsentCategory.analytics);
      expect(await q.enqueueDurably('level_start', {'level': 2}), isFalse);

      expect(q.pendingCount, 0);
      expect(storage.getString(StorageKeys.analyticsQueueV1), isNull);
      expect(
        q.auditSnapshot.droppedByReason[AnalyticsQueueDropReason
            .consentNotGranted],
        2,
      );
      q.dispose();
    },
  );

  test('schema validates and redacts PII before durable enqueue', () async {
    consent.grant(ConsentCategory.analytics);
    final q = queue(uploader: (_) async {});

    expect(
      await q.enqueueDurably('level_start', {'level': 4, 'email': 'x@y.com'}),
      isTrue,
    );

    expect(q.pendingEvents.single.params, {'level': 4});
    expect(
      storage.getString(StorageKeys.analyticsQueueV1),
      isNot(contains('x@y.com')),
    );

    expect(
      await q.enqueueDurably('unknown', {'email': 'leak@example.com'}),
      isFalse,
    );
    expect(
      storage.getString(StorageKeys.analyticsQueueV1),
      isNot(contains('leak@example.com')),
    );
    expect(
      q.auditSnapshot.droppedByReason[AnalyticsQueueDropReason.schemaRejected],
      1,
    );
    q.dispose();
  });

  test('bounded FIFO rejects newest and records queueFull', () async {
    consent.grant(ConsentCategory.analytics);
    final q = queue(uploader: (_) async {}, capacity: 2);

    expect(await q.enqueueDurably('level_start', {'level': 1}), isTrue);
    expect(await q.enqueueDurably('level_start', {'level': 2}), isTrue);
    expect(await q.enqueueDurably('level_start', {'level': 3}), isFalse);

    expect(q.pendingEvents.map((e) => e.params['level']), [1, 2]);
    expect(
      q.auditSnapshot.droppedByReason[AnalyticsQueueDropReason.queueFull],
      1,
    );
    q.dispose();
  });

  test('sampling is deterministic and runs after schema validation', () async {
    consent.grant(ConsentCategory.analytics);
    final q = queue(uploader: (_) async {}, samplingRate: 0);

    expect(await q.enqueueDurably('level_start', {'level': 1}), isFalse);
    expect(await q.enqueueDurably('level_start', {'level': 2}), isFalse);
    expect(q.pendingCount, 0);
    expect(
      q.auditSnapshot.droppedByReason[AnalyticsQueueDropReason.sampledOut],
      2,
    );
    q.dispose();
  });

  test(
    'hydrates FIFO and tolerates corrupt/malformed persisted JSON',
    () async {
      consent.grant(ConsentCategory.analytics);
      final q1 = queue(uploader: (_) async {});
      await q1.enqueueDurably('level_start', {'level': 1});
      await q1.enqueueDurably('level_start', {'level': 2});
      q1.dispose();

      final q2 = queue(uploader: (_) async {});
      expect(q2.pendingEvents.map((e) => e.params['level']), [1, 2]);
      q2.dispose();

      await storage.setString(StorageKeys.analyticsQueueV1, '{broken');
      final q3 = queue(uploader: (_) async {});
      expect(q3.pendingCount, 0);
      q3.dispose();

      await storage.setString(
        StorageKeys.analyticsQueueV1,
        jsonEncode([
          {'id': 7, 'name': true},
        ]),
      );
      final q4 = queue(uploader: (_) async {});
      expect(q4.pendingCount, 0);
      q4.dispose();
    },
  );

  test(
    'failed retry retains batch; success ACK clears and persists removal',
    () async {
      consent.grant(ConsentCategory.analytics);
      var fail = true;
      final uploaded = <List<QueuedAnalyticsEvent>>[];
      final q = queue(
        uploader: (batch) async {
          uploaded.add(batch);
          if (fail) throw StateError('offline');
        },
      );
      await q.enqueueDurably('level_start', {'level': 1});

      final failed = await q.flush();
      expect(failed.isSuccess, isFalse);
      expect(q.pendingCount, 1);
      expect(uploaded, hasLength(2));

      fail = false;
      final succeeded = await q.flush();
      expect(succeeded.value, 1);
      expect(q.pendingCount, 0);
      expect(storage.getString(StorageKeys.analyticsQueueV1), isNull);
      q.dispose();
    },
  );

  test(
    'flush is single-flight and enqueues during upload survive ACK',
    () async {
      consent.grant(ConsentCategory.analytics);
      final release = Completer<void>();
      var uploads = 0;
      final q = queue(
        uploader: (_) async {
          uploads++;
          await release.future;
        },
      );
      await q.enqueueDurably('level_start', {'level': 1});

      final first = q.flush();
      final second = q.flush();
      await Future<void>.delayed(Duration.zero);
      await q.enqueueDurably('level_start', {'level': 2});
      release.complete();

      expect(await first, same(await second));
      expect(uploads, 1);
      expect(q.pendingEvents.map((e) => e.params['level']), [2]);
      q.dispose();
    },
  );

  test(
    'revoking consent purges memory/storage and blocks in-flight upload ACK',
    () async {
      consent.grant(ConsentCategory.analytics);
      final release = Completer<void>();
      final q = queue(uploader: (_) => release.future);
      await q.enqueueDurably('level_start', {'level': 1});

      final flush = q.flush();
      await Future<void>.delayed(Duration.zero);
      consent.deny(ConsentCategory.analytics);
      await q.flushPersistence();

      expect(q.pendingCount, 0);
      expect(storage.getString(StorageKeys.analyticsQueueV1), isNull);
      release.complete();
      expect((await flush).isSuccess, isFalse);
      q.dispose();
    },
  );

  test('durable enqueue rollback memory when persistence fails', () async {
    consent.grant(ConsentCategory.analytics);
    final failingStorage = _FailingAnalyticsStorage(
      await SharedPreferences.getInstance(),
    );
    final q = PrivacyAwareAnalyticsQueue(
      storage: failingStorage,
      consent: consent,
      registry: registry,
      uploader: (_) async {},
      idGenerator: () => 'failed-id',
    );

    await expectLater(
      q.enqueueDurably('level_start', {'level': 1}),
      throwsStateError,
    );
    expect(q.pendingCount, 0);
    expect(q.auditSnapshot.queued, 0);
    expect(() => q.logEvent('level_start', {'level': 2}), returnsNormally);
    await Future<void>.delayed(Duration.zero);
    expect(q.pendingCount, 0);
    q.dispose();
  });

  Map<String, Object?> storedEvent(
    int sequence, {
    Object? params = const <String, Object?>{'level': 1},
  }) => {
    'id': 'stored-$sequence',
    'name': 'level_start',
    'params': params,
    'sequence': sequence,
    'createdAtMs': 1,
  };

  group('hydrate: dữ liệu lưu hỏng', () {
    test('bỏ event sai kiểu, giữ event hợp lệ theo thứ tự sequence và '
        'đặt sequence kế tiếp sau mốc lớn nhất', () async {
      consent.grant(ConsentCategory.analytics);
      await storage.setString(
        StorageKeys.analyticsQueueV1,
        jsonEncode([
          storedEvent(5),
          'không phải map',
          {'id': 1, 'name': 'level_start'},
          storedEvent(
            7,
            params: {
              'bad': {'nested': true},
            },
          ),
          storedEvent(2),
        ]),
      );

      final q = queue(uploader: (_) async {});

      expect(q.pendingEvents.map((e) => e.sequence), [2, 5]);
      expect(await q.enqueueDurably('level_start', {'level': 9}), isTrue);
      expect(q.pendingEvents.last.sequence, 6);
      q.dispose();
    });

    test('JSON hỏng hoặc không phải list: queue rỗng, không throw', () async {
      consent.grant(ConsentCategory.analytics);
      for (final raw in ['không phải json {{', '{"a":1}']) {
        await storage.setString(StorageKeys.analyticsQueueV1, raw);
        final q = queue(uploader: (_) async {});
        expect(q.pendingCount, 0, reason: raw);
        q.dispose();
      }
    });

    test('đọc lại không vượt capacity', () async {
      consent.grant(ConsentCategory.analytics);
      await storage.setString(
        StorageKeys.analyticsQueueV1,
        jsonEncode([storedEvent(1), storedEvent(2), storedEvent(3)]),
      );

      final q = queue(uploader: (_) async {}, capacity: 2);

      expect(q.pendingCount, 2);
      q.dispose();
    });

    test('consent chưa cấp: dữ liệu cũ bị xoá khỏi storage', () async {
      await storage.setString(
        StorageKeys.analyticsQueueV1,
        jsonEncode([storedEvent(1)]),
      );

      final q = queue(uploader: (_) async {});
      await q.flushPersistence();

      expect(q.pendingCount, 0);
      expect(storage.getString(StorageKeys.analyticsQueueV1), isNull);
      q.dispose();
    });
  });

  test('totalDropped cộng mọi lý do, id mặc định là hex 32 ký tự và '
      'không trùng giữa các event', () async {
    final q = PrivacyAwareAnalyticsQueue(
      storage: storage,
      consent: consent,
      registry: registry,
      uploader: (_) async {},
      nowMs: () => now++,
    );
    await q.enqueueDurably('level_start', {'level': 1}); // chưa cấp consent
    consent.grant(ConsentCategory.analytics);
    await q.enqueueDurably('khong_co_schema', {'level': 1});
    expect(q.auditSnapshot.totalDropped, 2);

    await q.enqueueDurably('level_start', {'level': 1});
    await q.enqueueDurably('level_start', {'level': 2});

    final ids = q.pendingEvents.map((e) => e.id).toList();
    expect(ids, hasLength(2));
    expect(ids.toSet(), hasLength(2));
    for (final value in ids) {
      expect(value, matches(RegExp(r'^[0-9a-f]{32}$')));
    }
    q.dispose();
  });

  group('sampling theo tên event', () {
    test('samplingRateOverrides ghi đè mặc định, rate 0 luôn loại', () async {
      consent.grant(ConsentCategory.analytics);
      final q = PrivacyAwareAnalyticsQueue(
        storage: storage,
        consent: consent,
        registry: registry,
        uploader: (_) async {},
        defaultSamplingRate: 1,
        samplingRateOverrides: const {'level_start': 0},
        idGenerator: () => 'id-${id++}',
        nowMs: () => now++,
        sessionSeed: () => 'session',
      );

      expect(await q.enqueueDurably('level_start', {'level': 1}), isFalse);
      expect(
        q.auditSnapshot.droppedByReason[AnalyticsQueueDropReason.sampledOut],
        1,
      );
      q.dispose();
    });

    test(
      'rate giữa 0 và 1 quyết định theo seed, ổn định giữa các lần',
      () async {
        consent.grant(ConsentCategory.analytics);
        Future<bool> accepted(String seed) async {
          final q = PrivacyAwareAnalyticsQueue(
            storage: StorageService(null),
            consent: consent,
            registry: registry,
            uploader: (_) async {},
            defaultSamplingRate: 0.5,
            idGenerator: () => 'id-${id++}',
            nowMs: () => now++,
            sessionSeed: () => seed,
          );
          final result = await q.enqueueDurably('level_start', {'level': 1});
          q.dispose();
          return result;
        }

        final seeds = List.generate(40, (i) => 'seed-$i');
        final first = [for (final s in seeds) await accepted(s)];
        final second = [for (final s in seeds) await accepted(s)];

        expect(second, first);
        expect(first, contains(true));
        expect(first, contains(false));
      },
    );
  });

  group('flush: consent và lỗi lưu', () {
    test(
      'consent bị thu hồi trước flush: purge, trả validation, không upload',
      () async {
        consent.grant(ConsentCategory.analytics);
        var uploads = 0;
        final q = queue(uploader: (_) async => uploads++);
        await q.enqueueDurably('level_start', {'level': 1});

        // Ghi thẳng storage, KHÔNG gọi consent.deny(): deny() bump `revision`
        // nên worker nền tự purge trước flush và nhánh purge của flush không
        // còn được kiểm. Ghi lặng để chỉ flush() mới thấy consent đã mất.
        revokeSilently(ConsentCategory.analytics);
        expect(q.pendingCount, 1, reason: 'worker nền không được purge sẵn');
        final result = await q.flush();

        expect(result, isA<SdkFailure<int>>());
        expect((result as SdkFailure<int>).kind, SdkErrorKind.validation);
        expect(uploads, 0);
        expect(q.pendingCount, 0);
        expect(storage.getString(StorageKeys.analyticsQueueV1), isNull);
        q.dispose();
      },
    );

    test('consent bị thu hồi giữa lúc upload: purge, trả validation', () async {
      consent.grant(ConsentCategory.analytics);
      var uploads = 0;
      final q = queue(
        uploader: (_) async {
          uploads++;
          revokeSilently(ConsentCategory.analytics);
        },
      );
      await q.enqueueDurably('level_start', {'level': 1});

      final result = await q.flush();

      expect(uploads, 1);
      expect(result, isA<SdkFailure<int>>());
      expect((result as SdkFailure<int>).kind, SdkErrorKind.validation);
      expect(result.message, contains('revoked during upload'));
      expect(q.pendingCount, 0);
      expect(storage.getString(StorageKeys.analyticsQueueV1), isNull);
      expect(q.auditSnapshot.uploaded, 0);
      q.dispose();
    });

    test('flush đồng thời dùng chung 1 lần upload', () async {
      consent.grant(ConsentCategory.analytics);
      var uploads = 0;
      final gate = Completer<void>();
      final q = queue(
        uploader: (_) async {
          uploads++;
          await gate.future;
        },
      );
      await q.enqueueDurably('level_start', {'level': 1});

      final a = q.flush();
      final b = q.flush();
      expect(identical(a, b), isTrue);
      gate.complete();
      await Future.wait([a, b]);

      expect(uploads, 1);
      q.dispose();
    });

    test(
      'upload xong nhưng ghi lại hàng đợi lỗi: flush trả SdkFailure(storage)',
      () async {
        consent.grant(ConsentCategory.analytics);
        // enqueueDurably cũng ghi storage nên sẽ throw; nạp sẵn event qua
        // storage thường rồi để queue (storage hỏng ghi) hydrate lại.
        // 2 event, batchSize 1: sau upload còn 1 event nên phải ghi lại bằng
        // setString (hỏng); nếu queue về rỗng thì nó gọi remove và không lỗi.
        await storage.setString(
          StorageKeys.analyticsQueueV1,
          jsonEncode([storedEvent(1), storedEvent(2)]),
        );
        final q = PrivacyAwareAnalyticsQueue(
          storage: _FailingAnalyticsStorage(
            await SharedPreferences.getInstance(),
          ),
          consent: consent,
          registry: registry,
          batchSize: 1,
          uploader: (_) async {},
        );
        expect(q.pendingCount, 2);

        final result = await q.flush();

        expect(result, isA<SdkFailure<int>>());
        expect((result as SdkFailure<int>).kind, SdkErrorKind.storage);
        q.dispose();
      },
    );

    test('đã dispose: enqueue bị loại như chưa cấp consent', () async {
      consent.grant(ConsentCategory.analytics);
      final q = queue(uploader: (_) async {});
      q.dispose();

      expect(await q.enqueueDurably('level_start', {'level': 1}), isFalse);
      expect(
        q.auditSnapshot.droppedByReason[AnalyticsQueueDropReason
            .consentNotGranted],
        1,
      );
    });
  });

  test('constructor validates capacity, batch size, and sampling rates', () {
    Future<void> uploader(List<QueuedAnalyticsEvent> _) async {}

    expect(() => queue(uploader: uploader, capacity: 0), throwsArgumentError);
    expect(() => queue(uploader: uploader, batchSize: 0), throwsArgumentError);
    expect(
      () => queue(uploader: uploader, samplingRate: 1.1),
      throwsArgumentError,
    );
  });
}

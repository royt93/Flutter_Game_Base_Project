import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/consent_state_service.dart';
import 'package:roy_casual_kit/core/privacy_aware_analytics_queue.dart';
import 'package:roy_casual_kit/core/sdk_event_schema_registry.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/retry_policy.dart';
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

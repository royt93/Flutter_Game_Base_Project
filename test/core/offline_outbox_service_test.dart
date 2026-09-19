import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/connectivity_coordinator.dart';
import 'package:roy_casual_kit/core/offline_outbox_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/retry_policy.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';

OfflineOutboxService _service({
  required OutboxUploader uploader,
  StorageService? storage,
  int capacity = 3,
  ConflictPolicy conflictPolicy = ConflictPolicy.manual,
  ConflictMerger? merger,
  ConnectivityCoordinator? connectivity,
}) => OfflineOutboxService(
  storage: storage ?? StorageService(null),
  uploader: uploader,
  capacity: capacity,
  conflictPolicy: conflictPolicy,
  merger: merger,
  connectivity: connectivity,
  retryPolicy: const RetryPolicy(maxAttempts: 2, baseDelay: Duration.zero),
)..onInit();

void main() {
  group('OfflineOutboxService: enqueue cơ bản', () {
    test('enqueue thêm đúng 1 item vào items', () async {
      final service = _service(uploader: (p, k) async => const SyncAck());
      final result = service.enqueue(
        idempotencyKey: 'k1',
        payload: const {'score': 100},
      );
      expect(result, isA<SdkSuccess<void>>());
      expect(service.items.length, 1);
      expect(service.items.first.idempotencyKey, 'k1');
    });

    test('idempotencyKey rỗng bị reject', () {
      final service = _service(uploader: (p, k) async => const SyncAck());
      final result = service.enqueue(idempotencyKey: '', payload: const {});
      expect(result, isA<SdkFailure<void>>());
    });

    test('enqueue cùng idempotencyKey 2 lần: thay thế, không nhân đôi', () {
      final service = _service(uploader: (p, k) async => const SyncAck());
      service.enqueue(idempotencyKey: 'k1', payload: const {'v': 1});
      service.enqueue(idempotencyKey: 'k1', payload: const {'v': 2});
      expect(service.items.length, 1);
      expect(service.items.first.payload['v'], 2);
    });

    test('vượt capacity: evict item priority thấp nhất', () {
      final service = _service(uploader: (p, k) async => const SyncAck());
      service.enqueue(idempotencyKey: 'low', payload: const {}, priority: 0);
      service.enqueue(idempotencyKey: 'mid', payload: const {}, priority: 1);
      service.enqueue(idempotencyKey: 'high', payload: const {}, priority: 2);
      service.enqueue(idempotencyKey: 'new', payload: const {}, priority: 1);
      expect(service.items.length, 3);
      expect(
        service.items.map((i) => i.idempotencyKey),
        isNot(contains('low')),
      );
    });
  });

  group('OfflineOutboxService: drain thành công', () {
    test('drain gọi uploader và xoá item khi ack', () async {
      final calls = <String>[];
      final service = _service(
        uploader: (p, k) async {
          calls.add(k);
          return const SyncAck();
        },
      );
      service.enqueue(idempotencyKey: 'k1', payload: const {'score': 1});
      await service.drain();
      expect(calls, ['k1']);
      expect(service.items, isEmpty);
    });

    test('drain xử lý theo priority cao trước', () async {
      final order = <String>[];
      final service = _service(
        uploader: (p, k) async {
          order.add(k);
          return const SyncAck();
        },
      );
      service.enqueue(idempotencyKey: 'low', payload: const {}, priority: 0);
      service.enqueue(idempotencyKey: 'high', payload: const {}, priority: 5);
      await service.drain();
      expect(order, ['high', 'low']);
    });

    test(
      'item hết hạn (expiresAtMs quá khứ) bị drop, không gọi uploader',
      () async {
        final calls = <String>[];
        final service = _service(
          uploader: (p, k) async {
            calls.add(k);
            return const SyncAck();
          },
        );
        service.enqueue(
          idempotencyKey: 'expired',
          payload: const {},
          expiresAtMs: 1,
        );
        await service.drain();
        expect(calls, isEmpty);
        expect(service.items, isEmpty);
      },
    );

    test(
      'uploader throw hết retry: item vẫn còn trong outbox (không mất)',
      () async {
        final service = _service(
          uploader: (p, k) async => throw Exception('network down'),
        );
        service.enqueue(idempotencyKey: 'k1', payload: const {});
        await service.drain();
        expect(service.items.length, 1);
      },
    );
  });

  group('OfflineOutboxService: conflict policy reject', () {
    test('conflict + reject: item bị xoá khỏi outbox, không giữ lại', () async {
      final service = _service(
        conflictPolicy: ConflictPolicy.reject,
        uploader: (p, k) async => const SyncConflict({'server': true}),
      );
      service.enqueue(idempotencyKey: 'k1', payload: const {'v': 1});
      await service.drain();
      expect(service.items, isEmpty);
    });
  });

  group('OfflineOutboxService: conflict policy merge', () {
    test(
      'conflict + merge: merger được gọi, upload lại payload merge, ack thì xoá item',
      () async {
        final uploadedPayloads = <Map<String, Object?>>[];
        var callCount = 0;
        final service = _service(
          conflictPolicy: ConflictPolicy.merge,
          merger: (local, remote) => {
            'v': (local['v'] as int) + (remote['v'] as int),
          },
          uploader: (p, k) async {
            callCount++;
            uploadedPayloads.add(p);
            if (callCount == 1) return const SyncConflict({'v': 10});
            return const SyncAck();
          },
        );
        service.enqueue(idempotencyKey: 'k1', payload: const {'v': 5});
        await service.drain();

        expect(uploadedPayloads.last['v'], 15);
        expect(service.items, isEmpty);
      },
    );

    test(
      'conflict + merge nhưng lần upload lại vẫn conflict: chuyển sang manual review',
      () async {
        final service = _service(
          conflictPolicy: ConflictPolicy.merge,
          merger: (local, remote) => {'v': 999},
          uploader: (p, k) async => const SyncConflict({'v': 10}),
        );
        service.enqueue(idempotencyKey: 'k1', payload: const {'v': 5});
        await service.drain();

        expect(service.manualReviewItems.length, 1);
        expect(service.manualReviewItems.first.idempotencyKey, 'k1');
      },
    );
  });

  group('OfflineOutboxService: conflict policy manual', () {
    test(
      'conflict + manual: item chuyển sang manualReview, không tự retry',
      () async {
        final calls = <String>[];
        final service = _service(
          conflictPolicy: ConflictPolicy.manual,
          uploader: (p, k) async {
            calls.add(k);
            return const SyncConflict({'server': 'value'});
          },
        );
        service.enqueue(idempotencyKey: 'k1', payload: const {'v': 1});
        await service.drain();
        await service
            .drain(); // gọi lại drain lần 2 không được retry item manual

        expect(calls, ['k1']);
        expect(service.manualReviewItems.length, 1);
        expect(
          service.manualReviewItems.first.remotePayload?['server'],
          'value',
        );
      },
    );

    test(
      'resolveManual(keepLocal): đưa lại vào hàng đợi pending, drain lại thử upload',
      () async {
        final calls = <String>[];
        var shouldConflict = true;
        final service = _service(
          conflictPolicy: ConflictPolicy.manual,
          uploader: (p, k) async {
            calls.add(k);
            if (shouldConflict) return const SyncConflict({'server': 'value'});
            return const SyncAck();
          },
        );
        service.enqueue(idempotencyKey: 'k1', payload: const {'v': 1});
        await service.drain();
        expect(service.manualReviewItems.length, 1);

        shouldConflict = false;
        final resolved = service.resolveManual(
          idempotencyKey: 'k1',
          resolution: ManualResolution.keepLocal,
        );
        expect(resolved, isA<SdkSuccess<void>>());
        expect(service.manualReviewItems, isEmpty);

        await service.drain();
        expect(calls, ['k1', 'k1']);
        expect(service.items, isEmpty);
      },
    );

    test('resolveManual(acceptRemote): xoá item khỏi outbox hẳn', () async {
      final service = _service(
        conflictPolicy: ConflictPolicy.manual,
        uploader: (p, k) async => const SyncConflict({'server': 'value'}),
      );
      service.enqueue(idempotencyKey: 'k1', payload: const {'v': 1});
      await service.drain();

      final resolved = service.resolveManual(
        idempotencyKey: 'k1',
        resolution: ManualResolution.acceptRemote,
      );
      expect(resolved, isA<SdkSuccess<void>>());
      expect(service.items, isEmpty);
      expect(service.manualReviewItems, isEmpty);
    });

    test('resolveManual với idempotencyKey không tồn tại bị reject', () {
      final service = _service(uploader: (p, k) async => const SyncAck());
      final result = service.resolveManual(
        idempotencyKey: 'missing',
        resolution: ManualResolution.acceptRemote,
      );
      expect(result, isA<SdkFailure<void>>());
    });
  });

  group('OfflineOutboxService: persist qua restart (crash giữa upload/ack)', () {
    test(
      'item vẫn còn trong outbox nếu chưa từng ack, đọc lại đúng qua restart',
      () async {
        final storage = StorageService(null);
        final first = _service(
          storage: storage,
          uploader: (p, k) async => throw Exception('crash trước ack'),
        );
        first.enqueue(idempotencyKey: 'k1', payload: const {'v': 1});
        await first.drain();
        expect(first.items.length, 1);

        final second = _service(
          storage: storage,
          uploader: (p, k) async => const SyncAck(),
        );
        expect(second.items.length, 1);
        expect(second.items.first.idempotencyKey, 'k1');
      },
    );

    test(
      'item đã ack không còn xuất hiện lại sau restart (không mất, không lặp)',
      () async {
        final storage = StorageService(null);
        final first = _service(
          storage: storage,
          uploader: (p, k) async => const SyncAck(),
        );
        first.enqueue(idempotencyKey: 'k1', payload: const {'v': 1});
        await first.drain();
        expect(first.items, isEmpty);

        final second = _service(
          storage: storage,
          uploader: (p, k) async => const SyncAck(),
        );
        expect(second.items, isEmpty);
      },
    );

    test('manualReview item giữ nguyên remotePayload qua restart', () async {
      final storage = StorageService(null);
      final first = _service(
        storage: storage,
        conflictPolicy: ConflictPolicy.manual,
        uploader: (p, k) async => const SyncConflict({'server': 'value'}),
      );
      first.enqueue(idempotencyKey: 'k1', payload: const {'v': 1});
      await first.drain();

      final second = _service(
        storage: storage,
        uploader: (p, k) async => const SyncAck(),
      );
      expect(second.manualReviewItems.length, 1);
      expect(second.manualReviewItems.first.remotePayload?['server'], 'value');
    });
  });

  group('OfflineOutboxService: corrupt save', () {
    test('save hỏng không throw, reset về rỗng', () async {
      final storage = StorageService(null);
      await storage.setString('offline_outbox_v1', 'not json {{{');
      final service = _service(
        storage: storage,
        uploader: (p, k) async => const SyncAck(),
      );
      expect(service.items, isEmpty);
      expect(() => service.items, returnsNormally);
    });
  });

  group('OfflineOutboxService: auto-drain qua ConnectivityCoordinator', () {
    Timer immediateTimer(Duration delay, void Function() callback) =>
        Timer(Duration.zero, callback);

    test(
      'enqueue lúc offline: KHÔNG tự drain; chuyển sang online: tự động drain, không cần gọi tay',
      () async {
        final calls = <String>[];
        final signal = FakeConnectivitySignal();
        final connectivity = ConnectivityCoordinator(
          signal: signal,
          probe: () async => true,
          createTimer: immediateTimer,
        );
        final service = _service(
          connectivity: connectivity,
          uploader: (payload, key) async {
            calls.add(key);
            return const SyncAck();
          },
        );

        service.enqueue(idempotencyKey: 'k1', payload: const {'score': 1});
        await pumpEventQueue();
        expect(calls, isEmpty, reason: 'chưa online thì chưa tự drain');
        expect(service.items, hasLength(1));

        signal.setHasInterface(true);
        await pumpEventQueue();

        expect(calls, ['k1']);
        expect(service.items, isEmpty);
      },
    );

    test(
      'enqueue lúc ĐÃ online sẵn: tự drain ngay trong chính lần enqueue đó',
      () async {
        final calls = <String>[];
        final signal = FakeConnectivitySignal(initialHasInterface: true);
        final connectivity = ConnectivityCoordinator(
          signal: signal,
          probe: () async => true,
          createTimer: immediateTimer,
        );
        await pumpEventQueue(); // để coordinator kịp lên online trước enqueue

        final service = _service(
          connectivity: connectivity,
          uploader: (payload, key) async {
            calls.add(key);
            return const SyncAck();
          },
        );

        service.enqueue(idempotencyKey: 'k1', payload: const {'score': 1});
        await pumpEventQueue();

        expect(calls, ['k1']);
        expect(service.items, isEmpty);
      },
    );
  });
}

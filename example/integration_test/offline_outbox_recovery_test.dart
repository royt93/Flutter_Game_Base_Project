import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roy_casual_kit/core/connectivity_coordinator.dart';
import 'package:roy_casual_kit/core/offline_outbox_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline outbox persists and drains after simulated reconnect', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);
    final storageKey =
        'device_recovery_${DateTime.now().microsecondsSinceEpoch}';
    final signal = FakeConnectivitySignal();
    var reachable = false;
    final uploads = <(String, Map<String, Object?>)>[];
    final uploadCompleted = Completer<void>();
    final connectivity = Get.put(
      ConnectivityCoordinator(
        signal: signal,
        probe: () async => reachable,
        debounceWindow: const Duration(milliseconds: 10),
        probeInterval: const Duration(minutes: 1),
      ),
    );
    final outbox = Get.put(
      OfflineOutboxService(
        storage: storage,
        storageKey: storageKey,
        connectivity: connectivity,
        uploader: (payload, key) async {
          uploads.add((key, Map<String, Object?>.from(payload)));
          uploadCompleted.complete();
          return const SyncAck();
        },
      ),
    );
    addTearDown(() async {
      Get.delete<OfflineOutboxService>(force: true);
      Get.delete<ConnectivityCoordinator>(force: true);
      await storage.flush();
      await prefs.remove(storageKey);
      signal.dispose();
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Recovery harness'))),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(connectivity.state, ConnectivityState.offline);
    final queued = await outbox.enqueueDurably(
      idempotencyKey: 'device-recovery-1',
      payload: const {'score': 42},
    );
    expect(queued.isSuccess, isTrue);
    expect(uploads, isEmpty);
    expect(outbox.items, hasLength(1));
    expect(prefs.getString(storageKey), contains('device-recovery-1'));

    reachable = true;
    signal.setHasInterface(true);
    await uploadCompleted.future.timeout(const Duration(seconds: 10));
    for (var attempt = 0; attempt < 20 && outbox.items.isNotEmpty; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await storage.flush();

    expect(connectivity.state, ConnectivityState.online);
    expect(uploads, hasLength(1));
    expect(uploads.single.$1, 'device-recovery-1');
    expect(uploads.single.$2, {'score': 42});
    expect(outbox.items, isEmpty);
    expect(prefs.getString(storageKey), '[]');
    expect(find.text('Recovery harness'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

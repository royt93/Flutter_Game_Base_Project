import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/achievement_sync_seam.dart';
import 'package:roy_casual_kit/core/analytics_provider.dart';
import 'package:roy_casual_kit/core/cloud_save_provider.dart';
import 'package:roy_casual_kit/core/crash_reporter.dart';
import 'package:roy_casual_kit/core/plugin_adapter_conformance_suite.dart';
import 'package:roy_casual_kit/core/purchase_seam.dart';
import 'package:roy_casual_kit/core/secure_storage_adapter.dart';

class _ThrowingAnalyticsProvider implements AnalyticsProvider {
  @override
  void logEvent(String name, [Map<String, Object?>? params]) =>
      throw StateError('boom');
}

class _HangingCloudSaveProvider implements CloudSaveProvider {
  @override
  Future<void> signIn() => Completer<void>().future; // không bao giờ hoàn tất
  @override
  Future<void> upload(Map<String, Object?> data) async {}
  @override
  Future<Map<String, Object?>?> download() async => null;
}

class _ThrowingCloudSaveProvider implements CloudSaveProvider {
  @override
  Future<void> signIn() async => throw StateError('boom');
  @override
  Future<void> upload(Map<String, Object?> data) async =>
      throw StateError('boom');
  @override
  Future<Map<String, Object?>?> download() async => throw StateError('boom');
}

class _LeakySecureStorageAdapter implements SecureStorageAdapter {
  final _values = <String, String>{};
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String value) async => _values[key] = value;
  @override
  Future<void> delete(String key) async {
    // Cố tình KHÔNG xoá — mô phỏng adapter lỗi rò rỉ dữ liệu sau delete.
  }
  @override
  Future<void> clear() async {
    // Cố tình KHÔNG xoá gì cả.
  }
}

class _EntitlementLeakPurchaseSeam implements PurchaseSeam {
  @override
  Future<bool> buy(String productId) async => true;
  @override
  Future<void> restorePurchases() async {}
  @override
  bool isOwned(String productId) => true; // luôn báo đã sở hữu — bug thật
}

class _ThrowingCrashReporter implements CrashReporter {
  @override
  void recordError(Object error, StackTrace stack, {String? reason}) =>
      throw StateError('crash reporter itself crashed');
}

enum _SyncBehaviour { max, noop, add, downgrade, replace, race, clearConcurrent, wrong, nullPull, throwPush, throwPull, hangPush, hangPull }

class _AchievementAdapter implements AchievementSyncSeam {
  _AchievementAdapter(this.behaviour);
  final _SyncBehaviour behaviour;
  final progress = <String, int>{'unrelated': 99};
  final raceGate = Completer<void>();
  var concurrentCalls = 0;
  var pushCalls = 0;
  var pullCalls = 0;

  @override
  Future<void> pushProgress(Map<String, int> values) async {
    pushCalls++;
    if (behaviour == _SyncBehaviour.throwPush) throw StateError('offline');
    if (behaviour == _SyncBehaviour.hangPush) await Completer<void>().future;
    if (behaviour == _SyncBehaviour.noop) return;
    if (behaviour == _SyncBehaviour.clearConcurrent &&
        values.keys.any((key) => key.endsWith('_concurrent_shared')) &&
        concurrentCalls++ == 0) {
      progress.clear();
    }
    if (behaviour == _SyncBehaviour.race &&
        values.keys.any((key) => key.endsWith('_concurrent_shared'))) {
      final snapshot = Map<String, int>.of(progress);
      for (final entry in values.entries) {
        if (entry.value > (snapshot[entry.key] ?? 0)) snapshot[entry.key] = entry.value;
      }
      if (++concurrentCalls == 2) raceGate.complete();
      await raceGate.future;
      progress..clear()..addAll(snapshot);
      return;
    }
    if (behaviour == _SyncBehaviour.replace) progress.clear();
    for (final entry in values.entries) {
      if (behaviour == _SyncBehaviour.add) {
        progress[entry.key] = (progress[entry.key] ?? 0) + entry.value;
      } else if (behaviour == _SyncBehaviour.downgrade || behaviour == _SyncBehaviour.replace) {
        progress[entry.key] = entry.value;
      } else if (entry.value > (progress[entry.key] ?? 0)) {
        progress[entry.key] = entry.value;
      }
    }
  }

  @override
  Future<Map<String, int>?> pullProgress() async {
    pullCalls++;
    if (behaviour == _SyncBehaviour.throwPull) throw StateError('offline');
    if (behaviour == _SyncBehaviour.hangPull) return Completer<Map<String, int>?>().future;
    if (behaviour == _SyncBehaviour.nullPull) return null;
    if (behaviour == _SyncBehaviour.wrong) return {for (final key in progress.keys) key: 999};
    return Map.of(progress);
  }
}

void main() {
  group('PluginAdapterConformanceSuite: AchievementSyncSeam', () {
    Future<ConformanceReport> verify(_AchievementAdapter adapter) =>
        PluginAdapterConformanceSuite.verifyAchievementSyncSeam(
          adapter, testIdPrefix: 'isolated_probe',
          timeout: const Duration(milliseconds: 30),
        );

    test('max adapter passes five checks with unrelated backend data', () async {
      final adapter = _AchievementAdapter(_SyncBehaviour.max);
      final report = await verify(adapter);
      expect(report.adapterName, 'AchievementSyncSeam');
      expect(report.checks, hasLength(5));
      expect(report.passed, isTrue, reason: report.failures.join(', '));
      expect(adapter.progress['unrelated'], 99);
    });

    for (final behaviour in [_SyncBehaviour.noop, _SyncBehaviour.wrong, _SyncBehaviour.nullPull]) {
      test('$behaviour fails exact round-trip', () async {
        final report = await verify(_AchievementAdapter(behaviour));
        expect(report.checks['progress round-trips exactly'], isFalse);
      });
    }
    test('additive adapter fails repeat but round-trip succeeds', () async {
      final report = await verify(_AchievementAdapter(_SyncBehaviour.add));
      expect(report.checks['progress round-trips exactly'], isTrue);
      expect(report.checks['repeated uploads do not inflate progress'], isFalse);
    });
    test('overwriting a lower value fails max check', () async {
      final report = await verify(_AchievementAdapter(_SyncBehaviour.downgrade));
      expect(report.checks['lower uploads preserve maximum progress'], isFalse);
      expect(report.checks['uploads preserve unrelated achievement IDs'], isTrue);
    });
    test('whole-map replacement fails disjoint check', () async {
      final report = await verify(_AchievementAdapter(_SyncBehaviour.replace));
      expect(report.checks['uploads preserve unrelated achievement IDs'], isFalse);
      expect(report.checks['progress round-trips exactly'], isTrue);
    });
    test('concurrent uploads cannot erase progress from earlier checks', () async {
      final report = await verify(_AchievementAdapter(_SyncBehaviour.clearConcurrent));
      expect(report.failures, ['concurrent uploads preserve max and both achievement IDs']);
    });
    test('barrier-controlled lost update fails concurrent check only', () async {
      final report = await verify(_AchievementAdapter(_SyncBehaviour.race));
      expect(report.failures, ['concurrent uploads preserve max and both achievement IDs']);
    });
    for (final behaviour in [_SyncBehaviour.throwPush, _SyncBehaviour.throwPull, _SyncBehaviour.hangPush, _SyncBehaviour.hangPull]) {
      test('$behaviour yields five failures without throwing or hanging suite', () async {
        final report = await verify(_AchievementAdapter(behaviour));
        expect(report.failures, hasLength(5));
      });
    }
    test('validates blank prefix and nonpositive timeout before adapter calls', () async {
      final adapter = _AchievementAdapter(_SyncBehaviour.max);
      for (final prefix in ['', '   ']) {
        await expectLater(PluginAdapterConformanceSuite.verifyAchievementSyncSeam(
          adapter, testIdPrefix: prefix,
        ), throwsArgumentError);
      }
      for (final timeout in [Duration.zero, const Duration(milliseconds: -1)]) {
        await expectLater(PluginAdapterConformanceSuite.verifyAchievementSyncSeam(
          adapter, testIdPrefix: 'isolated_probe', timeout: timeout,
        ), throwsArgumentError);
      }
      expect(adapter.pushCalls, 0);
      expect(adapter.pullCalls, 0);
    });
    test('prefix is preserved and distinct prefixes can reuse sandbox', () async {
      final adapter = _AchievementAdapter(_SyncBehaviour.max);
      for (final prefix in [' first ', 'second']) {
        final report = await PluginAdapterConformanceSuite.verifyAchievementSyncSeam(
          adapter, testIdPrefix: prefix,
        );
        expect(report.passed, isTrue);
        expect(adapter.progress['${prefix}_roundtrip_a'], 3);
      }
    });
  });

  group('PluginAdapterConformanceSuite: AnalyticsProvider', () {
    test(
      'NoopAnalyticsProvider (fake reference) pass toàn bộ checklist',
      () async {
        final report =
            await PluginAdapterConformanceSuite.verifyAnalyticsProvider(
              NoopAnalyticsProvider(),
            );

        expect(report.passed, isTrue, reason: report.failures.join(', '));
      },
    );

    test('adapter throw ở logEvent: suite bắt được, không tự crash', () async {
      final report =
          await PluginAdapterConformanceSuite.verifyAnalyticsProvider(
            _ThrowingAnalyticsProvider(),
          );

      expect(report.passed, isFalse);
      expect(
        report.failures,
        contains('logEvent does not throw on a normal event'),
      );
    });
  });

  group('PluginAdapterConformanceSuite: CrashReporter', () {
    test('FakeCrashReporter (fake reference) pass toàn bộ checklist', () async {
      final report = await PluginAdapterConformanceSuite.verifyCrashReporter(
        FakeCrashReporter(),
      );

      expect(report.passed, isTrue, reason: report.failures.join(', '));
    });

    test('adapter tự throw khi recordError: suite bắt được', () async {
      final report = await PluginAdapterConformanceSuite.verifyCrashReporter(
        _ThrowingCrashReporter(),
      );

      expect(report.passed, isFalse);
      expect(
        report.failures,
        contains('recordError does not throw for a normal error'),
      );
    });
  });

  group('PluginAdapterConformanceSuite: CloudSaveProvider', () {
    test(
      'FakeCloudSaveProvider (fake reference) pass toàn bộ checklist',
      () async {
        final report =
            await PluginAdapterConformanceSuite.verifyCloudSaveProvider(
              FakeCloudSaveProvider(),
            );

        expect(report.passed, isTrue, reason: report.failures.join(', '));
      },
    );

    test(
      'adapter throw ở mọi method: suite bắt được nhiều check fail',
      () async {
        final report =
            await PluginAdapterConformanceSuite.verifyCloudSaveProvider(
              _ThrowingCloudSaveProvider(),
            );

        expect(report.passed, isFalse);
        expect(report.failures, contains('signIn does not throw'));
        expect(
          report.failures,
          contains('upload does not throw for a normal payload'),
        );
      },
    );

    test(
      'adapter treo mãi ở signIn: check timeout fail đúng, không hang cả suite',
      () async {
        final report =
            await PluginAdapterConformanceSuite.verifyCloudSaveProvider(
              _HangingCloudSaveProvider(),
              timeout: const Duration(milliseconds: 100),
            );

        expect(report.checks['signIn completes within timeout'], isFalse);
      },
    );
  });

  group('PluginAdapterConformanceSuite: SecureStorageAdapter', () {
    test(
      'FakeSecureStorageAdapter (fake reference) pass toàn bộ checklist',
      () async {
        final report =
            await PluginAdapterConformanceSuite.verifySecureStorageAdapter(
              FakeSecureStorageAdapter(),
            );

        expect(report.passed, isTrue, reason: report.failures.join(', '));
      },
    );

    test(
      'adapter KHÔNG xoá thật khi delete/clear: privacy check fail đúng chỗ',
      () async {
        final report =
            await PluginAdapterConformanceSuite.verifySecureStorageAdapter(
              _LeakySecureStorageAdapter(),
            );

        expect(report.passed, isFalse);
        expect(
          report.failures,
          contains(
            'delete actually removes the value (privacy: no residual read)',
          ),
        );
        expect(
          report.failures,
          contains(
            'clear wipes every previously-written key (privacy: no residual data)',
          ),
        );
        // Các check KHÁC (không liên quan bug này) vẫn phải pass — chứng
        // minh suite cô lập đúng từng check, không fail dây chuyền.
        expect(report.checks['write+read round-trips correctly'], isTrue);
      },
    );
  });

  group('PluginAdapterConformanceSuite: PurchaseSeam', () {
    test('FakePurchaseSeam (fake reference) pass toàn bộ checklist', () async {
      final report = await PluginAdapterConformanceSuite.verifyPurchaseSeam(
        FakePurchaseSeam(),
      );

      expect(report.passed, isTrue, reason: report.failures.join(', '));
    });

    test(
      'adapter báo đã sở hữu sản phẩm chưa từng mua: entitlement-leak check fail',
      () async {
        final report = await PluginAdapterConformanceSuite.verifyPurchaseSeam(
          _EntitlementLeakPurchaseSeam(),
        );

        expect(report.passed, isFalse);
        expect(
          report.failures,
          contains(
            'isOwned returns false for a never-bought product (no entitlement leak)',
          ),
        );
      },
    );
  });

  group('PluginAdapterConformanceSuite: AdRewardSeam', () {
    test('FakeAdRewardSeam pass toàn bộ checklist', () async {
      final report = await PluginAdapterConformanceSuite.verifyAdRewardSeam(
        FakeAdRewardSeam(),
      );

      expect(report.passed, isTrue, reason: report.failures.join(', '));
    });
  });

  group('ConformanceReport', () {
    test('passed = true khi mọi check true; failures rỗng', () {
      const report = ConformanceReport(
        adapterName: 'x',
        checks: {'a': true, 'b': true},
      );
      expect(report.passed, isTrue);
      expect(report.failures, isEmpty);
    });

    test(
      'passed = false khi có ít nhất 1 check false; failures liệt kê đúng',
      () {
        const report = ConformanceReport(
          adapterName: 'x',
          checks: {'a': true, 'b': false},
        );
        expect(report.passed, isFalse);
        expect(report.failures, ['b']);
      },
    );
  });
}

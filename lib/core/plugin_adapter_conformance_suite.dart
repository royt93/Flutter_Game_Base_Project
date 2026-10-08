import 'dart:async';

import 'achievement_sync_seam.dart';
import 'ad_reward_seam.dart';
import 'analytics_provider.dart';
import 'cloud_save_provider.dart';
import 'crash_reporter.dart';
import 'purchase_seam.dart';
import 'secure_storage_adapter.dart';

/// Result of running one adapter's checklist — a plain Dart report (same
/// shape as `RoyCasualKitContractReport`) so a consumer can use it from any
/// test runner and turn failures into their own preferred matcher.
class ConformanceReport {
  const ConformanceReport({required this.adapterName, required this.checks});

  final String adapterName;
  final Map<String, bool> checks;

  bool get passed => checks.values.every((v) => v);

  List<String> get failures => [
    for (final entry in checks.entries)
      if (!entry.value) entry.key,
  ];
}

/// Vendor-neutral conformance checks for the kit's platform adapters.
///
/// Every `verifyX` method only depends on the abstract seam interface — a
/// consumer runs it against their own concrete adapter without this
/// package (or the consumer's test) importing any vendor SDK. Each check
/// is independent and never throws itself: a check that would have thrown
/// is recorded as a `false` result instead, so one broken check never
/// aborts the rest of the checklist.
///
/// **Timeout** checks use a per-call `.timeout(timeout)` — they fail only
/// on an actual [TimeoutException], never on a different thrown error
/// (that's what the corresponding "does not throw" check is for) — so
/// each check tests exactly one property.
///
/// **Dispose**: these interfaces do not declare a dispose/close method
/// (they're stateless call surfaces, not owned resources), so there is no
/// generic "dispose" check here — a consumer adapter that itself owns a
/// disposable resource (a stream subscription, a native SDK handle) is
/// responsible for its own disposal test, outside this shared suite.
class PluginAdapterConformanceSuite {
  PluginAdapterConformanceSuite._();

  static Future<ConformanceReport> verifyAnalyticsProvider(
    AnalyticsProvider adapter, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final checks = <String, bool>{
      'logEvent does not throw on a normal event': await _noThrow(
        () async => adapter.logEvent('conformance_test_event', {'k': 'v'}),
        timeout,
      ),
      'logEvent completes within timeout': await _completesWithin(
        () async => adapter.logEvent('conformance_timeout_event'),
        timeout,
      ),
      'logEvent tolerates repeated/duplicate calls': await _noThrow(() async {
        adapter.logEvent('conformance_dup_event');
        adapter.logEvent('conformance_dup_event');
      }, timeout),
      'logEvent tolerates no params': await _noThrow(
        () async => adapter.logEvent('conformance_no_params_event'),
        timeout,
      ),
      'logEvent tolerates PII-shaped keys without throwing': await _noThrow(
        () async => adapter.logEvent('conformance_pii_event', {
          'email': 'test@example.com',
        }),
        timeout,
      ),
    };
    return ConformanceReport(adapterName: 'AnalyticsProvider', checks: checks);
  }

  static Future<ConformanceReport> verifyCrashReporter(
    CrashReporter adapter, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final checks = <String, bool>{
      'recordError does not throw for a normal error': await _noThrow(
        () async => adapter.recordError(
          StateError('conformance test'),
          StackTrace.current,
        ),
        timeout,
      ),
      'recordError completes within timeout': await _completesWithin(
        () async => adapter.recordError(
          StateError('conformance timeout'),
          StackTrace.current,
        ),
        timeout,
      ),
      'recordError tolerates repeated/duplicate calls': await _noThrow(
        () async {
          adapter.recordError(
            StateError('conformance dup'),
            StackTrace.current,
          );
          adapter.recordError(
            StateError('conformance dup'),
            StackTrace.current,
          );
        },
        timeout,
      ),
      'recordError tolerates a null reason': await _noThrow(
        () async => adapter.recordError(
          StateError('conformance test'),
          StackTrace.current,
        ),
        timeout,
      ),
      'recordError tolerates a non-Exception/Error object': await _noThrow(
        () async =>
            adapter.recordError('a plain string error', StackTrace.current),
        timeout,
      ),
    };
    return ConformanceReport(adapterName: 'CrashReporter', checks: checks);
  }

  static Future<ConformanceReport> verifyCloudSaveProvider(
    CloudSaveProvider adapter, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final checks = <String, bool>{
      'signIn does not throw': await _noThrow(() => adapter.signIn(), timeout),
      'signIn completes within timeout': await _completesWithin(
        () => adapter.signIn(),
        timeout,
      ),
      'upload does not throw for a normal payload': await _noThrow(
        () => adapter.upload({'level': 1}),
        timeout,
      ),
      'upload completes within timeout': await _completesWithin(
        () => adapter.upload({'level': 1}),
        timeout,
      ),
      'download completes within timeout': await _completesWithin(
        () => adapter.download(),
        timeout,
      ),
      'upload+download round-trips correctly': await _check(() async {
        await adapter.upload({'conformance_key': 'conformance_value'});
        final result = await adapter.download();
        return result != null &&
            result['conformance_key'] == 'conformance_value';
      }, timeout),
      'upload tolerates repeated/retry calls': await _noThrow(() async {
        await adapter.upload({'conformance_key': 'v1'});
        await adapter.upload({'conformance_key': 'v2'});
      }, timeout),
    };
    return ConformanceReport(adapterName: 'CloudSaveProvider', checks: checks);
  }

  static Future<ConformanceReport> verifySecureStorageAdapter(
    SecureStorageAdapter adapter, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    const key = 'conformance_test_key';
    final checks = <String, bool>{
      'write completes within timeout': await _completesWithin(
        () => adapter.write(key, 'v1'),
        timeout,
      ),
      'write+read round-trips correctly': await _check(() async {
        await adapter.write(key, 'roundtrip-value');
        return await adapter.read(key) == 'roundtrip-value';
      }, timeout),
      'read returns null for a never-written key': await _check(
        () async => await adapter.read('conformance_never_written_key') == null,
        timeout,
      ),
      'delete actually removes the value (privacy: no residual read)':
          await _check(() async {
            await adapter.write(key, 'to-be-deleted');
            await adapter.delete(key);
            return await adapter.read(key) == null;
          }, timeout),
      'clear wipes every previously-written key (privacy: no residual data)':
          await _check(() async {
            await adapter.write('conformance_k1', 'v1');
            await adapter.write('conformance_k2', 'v2');
            await adapter.clear();
            return await adapter.read('conformance_k1') == null &&
                await adapter.read('conformance_k2') == null;
          }, timeout),
      'write tolerates overwrite (retry) of the same key': await _noThrow(
        () async {
          await adapter.write(key, 'first');
          await adapter.write(key, 'second');
        },
        timeout,
      ),
    };
    return ConformanceReport(
      adapterName: 'SecureStorageAdapter',
      checks: checks,
    );
  }

  static Future<ConformanceReport> verifyPurchaseSeam(
    PurchaseSeam adapter, {
    Duration timeout = const Duration(seconds: 2),
    String testProductId = 'conformance_test_product',
  }) async {
    final checks = <String, bool>{
      'isOwned returns false for a never-bought product (no entitlement leak)':
          await _check(
            () async =>
                adapter.isOwned('conformance_never_bought_product') == false,
            timeout,
          ),
      'buy completes within timeout': await _completesWithin(
        () => adapter.buy(testProductId),
        timeout,
      ),
      'restorePurchases does not throw': await _noThrow(
        () => adapter.restorePurchases(),
        timeout,
      ),
      'restorePurchases completes within timeout': await _completesWithin(
        () => adapter.restorePurchases(),
        timeout,
      ),
      'buy tolerates repeated/duplicate calls without throwing': await _noThrow(
        () async {
          await adapter.buy(testProductId);
          await adapter.buy(testProductId);
        },
        timeout,
      ),
    };
    return ConformanceReport(adapterName: 'PurchaseSeam', checks: checks);
  }

  // Writes sandbox data; use a fresh prefix. Timeouts do not cancel I/O, and a concurrent probe cannot prove every race schedule.
  static Future<ConformanceReport> verifyAchievementSyncSeam(
    AchievementSyncSeam adapter, {
    required String testIdPrefix,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (testIdPrefix.trim().isEmpty) {
      throw ArgumentError.value(testIdPrefix, 'testIdPrefix', 'must not be blank');
    }
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'must be positive');
    }
    final roundTripA = '${testIdPrefix}_roundtrip_a';
    final roundTripB = '${testIdPrefix}_roundtrip_b';
    final repeat = '${testIdPrefix}_repeat';
    final maximum = '${testIdPrefix}_maximum';
    final disjointA = '${testIdPrefix}_disjoint_a';
    final disjointB = '${testIdPrefix}_disjoint_b';
    final shared = '${testIdPrefix}_concurrent_shared';
    final left = '${testIdPrefix}_concurrent_left';
    final right = '${testIdPrefix}_concurrent_right';
    final checks = <String, bool>{
      'progress round-trips exactly': await _check(() async {
        await adapter.pushProgress({roundTripA: 3, roundTripB: 7});
        final result = await adapter.pullProgress();
        return result?[roundTripA] == 3 && result?[roundTripB] == 7;
      }, timeout),
      'repeated uploads do not inflate progress': await _check(() async {
        await adapter.pushProgress({repeat: 3});
        await adapter.pushProgress({repeat: 3});
        return (await adapter.pullProgress())?[repeat] == 3;
      }, timeout),
      'lower uploads preserve maximum progress': await _check(() async {
        await adapter.pushProgress({maximum: 7});
        await adapter.pushProgress({maximum: 3});
        return (await adapter.pullProgress())?[maximum] == 7;
      }, timeout),
      'uploads preserve unrelated achievement IDs': await _check(() async {
        await adapter.pushProgress({disjointA: 3});
        await adapter.pushProgress({disjointB: 7});
        final result = await adapter.pullProgress();
        return result?[disjointA] == 3 && result?[disjointB] == 7;
      }, timeout),
      'concurrent uploads preserve max and both achievement IDs': await _check(
        () async {
          await Future.wait([
            adapter.pushProgress({shared: 9, left: 2}),
            adapter.pushProgress({shared: 4, right: 6}),
          ]);
          final result = await adapter.pullProgress();
          return result?[shared] == 9 &&
              result?[left] == 2 &&
              result?[right] == 6 &&
              result?[roundTripA] == 3 &&
              result?[roundTripB] == 7 &&
              result?[repeat] == 3 &&
              result?[maximum] == 7 &&
              result?[disjointA] == 3 &&
              result?[disjointB] == 7;
        },
        timeout,
      ),
    };
    return ConformanceReport(adapterName: 'AchievementSyncSeam', checks: checks);
  }

  static Future<ConformanceReport> verifyAdRewardSeam(
    AdRewardSeam adapter, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final checks = <String, bool>{
      'isReady does not throw': await _noThrow(
        () async => adapter.isReady,
        timeout,
      ),
      'showRewardedAd completes within timeout': await _completesWithin(
        () => adapter.showRewardedAd(),
        timeout,
      ),
    };
    return ConformanceReport(adapterName: 'AdRewardSeam', checks: checks);
  }

  /// Runs [action], bounded by [timeout] — a hang counts as a failure here
  /// (same as a thrown error), so a stuck adapter can never block the rest
  /// of the checklist regardless of which check catches it first.
  static Future<bool> _noThrow(
    FutureOr<void> Function() action,
    Duration timeout,
  ) async {
    try {
      await Future.sync(action).timeout(timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _check(
    Future<bool> Function() action,
    Duration timeout,
  ) async {
    try {
      return await action().timeout(timeout);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _completesWithin(
    Future<void> Function() action,
    Duration timeout,
  ) async {
    try {
      await action().timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    } catch (_) {
      // A different thrown error isn't a timeout failure — the matching
      // "does not throw" check is what reports that.
      return true;
    }
  }
}

/// Minimal, correct in-memory reference [CloudSaveProvider] — passes its
/// own conformance suite and doubles as an example implementation.
class FakeCloudSaveProvider implements CloudSaveProvider {
  bool signedIn = false;
  Map<String, Object?>? _stored;

  @override
  Future<void> signIn() async => signedIn = true;

  @override
  Future<void> upload(Map<String, Object?> data) async =>
      _stored = Map.of(data);

  @override
  Future<Map<String, Object?>?> download() async =>
      _stored == null ? null : Map.of(_stored!);
}

/// Minimal, correct in-memory reference [CrashReporter] — records every
/// call instead of actually reporting anywhere, for tests/examples.
class FakeCrashReporter implements CrashReporter {
  final recorded = <({Object error, StackTrace stack, String? reason})>[];

  @override
  void recordError(Object error, StackTrace stack, {String? reason}) =>
      recorded.add((error: error, stack: stack, reason: reason));
}

/// Minimal, correct in-memory reference [PurchaseSeam] — [buy] always
/// succeeds and marks the product owned, for tests/examples.
class FakePurchaseSeam implements PurchaseSeam {
  final _owned = <String>{};

  @override
  Future<bool> buy(String productId) async {
    _owned.add(productId);
    return true;
  }

  @override
  Future<void> restorePurchases() async {}

  @override
  bool isOwned(String productId) => _owned.contains(productId);
}

/// Minimal, correct in-memory reference [AdRewardSeam] — [showRewardedAd]
/// always completes successfully with reward earned.
class FakeAdRewardSeam implements AdRewardSeam {
  @override
  bool get isReady => true;

  @override
  Future<bool> showRewardedAd({String? placement}) async => true;
}

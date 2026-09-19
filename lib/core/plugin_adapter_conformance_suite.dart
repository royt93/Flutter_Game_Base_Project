import 'dart:async';

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

/// Standard conformance checklist for the 5 platform-neutral seams this
/// kit ships (`AnalyticsProvider`, `CloudSaveProvider`,
/// `SecureStorageAdapter`, `CrashReporter`, `PurchaseSeam`) — deliberately
/// excludes an "ads" adapter, since this kit ships no ads mediation seam
/// by product decision (FEAT-02's rejection; see FEAT-61's `ConsentStateService`
/// decision for the same scoping call).
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
/// **Dispose**: none of these 5 interfaces declare a dispose/close method
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
        () async =>
            adapter.recordError(StateError('conformance test'), StackTrace.current),
        timeout,
      ),
      'recordError completes within timeout': await _completesWithin(
        () async =>
            adapter.recordError(StateError('conformance timeout'), StackTrace.current),
        timeout,
      ),
      'recordError tolerates repeated/duplicate calls': await _noThrow(() async {
        adapter.recordError(StateError('conformance dup'), StackTrace.current);
        adapter.recordError(StateError('conformance dup'), StackTrace.current);
      }, timeout),
      'recordError tolerates a null reason': await _noThrow(
        () async => adapter.recordError(
          StateError('conformance test'),
          StackTrace.current,
        ),
        timeout,
      ),
      'recordError tolerates a non-Exception/Error object': await _noThrow(
        () async => adapter.recordError('a plain string error', StackTrace.current),
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
        return result != null && result['conformance_key'] == 'conformance_value';
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
      'delete actually removes the value (privacy: no residual read)': await _check(() async {
        await adapter.write(key, 'to-be-deleted');
        await adapter.delete(key);
        return await adapter.read(key) == null;
      }, timeout),
      'clear wipes every previously-written key (privacy: no residual data)': await _check(() async {
        await adapter.write('conformance_k1', 'v1');
        await adapter.write('conformance_k2', 'v2');
        await adapter.clear();
        return await adapter.read('conformance_k1') == null &&
            await adapter.read('conformance_k2') == null;
      }, timeout),
      'write tolerates overwrite (retry) of the same key': await _noThrow(() async {
        await adapter.write(key, 'first');
        await adapter.write(key, 'second');
      }, timeout),
    };
    return ConformanceReport(adapterName: 'SecureStorageAdapter', checks: checks);
  }

  static Future<ConformanceReport> verifyPurchaseSeam(
    PurchaseSeam adapter, {
    Duration timeout = const Duration(seconds: 2),
    String testProductId = 'conformance_test_product',
  }) async {
    final checks = <String, bool>{
      'isOwned returns false for a never-bought product (no entitlement leak)':
          await _check(
            () async => adapter.isOwned('conformance_never_bought_product') == false,
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
      'buy tolerates repeated/duplicate calls without throwing': await _noThrow(() async {
        await adapter.buy(testProductId);
        await adapter.buy(testProductId);
      }, timeout),
    };
    return ConformanceReport(adapterName: 'PurchaseSeam', checks: checks);
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

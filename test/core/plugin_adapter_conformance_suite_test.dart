import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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

void main() {
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

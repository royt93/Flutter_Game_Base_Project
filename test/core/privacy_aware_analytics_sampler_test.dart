import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/analytics_provider.dart';
import 'package:roy_casual_kit/core/consent_state_service.dart';
import 'package:roy_casual_kit/core/crash_reporter.dart';
import 'package:roy_casual_kit/core/privacy_aware_analytics_sampler.dart';
import 'package:roy_casual_kit/core/sdk_event_schema_registry.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingAnalyticsProvider implements AnalyticsProvider {
  final calls = <MapEntry<String, Map<String, Object?>?>>[];

  @override
  void logEvent(String name, [Map<String, Object?>? params]) {
    calls.add(MapEntry(name, params));
  }
}

class _ThrowingAnalyticsProvider implements AnalyticsProvider {
  @override
  void logEvent(String name, [Map<String, Object?>? params]) {
    throw Exception('provider down');
  }
}

class _FakeCrashReporter implements CrashReporter {
  final recorded = <String?>[];

  @override
  void recordError(Object error, StackTrace stack, {String? reason}) {
    recorded.add(reason);
  }
}

void _grantConsent() {
  final consent = ConsentStateService(policyVersion: 1);
  Get.put(consent, permanent: true);
  consent.grant(ConsentCategory.analytics);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.put(StorageService(await SharedPreferences.getInstance()), permanent: true);
  });

  group('consent gate', () {
    test('chưa có ConsentStateService -> default-deny, không forward', () {
      final inner = _RecordingAnalyticsProvider();
      final sampler = PrivacyAwareAnalyticsSampler(inner);

      sampler.logEvent('level_start');

      expect(inner.calls, isEmpty);
      expect(
        sampler.auditSnapshot.droppedByReason[AnalyticsDropReason.consentNotGranted],
        1,
      );
    });

    test('consent granted -> forward đúng name/params', () {
      _grantConsent();
      final inner = _RecordingAnalyticsProvider();
      final sampler = PrivacyAwareAnalyticsSampler(inner);

      sampler.logEvent('level_start', {'level': 3});

      expect(inner.calls, hasLength(1));
      expect(inner.calls.single.key, 'level_start');
      expect(inner.calls.single.value, {'level': 3});
      expect(sampler.auditSnapshot.forwarded, 1);
    });
  });

  group('deterministic sampling', () {
    test('sampling rate 0.0 cho 1 event: luôn drop, các event khác không ảnh hưởng', () {
      _grantConsent();
      final inner = _RecordingAnalyticsProvider();
      final sampler = PrivacyAwareAnalyticsSampler(
        inner,
        samplingRateOverrides: const {'noisy_event': 0.0},
      );

      for (var i = 0; i < 5; i++) {
        sampler.logEvent('noisy_event');
        sampler.logEvent('important_event');
      }

      expect(inner.calls.where((c) => c.key == 'noisy_event'), isEmpty);
      expect(inner.calls.where((c) => c.key == 'important_event'), hasLength(5));
      expect(
        sampler.auditSnapshot.droppedByReason[AnalyticsDropReason.sampledOut],
        5,
      );
    });

    test('cùng session seed + cùng event name -> quyết định giống hệt mọi lần gọi', () {
      _grantConsent();
      final inner = _RecordingAnalyticsProvider();
      final sampler = PrivacyAwareAnalyticsSampler(
        inner,
        defaultSamplingRate: 0.5,
        sessionSeed: () => 'fixed-session-abc',
      );

      final results = List.generate(20, (_) {
        inner.calls.clear();
        sampler.logEvent('repeat_event');
        return inner.calls.isNotEmpty;
      });

      expect(results.toSet(), hasLength(1)); // luôn cùng 1 giá trị (all-true hoặc all-false)
    });

    test('session seed khác nhau -> có thể ra quyết định khác nhau (không cùng 1 coin flip cứng)', () {
      _grantConsent();
      final inner = _RecordingAnalyticsProvider();

      bool sampledFor(String seed) {
        inner.calls.clear();
        final sampler = PrivacyAwareAnalyticsSampler(
          inner,
          defaultSamplingRate: 0.5,
          sessionSeed: () => seed,
        );
        sampler.logEvent('event_x');
        return inner.calls.isNotEmpty;
      }

      final outcomes = {
        for (var i = 0; i < 30; i++) i: sampledFor('session-$i'),
      };
      // Với 30 seed khác nhau và rate 0.5, gần như chắc chắn có cả true lẫn
      // false — nếu decision không phụ thuộc seed (bug) thì set này sẽ chỉ
      // có 1 giá trị.
      expect(outcomes.values.toSet(), hasLength(2));
    });

    test('rate ngoài [0,1] -> throw ArgumentError ngay lúc tạo', () {
      expect(
        () => PrivacyAwareAnalyticsSampler(
          _RecordingAnalyticsProvider(),
          defaultSamplingRate: 1.5,
        ),
        throwsArgumentError,
      );
      expect(
        () => PrivacyAwareAnalyticsSampler(
          _RecordingAnalyticsProvider(),
          samplingRateOverrides: const {'x': -0.1},
        ),
        throwsArgumentError,
      );
    });
  });

  group('PII redaction qua SdkEventSchemaRegistry', () {
    test('registry redact field pii trước khi tới provider, audit không tính rateLimited', () {
      _grantConsent();
      final registry = SdkEventSchemaRegistry()
        ..register(
          EventSchema(
            name: 'purchase',
            version: 1,
            params: {
              'itemId': const EventParamSchema(type: EventParamType.string),
              'email': const EventParamSchema(type: EventParamType.string, pii: true),
            },
          ),
        );
      final inner = _RecordingAnalyticsProvider();
      final sampler = PrivacyAwareAnalyticsSampler(inner, registry: registry);

      sampler.logEvent('purchase', {'itemId': 'sword', 'email': 'a@b.com'});

      expect(inner.calls.single.value, {'itemId': 'sword'});
      expect(inner.calls.single.value!.containsKey('email'), isFalse);
    });

    test('registry reject (unknown event) -> drop, không forward, đúng audit reason', () {
      _grantConsent();
      final registry = SdkEventSchemaRegistry();
      final inner = _RecordingAnalyticsProvider();
      final sampler = PrivacyAwareAnalyticsSampler(inner, registry: registry);

      sampler.logEvent('never_registered');

      expect(inner.calls, isEmpty);
      expect(
        sampler.auditSnapshot.droppedByReason[AnalyticsDropReason.schemaRejected],
        1,
      );
    });

    test('không truyền registry -> params đi qua nguyên vẹn, không redact', () {
      _grantConsent();
      final inner = _RecordingAnalyticsProvider();
      final sampler = PrivacyAwareAnalyticsSampler(inner);

      sampler.logEvent('any_event', {'email': 'a@b.com'});

      expect(inner.calls.single.value, {'email': 'a@b.com'});
    });
  });

  group('rate limit / backpressure', () {
    test('vượt maxEventsPerWindow trong cùng window -> drop, không throw, không block', () {
      _grantConsent();
      final inner = _RecordingAnalyticsProvider();
      var now = 1000;
      final sampler = PrivacyAwareAnalyticsSampler(
        inner,
        maxEventsPerWindow: 3,
        windowSize: const Duration(seconds: 1),
        nowMs: () => now,
      );

      for (var i = 0; i < 5; i++) {
        sampler.logEvent('spam');
      }

      expect(inner.calls, hasLength(3));
      expect(
        sampler.auditSnapshot.droppedByReason[AnalyticsDropReason.rateLimited],
        2,
      );
    });

    test('sang window mới -> budget reset, forward tiếp được', () {
      _grantConsent();
      final inner = _RecordingAnalyticsProvider();
      var now = 1000;
      final sampler = PrivacyAwareAnalyticsSampler(
        inner,
        maxEventsPerWindow: 2,
        windowSize: const Duration(seconds: 1),
        nowMs: () => now,
      );

      sampler.logEvent('a');
      sampler.logEvent('a');
      sampler.logEvent('a'); // dropped, hết budget window 1

      now += 1000; // sang window mới
      sampler.logEvent('a');

      expect(inner.calls, hasLength(3));
      expect(
        sampler.auditSnapshot.droppedByReason[AnalyticsDropReason.rateLimited],
        1,
      );
    });
  });

  group('inner provider throw', () {
    test('provider throw -> không crash caller, forward về CrashReporter', () {
      _grantConsent();
      final crashReporter = _FakeCrashReporter();
      Get.put<CrashReporter>(crashReporter, permanent: true);
      final sampler = PrivacyAwareAnalyticsSampler(_ThrowingAnalyticsProvider());

      expect(() => sampler.logEvent('boom'), returnsNormally);
      expect(crashReporter.recorded, hasLength(1));
    });
  });

  group('auditSnapshot', () {
    test('totalDropped cộng đúng mọi reason, forwarded đếm đúng', () {
      final inner = _RecordingAnalyticsProvider();
      final sampler = PrivacyAwareAnalyticsSampler(inner); // chưa consent

      sampler.logEvent('a');
      sampler.logEvent('b');

      final snapshot = sampler.auditSnapshot;
      expect(snapshot.forwarded, 0);
      expect(snapshot.totalDropped, 2);
      expect(snapshot.droppedByReason[AnalyticsDropReason.consentNotGranted], 2);
    });
  });
}

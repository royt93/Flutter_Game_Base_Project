import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/analytics_provider.dart';
import 'package:roy_casual_kit/core/consent_gated_analytics_provider.dart';
import 'package:roy_casual_kit/core/consent_state_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingAnalyticsProvider implements AnalyticsProvider {
  final calls = <MapEntry<String, Map<String, Object?>?>>[];

  @override
  void logEvent(String name, [Map<String, Object?>? params]) {
    calls.add(MapEntry(name, params));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.put(StorageService(await SharedPreferences.getInstance()), permanent: true);
  });

  test('chưa có ConsentStateService nào đăng ký: mặc định KHÔNG forward (default-deny)', () {
    final inner = _RecordingAnalyticsProvider();
    final gated = ConsentGatedAnalyticsProvider(inner);

    gated.logEvent('level_start');

    expect(inner.calls, isEmpty);
  });

  test('consent chưa quyết định (unknown): KHÔNG forward event', () {
    Get.put(ConsentStateService(policyVersion: 1), permanent: true);
    final inner = _RecordingAnalyticsProvider();
    final gated = ConsentGatedAnalyticsProvider(inner);

    gated.logEvent('level_start');

    expect(inner.calls, isEmpty);
  });

  test('consent denied: KHÔNG forward event', () {
    final consent = ConsentStateService(policyVersion: 1);
    Get.put(consent, permanent: true);
    consent.deny(ConsentCategory.analytics);
    final inner = _RecordingAnalyticsProvider();
    final gated = ConsentGatedAnalyticsProvider(inner);

    gated.logEvent('level_start');

    expect(inner.calls, isEmpty);
  });

  test('consent granted: forward đúng name và params xuống inner provider', () {
    final consent = ConsentStateService(policyVersion: 1);
    Get.put(consent, permanent: true);
    consent.grant(ConsentCategory.analytics);
    final inner = _RecordingAnalyticsProvider();
    final gated = ConsentGatedAnalyticsProvider(inner);

    gated.logEvent('level_start', {'level': 3});

    expect(inner.calls, hasLength(1));
    expect(inner.calls.single.key, 'level_start');
    expect(inner.calls.single.value, {'level': 3});
  });

  test('revoke consent giữa chừng: các logEvent sau đó không còn forward nữa', () {
    final consent = ConsentStateService(policyVersion: 1);
    Get.put(consent, permanent: true);
    consent.grant(ConsentCategory.analytics);
    final inner = _RecordingAnalyticsProvider();
    final gated = ConsentGatedAnalyticsProvider(inner);

    gated.logEvent('a');
    consent.deny(ConsentCategory.analytics);
    gated.logEvent('b');

    expect(inner.calls, hasLength(1));
    expect(inner.calls.single.key, 'a');
  });
}

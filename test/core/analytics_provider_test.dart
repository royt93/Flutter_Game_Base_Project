import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/analytics_provider.dart';

class _FakeAnalyticsProvider implements AnalyticsProvider {
  final List<String> logged = [];

  @override
  void logEvent(String name, [Map<String, Object?>? params]) {
    logged.add(name);
  }
}

void main() {
  tearDown(Get.reset);

  test('NoopAnalyticsProvider.logEvent không throw khi không có params', () {
    expect(() => NoopAnalyticsProvider().logEvent('level_start'), returnsNormally);
  });

  test('NoopAnalyticsProvider.logEvent không throw khi có params', () {
    expect(
      () => NoopAnalyticsProvider().logEvent('level_complete', {'level': 3}),
      returnsNormally,
    );
  });

  test('maybe trả về null khi chưa đăng ký implementation nào', () {
    expect(AnalyticsProvider.maybe, isNull);
  });

  test('maybe trả về đúng instance khi đã đăng ký', () {
    final provider = _FakeAnalyticsProvider();
    Get.put<AnalyticsProvider>(provider, permanent: true);

    expect(AnalyticsProvider.maybe, same(provider));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/crash_reporter.dart';

class _FakeCrashReporter implements CrashReporter {
  final List<Object> recorded = [];

  @override
  void recordError(Object error, StackTrace stack, {String? reason}) {
    recorded.add(error);
  }
}

void main() {
  tearDown(Get.reset);

  test('maybe trả về null khi chưa đăng ký implementation nào', () {
    expect(CrashReporter.maybe, isNull);
  });

  test('maybe trả về đúng instance khi đã đăng ký', () {
    final reporter = _FakeCrashReporter();
    Get.put<CrashReporter>(reporter, permanent: true);

    expect(CrashReporter.maybe, same(reporter));
  });

  test('recordError của implementation đã đăng ký nhận đúng error/stack', () {
    final reporter = _FakeCrashReporter();
    Get.put<CrashReporter>(reporter, permanent: true);

    final error = StateError('boom');
    CrashReporter.maybe?.recordError(error, StackTrace.current, reason: 'test');

    expect(reporter.recorded, [error]);
  });
}

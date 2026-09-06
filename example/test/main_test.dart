import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/crash_reporter.dart';
import 'package:roy_casual_kit_example/main.dart' as app;

class _FakeCrashReporter implements CrashReporter {
  final List<Object> recorded = [];

  @override
  void recordError(Object error, StackTrace stack, {String? reason}) {
    recorded.add(error);
  }
}

void main() {
  tearDown(Get.reset);

  test(
    'FlutterError.onError forward lỗi framework tới CrashReporter.maybe',
    () {
      final reporter = _FakeCrashReporter();
      Get.put<CrashReporter>(reporter, permanent: true);
      final originalOnError = FlutterError.onError;
      addTearDown(() => FlutterError.onError = originalOnError);

      app.installErrorHandlers();

      final details = FlutterErrorDetails(
        exception: StateError('boom-framework'),
        stack: StackTrace.current,
      );
      FlutterError.onError!(details);

      expect(reporter.recorded, [details.exception]);
    },
  );

  test(
    'lỗi async ngoài build method (runZonedGuarded) forward tới CrashReporter.maybe',
    () {
      final reporter = _FakeCrashReporter();
      Get.put<CrashReporter>(reporter, permanent: true);

      final error = StateError('boom-async');
      app.reportUncaughtError(error, StackTrace.current);

      expect(reporter.recorded, [error]);
    },
  );

  test(
    'chưa đăng ký CrashReporter nào → reportUncaughtError không throw',
    () {
      expect(
        () => app.reportUncaughtError(StateError('x'), StackTrace.current),
        returnsNormally,
      );
    },
  );
}

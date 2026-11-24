import 'dart:async';

import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

/// ENH-117: every test in this folder runs with leak tracking on.
///
/// Leak tracking is enabled folder by folder: widgets whose own tests are
/// clean are added here as regression tests, and the rest of `test/widget`
/// stays off until its leaks are fixed.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  await testMain();
}

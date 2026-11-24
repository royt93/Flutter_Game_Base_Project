import 'dart:async';

import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

/// ENH-117: the loose tests in `test/widget` run with leak tracking on.
/// `common/` and `leaks/` have their own config; `goldens/` opts out (see its
/// config).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  await testMain();
}

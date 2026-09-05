import 'package:flutter/foundation.dart';

/// Debug log prefixed 'roy93~' — prints ONLY in debug builds, no-op
/// (tree-shaken away) in release. Funnels every on-device debug trace
/// through one place, without cluttering release logs.
void dlog(String msg) {
  if (kDebugMode) debugPrint('roy93~ $msg');
}

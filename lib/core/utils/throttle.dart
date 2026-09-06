import 'package:flutter/foundation.dart';

/// Wraps [fn] so repeated calls within [window] of the last one that ran
/// are dropped — guards a button/action callback against rage-tap causing
/// a double purchase, double navigation, double submit. Only blocks
/// double-firing; a throw from [fn] still propagates (never swallowed).
VoidCallback throttled(VoidCallback fn, {Duration window = const Duration(milliseconds: 600)}) {
  DateTime? lastRun;
  return () {
    final now = DateTime.now();
    if (lastRun != null && now.difference(lastRun!) < window) return;
    lastRun = now;
    fn();
  };
}

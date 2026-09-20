import 'package:flutter/foundation.dart';

/// Wraps [fn] so repeated calls within [window] of the last one that ran
/// are dropped — guards a button/action callback against rage-tap causing
/// a double purchase, double navigation, double submit. Only blocks
/// double-firing; a throw from [fn] still propagates (never swallowed).
///
/// Measures elapsed time with a single [Stopwatch] started on first call
/// (BUG-28) rather than `DateTime.now()` — a monotonic clock can't be
/// rewound by a system-clock change, so it can't get stuck dropping every
/// call indefinitely the way a wall-clock diff would if the clock jumped
/// backward mid-session.
VoidCallback throttled(
  VoidCallback fn, {
  Duration window = const Duration(milliseconds: 600),
}) {
  final stopwatch = Stopwatch();
  Duration? lastRunAt;
  return () {
    if (!stopwatch.isRunning) stopwatch.start();
    final now = stopwatch.elapsed;
    if (lastRunAt != null && now - lastRunAt! < window) return;
    lastRunAt = now;
    fn();
  };
}

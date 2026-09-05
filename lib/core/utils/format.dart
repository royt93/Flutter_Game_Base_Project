// Shared formatting utilities.

import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Formats a [Duration] as "mm:ss" (minutes:seconds, each part 2 digits).
/// Used for the reconnect countdown on Home / Level Select / World Map.
String fmtDur(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Time remaining until **DEVICE-LOCAL midnight** [daysLeft] days from today.
///
/// Used for the Season / weekly tournament end countdown. The end timestamp
/// is built from LOCAL DATE COMPONENTS (`DateTime(year, month, day +
/// daysLeft)`) — matching how `todayEpochDay` computes it (also by local
/// date). The end timestamp used to be reconstructed with UTC midnight
/// (`endDay * 86400000`) while epoch-day was local → off by exactly the
/// timezone offset (UTC+7 → the countdown jumps to 00:00:00 7 hours early).
/// Dart normalizes an overflowing `day` automatically (e.g. 35 → next month).
Duration durationToLocalMidnight(DateTime now, int daysLeft) {
  final end = DateTime(now.year, now.month, now.day + daysLeft);
  final ms = end.millisecondsSinceEpoch - now.millisecondsSinceEpoch;
  return ms <= 0 ? Duration.zero : Duration(milliseconds: ms);
}

/// Formats a large integer (coins, score, price, boss HP…) with a THOUSANDS
/// SEPARATOR matching the CURRENT LANGUAGE: vi → "10.000", en → "10,000",
/// de → "10.000"… Uses [NumberFormat] (intl) keyed on `Get.locale`; if the
/// locale is unknown/has no data, falls back to manual grouping with '.'
/// (Vietnamese-style) so it NEVER throws.
String fmtNum(int n) {
  try {
    return NumberFormat.decimalPattern(
      Get.locale?.languageCode ?? 'en',
    ).format(n);
  } catch (_) {
    final neg = n < 0;
    final digits = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return neg ? '-$buf' : buf.toString();
  }
}

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

/// Formats [Duration] as "mm:ss" when under an hour (same as [fmtDur]), or
/// "hh:mm:ss" once it reaches an hour — for longer timers (energy/lives
/// refill, boss events) where [fmtDur] would wrap and understate the time
/// left. [fmtDur] itself is untouched (kept for its existing short-timer
/// contract); use this one for anything that can run past 60 minutes.
String fmtDurLong(Duration d) {
  if (d.inHours <= 0) return fmtDur(d);
  final h = d.inHours.toString().padLeft(2, '0');
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

const _compactUnits = [
  (1000000000000, 'T'),
  (1000000000, 'B'),
  (1000000, 'M'),
  (1000, 'K'),
];

/// Abbreviates large numbers (idle/tycoon-scale coin balances) as
/// `1.5K`/`2.4M`/`10.8B`/`1T`, one decimal place, trailing `.0` dropped.
/// Below 1000 falls back to [fmtNum] (locale-aware thousands separator).
String fmtNumCompact(num n) {
  final abs = n.abs();
  for (final (threshold, suffix) in _compactUnits) {
    if (abs >= threshold) {
      final scaled = n / threshold;
      var text = scaled.toStringAsFixed(1);
      if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
      return '$text$suffix';
    }
  }
  return fmtNum(n.toInt());
}

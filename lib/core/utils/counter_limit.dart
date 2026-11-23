import 'package:flutter/foundation.dart' show kIsWeb;

/// Largest value a persisted counter (balance, progress) may reach before an
/// increment must be rejected as an overflow.
///
/// Native platforms use the full int64 range. On the web an `int` is a
/// JavaScript double, exact only up to 2^53 - 1, so past that a "valid"
/// addition would silently round and corrupt the saved value; the web limit
/// is therefore 2^53 - 1. The native value is parsed from a string because
/// the web compiler rejects the literal `0x7FFFFFFFFFFFFFFF` at build time,
/// even in a branch that never runs on the web.
final int maxCounterValue = kIsWeb
    ? 9007199254740991
    : int.parse('9223372036854775807');

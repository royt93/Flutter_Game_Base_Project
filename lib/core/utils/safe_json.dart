/// Defensive `Map`-value parsers for JSON read from a not-fully-trusted
/// source (an old save file, cloud data from a different app version, a
/// hand-edited local file). Never throw — always fall back on a type
/// mismatch or `null` instead of crashing the whole load over one bad field.
library;

/// Reads [v] as an `int`. `dart:convert` decodes a whole-number JSON value
/// as `int` but a value with `.0` may come back as `double` (or vice versa
/// depending on the source) — both are accepted here.
///
/// A non-finite double (NaN/Infinity/-Infinity) — e.g. from a hand-crafted
/// payload or a remote adapter that isn't strict JSON — falls back instead
/// of throwing (BUG-22): `.toInt()` throws `UnsupportedError` for those,
/// which would otherwise violate this whole file's "never throw" contract.
int asIntOr(Object? v, int fallback) {
  // On the web `double.infinity is int` is true (an int is a JS number), so a
  // non-finite value would slip through the `is int` branch and be returned
  // as the "int". Check finiteness for every number, not just doubles.
  if (v is num) {
    if (!v.isFinite) return fallback;
    return v is int ? v : v.toInt();
  }
  return fallback;
}

/// Reads [v] as a `String` (empty string is a valid value, not a miss).
String asStringOr(Object? v, String fallback) => v is String ? v : fallback;

/// Reads [v] as a `double`, accepting a JSON integer for it too (see
/// [asIntOr] for why `dart:convert` can hand back either).
double asDoubleOr(Object? v, double fallback) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return fallback;
}

/// Reads [v] as a `bool`.
bool asBoolOr(Object? v, bool fallback) => v is bool ? v : fallback;

import 'dart:math';

/// Picks 1 item from [items] with probability proportional to the matching
/// entry in [weights] — the shared loot-table/gacha-reward primitive so
/// each new reward system (achievements, offline earnings, …) doesn't
/// reimplement this. Pass a seeded [random] in tests for determinism.
///
/// Does NOT support sampling-without-replacement (drawing multiple items
/// that can't repeat) — every call is independent.
T weightedRandomPick<T>(
  List<T> items,
  List<double> weights, {
  Random? random,
}) {
  assert(
    items.length == weights.length,
    'weightedRandomPick: items (${items.length}) and weights '
    '(${weights.length}) must be the same length',
  );
  assert(items.isNotEmpty, 'weightedRandomPick: items must not be empty');

  final total = weights.fold<double>(0, (sum, w) => sum + w);
  final target = (random ?? Random()).nextDouble() * total;

  var cumulative = 0.0;
  for (var i = 0; i < items.length; i++) {
    cumulative += weights[i];
    if (target < cumulative) return items[i];
  }
  return items.last; // floating-point rounding safety net
}

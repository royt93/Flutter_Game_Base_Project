import 'dart:math';

/// Picks 1 item from [items] with probability proportional to the matching
/// entry in [weights] — the shared loot-table/gacha-reward primitive so
/// each new reward system (achievements, offline earnings, …) doesn't
/// reimplement this. Pass a seeded [random] in tests for determinism.
///
/// Does NOT support sampling-without-replacement (drawing multiple items
/// that can't repeat) — every call is independent.
///
/// Throws [ArgumentError] (BUG-21 — a real runtime check, not just an
/// `assert`, so a misconfigured loot table still fails loudly in a release
/// build instead of silently and deterministically always returning
/// [items].last) for: mismatched lengths, an empty [items], any weight
/// that's negative or not finite (NaN/Infinity), or a total that isn't
/// finite and strictly positive.
T weightedRandomPick<T>(List<T> items, List<double> weights, {Random? random}) {
  if (items.length != weights.length) {
    throw ArgumentError(
      'weightedRandomPick: items (${items.length}) and weights '
      '(${weights.length}) must be the same length',
    );
  }
  if (items.isEmpty) {
    throw ArgumentError('weightedRandomPick: items must not be empty');
  }
  for (final w in weights) {
    if (!w.isFinite || w < 0) {
      throw ArgumentError(
        'weightedRandomPick: every weight must be finite and >= 0, got $w',
      );
    }
  }

  final total = weights.fold<double>(0, (sum, w) => sum + w);
  if (!total.isFinite || total <= 0) {
    throw ArgumentError(
      'weightedRandomPick: weights must sum to a finite value > 0, got $total',
    );
  }
  final target = (random ?? Random()).nextDouble() * total;

  var cumulative = 0.0;
  for (var i = 0; i < items.length; i++) {
    cumulative += weights[i];
    if (target < cumulative) return items[i];
  }
  return items.last; // floating-point rounding safety net
}

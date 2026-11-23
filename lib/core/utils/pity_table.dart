import 'dart:math';

import 'seeded_random.dart';

/// A weighted loot table with a hard "pity" guarantee (FEAT-219): after
/// [pityAfter] consecutive pulls that miss every item in [pityItems], the
/// next pull is forced to be a pity item (picked by the original weights among
/// the pity items only).
///
/// A probability tool for game design, not legal advice: loot-box odds
/// disclosure and age rules differ by region, and this class has no purchase
/// or UI. Pass a [Random] (a [SeededRandom] reproduces a run, and its
/// `snapshot()` plus [toJson] resumes one exactly). Pure Dart, no Flutter.
///
/// Hard threshold only: the odds do not creep up before [pityAfter] (that is
/// "soft pity", not provided).
class PityTable<T> {
  PityTable({
    required List<T> items,
    required List<double> weights,
    required Set<T> pityItems,
    required this.pityAfter,
  }) : _items = List.unmodifiable(items),
       _weights = List.unmodifiable(weights),
       pityItems = Set.unmodifiable(pityItems) {
    if (pityAfter <= 0) {
      throw ArgumentError.value(pityAfter, 'pityAfter', 'must be > 0');
    }
    if (pityItems.isEmpty) {
      throw ArgumentError.value(pityItems, 'pityItems', 'must not be empty');
    }
    if (items.toSet().length != items.length) {
      throw ArgumentError.value(items, 'items', 'must not contain duplicates');
    }
    for (final p in pityItems) {
      if (!items.contains(p)) {
        throw ArgumentError.value(p, 'pityItems', 'is not in items');
      }
    }
    // Validates length, emptiness and every weight (finite, >= 0, sum > 0).
    _normal = CompiledWeightedTable<T>(items, weights);
    final pi = <T>[];
    final pw = <double>[];
    for (var i = 0; i < items.length; i++) {
      if (pityItems.contains(items[i])) {
        pi.add(items[i]);
        pw.add(weights[i]);
      }
    }
    final pityTotal = pw.fold<double>(0, (a, b) => a + b);
    if (pityTotal <= 0) {
      throw ArgumentError.value(
        pityItems,
        'pityItems',
        'must have a total weight > 0',
      );
    }
    _pity = CompiledWeightedTable<T>(pi, pw);
  }

  final List<T> _items;
  final List<double> _weights;

  /// The items that satisfy the guarantee (and reset the miss counter).
  final Set<T> pityItems;

  /// Consecutive misses after which the next pull is forced.
  final int pityAfter;

  late final CompiledWeightedTable<T> _normal;
  late final CompiledWeightedTable<T> _pity;

  int _misses = 0;

  /// Consecutive pulls so far that were not a pity item. Always
  /// `0 <= misses < pityAfter`.
  int get misses => _misses;

  /// Pulls one item. Never returns more than [pityAfter] - 1 consecutive
  /// non-pity items.
  T pull(Random random) {
    final T result;
    if (_misses >= pityAfter - 1) {
      result = _pity.pick(random);
    } else {
      result = _normal.pick(random);
    }
    _misses = pityItems.contains(result) ? 0 : _misses + 1;
    return result;
  }

  /// Persistable state (only the miss counter; the table itself is code).
  Map<String, Object?> toJson() => {'misses': _misses};

  /// Restores the counter from [json], tolerating anything: a missing,
  /// non-integer or negative value becomes 0 and a too-large one is clamped to
  /// `pityAfter - 1`, so a corrupt save can never break the guarantee.
  void restore(Map<String, Object?> json) {
    final raw = json['misses'];
    final m = raw is int ? raw : 0;
    _misses = m < 0 ? 0 : (m >= pityAfter ? pityAfter - 1 : m);
  }

  /// The items, for display (unmodifiable).
  List<T> get items => _items;

  /// The weights in the same order as [items] (unmodifiable).
  List<double> get weights => _weights;
}

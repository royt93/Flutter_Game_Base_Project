import 'dart:math';

import 'fnv1a.dart';
import 'weighted_random_pick.dart';

/// Opaque, versioned snapshot of a [SeededRandom]'s internal state —
/// serializable so a caller (e.g. a save file, or IDEA-42's replay capsule)
/// can persist an RNG stream and later resume it at the exact point it left
/// off, via [SeededRandom.fromSnapshot].
class RandomSnapshot {
  const RandomSnapshot({required this.algorithmVersion, required this.state});

  final int algorithmVersion;
  final int state;

  Map<String, Object?> toJson() => {
    'algorithmVersion': algorithmVersion,
    'state': state,
  };

  /// Throws [FormatException] for a missing/wrong-typed field — same
  /// "untrusted input, fail loud rather than silently produce a bogus RNG
  /// stream" posture as the rest of this package's persisted state.
  static RandomSnapshot fromJson(Map<String, Object?> json) {
    final algorithmVersion = json['algorithmVersion'];
    final state = json['state'];
    if (algorithmVersion is! int || state is! int) {
      throw const FormatException(
        'RandomSnapshot.fromJson: algorithmVersion and state must both be int',
      );
    }
    return RandomSnapshot(algorithmVersion: algorithmVersion, state: state);
  }
}

const int _mask32 = 0xFFFFFFFF;

/// Deterministic, cross-platform-stable pseudo-random generator —
/// implements [Random] so it's a drop-in source for [weightedRandomPick],
/// `List.shuffle`, or anywhere else a `dart:math` `Random` is accepted.
///
/// Unlike `Random(seed)`, this:
/// - Exposes its internal state via [snapshot]/[SeededRandom.fromSnapshot]
///   so a caller can persist and later resume a sequence exactly — plain
///   `dart:math` `Random` has no such API at all.
/// - Uses hand-rolled 32-bit-safe integer arithmetic (a mulberry32 variant)
///   instead of relying on native 64-bit int overflow, so the SAME seed +
///   call sequence produces the SAME output on every Dart compile target
///   (the Dart VM, where `int` is a real 64-bit integer, AND a JS web
///   build, where numbers above 2^53 silently lose precision — a naive
///   64-bit generator would drift between the two).
class SeededRandom implements Random {
  factory SeededRandom(int seed) => SeededRandom._(seed & _mask32);

  SeededRandom._(this._state);

  /// Bumped only if the generator algorithm itself ever changes — lets
  /// [fromSnapshot] reject a snapshot produced by an incompatible version
  /// instead of silently producing a different (wrong) sequence from it.
  static const int algorithmVersion = 1;

  int _state;

  factory SeededRandom.fromSnapshot(RandomSnapshot snapshot) {
    if (snapshot.algorithmVersion != algorithmVersion) {
      throw ArgumentError.value(
        snapshot.algorithmVersion,
        'snapshot.algorithmVersion',
        'unsupported SeededRandom algorithm version '
            '(this build supports $algorithmVersion)',
      );
    }
    return SeededRandom._(snapshot.state & _mask32);
  }

  RandomSnapshot snapshot() =>
      RandomSnapshot(algorithmVersion: algorithmVersion, state: _state);

  /// 32-bit-truncated multiply — mirrors JavaScript's `Math.imul` by
  /// splitting both operands into 16-bit halves so no intermediate product
  /// ever exceeds 2^32 (well inside the 2^53 safe-integer range every Dart
  /// compile target, including web, guarantees). A plain `a * b` here would
  /// silently lose precision on a web build once the product exceeds 2^53.
  static int _imul32(int a, int b) {
    a &= _mask32;
    b &= _mask32;
    final aLo = a & 0xFFFF;
    final aHi = a >>> 16;
    final bLo = b & 0xFFFF;
    final bHi = b >>> 16;
    final low = aLo * bLo;
    final mid = (aHi * bLo + aLo * bHi) & 0xFFFF;
    return (low + (mid << 16)) & _mask32;
  }

  int _nextRaw32() {
    _state = (_state + 0x6D2B79F5) & _mask32;
    var t = _state;
    t = _imul32(t ^ (t >>> 15), t | 1);
    t = (_imul32(t ^ (t >>> 7), t | 61) ^ t) & _mask32;
    return (t ^ (t >>> 14)) & _mask32;
  }

  /// [max] must be in `1..0x100000000` (a single 32-bit draw's full range) —
  /// this generator doesn't support a wider range in one call.
  @override
  int nextInt(int max) {
    if (max <= 0 || max > _mask32 + 1) {
      throw RangeError.range(max, 1, _mask32 + 1, 'max');
    }
    return _nextRaw32() % max;
  }

  @override
  double nextDouble() => _nextRaw32() / 4294967296.0;

  @override
  bool nextBool() => (_nextRaw32() & 1) == 1;

  /// Shuffles [items] in place — a thin, discoverable wrapper over the
  /// built-in `List.shuffle(Random)`, since `SeededRandom` already
  /// implements [Random].
  void shuffle<T>(List<T> items) => items.shuffle(this);

  /// Weighted pick, bridging straight to the existing [weightedRandomPick]
  /// — same validation/selection algorithm, sourced from this deterministic
  /// generator instead of `dart:math`'s own `Random`. Invalid input (empty
  /// list, mismatched lengths, a bad weight) throws before this generator's
  /// state is touched, same as [weightedRandomPick] itself.
  T pick<T>(List<T> items, List<double> weights) =>
      weightedRandomPick(items, weights, random: this);
}

/// Pre-validates a weighted loot table ONCE at construction — compiling it
/// into cumulative weights so repeated [pick] calls (e.g. every enemy
/// spawn, every loot roll) don't re-validate and re-sum the whole table
/// every time the way a bare [weightedRandomPick] call does.
class CompiledWeightedTable<T> {
  factory CompiledWeightedTable(List<T> items, List<double> weights) {
    if (items.length != weights.length) {
      throw ArgumentError(
        'CompiledWeightedTable: items (${items.length}) and weights '
        '(${weights.length}) must be the same length',
      );
    }
    if (items.isEmpty) {
      throw ArgumentError('CompiledWeightedTable: items must not be empty');
    }
    final cumulative = <double>[];
    var running = 0.0;
    for (final w in weights) {
      if (!w.isFinite || w < 0) {
        throw ArgumentError(
          'CompiledWeightedTable: every weight must be finite and >= 0, '
          'got $w',
        );
      }
      running += w;
      cumulative.add(running);
    }
    if (!running.isFinite || running <= 0) {
      throw ArgumentError(
        'CompiledWeightedTable: weights must sum to a finite value > 0, '
        'got $running',
      );
    }
    return CompiledWeightedTable._(
      List.unmodifiable(items),
      List.unmodifiable(cumulative),
    );
  }

  CompiledWeightedTable._(this._items, this._cumulative);

  final List<T> _items;
  final List<double> _cumulative;

  /// Picks 1 item, probability proportional to its compiled weight. No
  /// re-validation — that already happened once, at construction.
  T pick(Random random) {
    final target = random.nextDouble() * _cumulative.last;
    for (var i = 0; i < _items.length; i++) {
      if (target < _cumulative[i]) return _items[i];
    }
    return _items.last; // floating-point rounding safety net
  }
}

/// Manages independent, deterministically-derived [SeededRandom] streams
/// keyed by a caller-chosen namespace (e.g. `"loot"`, `"enemy_spawn"`) —
/// so one gameplay system calling its own stream an extra time never
/// shifts another system's sequence, the classic shared-RNG
/// replay-determinism trap.
///
/// Not a `GetxService`/singleton — a caller (e.g. one game session) owns
/// its own instance, seeded explicitly with the seed that session's replay
/// capsule needs to reproduce (same "caller supplies and owns state, this
/// class only computes" convention as [VersionedJsonStore]).
class SeededRandomService {
  SeededRandomService(this.rootSeed);

  final int rootSeed;
  final Map<String, SeededRandom> _streams = {};

  /// Gets (creating on first call) the deterministic stream for
  /// [namespace]. The same [namespace] on the same [rootSeed] always
  /// starts from the same derived seed, and repeated calls for the same
  /// namespace return the SAME instance (its sequence keeps advancing
  /// across calls, it isn't reset).
  SeededRandom stream(String namespace) => _streams.putIfAbsent(
    namespace,
    () => SeededRandom(fnv1aHash('$rootSeed:$namespace')),
  );

  /// Snapshots every namespace stream created so far (via [stream]), keyed
  /// by namespace. Pass to [restoreSnapshots] to resume every one of them
  /// at its exact point.
  Map<String, RandomSnapshot> snapshotAll() => {
    for (final entry in _streams.entries) entry.key: entry.value.snapshot(),
  };

  /// Restores every namespace in [snapshots] to its saved state —
  /// overwriting that namespace's current stream (or creating it fresh at
  /// that state, if it was never touched on this instance).
  void restoreSnapshots(Map<String, RandomSnapshot> snapshots) {
    for (final entry in snapshots.entries) {
      _streams[entry.key] = SeededRandom.fromSnapshot(entry.value);
    }
  }
}

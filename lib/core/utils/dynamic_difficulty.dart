import 'safe_json.dart';

/// A small difficulty balancer driven by the player's recent win/loss results
/// (FEAT-237): it nudges a difficulty number up when they win a lot and down
/// when they lose a lot, so casual players are not stuck or bored.
///
/// After each [record], once [window] results exist, the win rate over the
/// newest [window] results is compared with [targetWinRate]: above
/// `target + deadband` the value rises by [step], below `target - deadband` it
/// falls by [step], otherwise it stays (the [deadband] stops win/loss
/// alternation from jittering the value). The value is always clamped to
/// `[min, max]`; map it to levels, speeds or spawn rates in your game.
///
/// A balancing tool for game feel. It has no link to purchases or the wallet
/// and must not be used to push spending. Deterministic (no randomness) and
/// pure Dart.
class DynamicDifficulty {
  DynamicDifficulty({
    required this.min,
    required this.max,
    required double start,
    required this.step,
    required this.window,
    this.deadband = 0.1,
    this.targetWinRate = 0.5,
  }) : _value = start {
    for (final entry in {
      'min': min,
      'max': max,
      'start': start,
      'step': step,
      'deadband': deadband,
      'targetWinRate': targetWinRate,
    }.entries) {
      if (!entry.value.isFinite) {
        throw ArgumentError.value(entry.value, entry.key, 'must be finite');
      }
    }
    if (min > max) {
      throw ArgumentError.value(min, 'min', 'must be <= max ($max)');
    }
    if (start < min || start > max) {
      throw ArgumentError.value(start, 'start', 'must be in [$min, $max]');
    }
    if (step <= 0) {
      throw ArgumentError.value(step, 'step', 'must be > 0');
    }
    if (window <= 0) {
      throw ArgumentError.value(window, 'window', 'must be > 0');
    }
    if (deadband < 0) {
      throw ArgumentError.value(deadband, 'deadband', 'must be >= 0');
    }
    if (targetWinRate <= 0 || targetWinRate >= 1) {
      throw ArgumentError.value(
        targetWinRate,
        'targetWinRate',
        'must be in (0, 1)',
      );
    }
    _start = start;
  }

  final double min;
  final double max;

  /// How much one adjustment changes the value.
  final double step;

  /// How many of the newest results the win rate is computed over.
  final int window;

  /// Half-width of the no-change band around [targetWinRate].
  final double deadband;

  /// The win rate the balancer steers toward, in (0, 1).
  final double targetWinRate;

  late final double _start;
  double _value;
  final List<bool> _recent = [];

  /// The current difficulty, always in `[min, max]`.
  double get value => _value;

  /// Records one result and adjusts the value if the window is full.
  void record({required bool won}) {
    _recent.add(won);
    if (_recent.length > window) _recent.removeAt(0);
    if (_recent.length < window) return;
    final wins = _recent.where((w) => w).length;
    // Compare WIN COUNTS, not rates: `0.7 + 0.1` is `0.7999...` in floating
    // point, so a rate of exactly 0.8 would wrongly count as above the band.
    // The epsilon is far smaller than 1 / window can ever be, so it only
    // absorbs that rounding at the edges.
    const eps = 1e-9;
    final upperWins = (targetWinRate + deadband) * window;
    final lowerWins = (targetWinRate - deadband) * window;
    if (wins > upperWins + eps) {
      _value += step;
    } else if (wins < lowerWins - eps) {
      _value -= step;
    }
    _value = _value.clamp(min, max).toDouble();
  }

  /// Persistable state: the value and the newest results.
  Map<String, Object?> toJson() => {
    'value': _value,
    'recent': List<bool>.of(_recent),
  };

  /// Restores from [json], tolerating anything: a missing or non-finite value
  /// becomes the start value, an out-of-range value is clamped, results of the
  /// wrong type are dropped and only the newest [window] kept.
  void restore(Map<String, Object?> json) {
    final v = asDoubleOr(json['value'], _start);
    _value = (v.isFinite ? v : _start).clamp(min, max).toDouble();
    _recent.clear();
    final raw = json['recent'];
    if (raw is List) {
      for (final r in raw) {
        if (r is bool) _recent.add(r);
      }
      while (_recent.length > window) {
        _recent.removeAt(0);
      }
    }
  }
}

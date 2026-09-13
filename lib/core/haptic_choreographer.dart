import 'dart:async';

import 'haptics.dart';

/// One step of a [HapticPattern]: fire [level], then wait [delayAfter]
/// before the next pulse (ignored on the pattern's last pulse).
class HapticPulse {
  const HapticPulse({required this.level, this.delayAfter = Duration.zero});

  final HapticLevel level;
  final Duration delayAfter;
}

/// A small, caller-declarable haptic sequence — "1 buzz then a pause then
/// 2 buzzes" instead of a consumer wiring up individual [fireHaptic] calls
/// by hand for every combo/reward/error moment.
///
/// Bounded on purpose (IDEA-41 MVP slice 1: "pulse/delay có giới hạn an
/// toàn") — an unbounded pattern (hundreds of pulses, or a multi-minute
/// total run time) would turn a game-feel touch into an annoying,
/// battery-draining buzz marathon, so both dimensions are capped and
/// validated eagerly at construction rather than left to accumulate at
/// playback time.
class HapticPattern {
  HapticPattern(this.pulses) {
    if (pulses.isEmpty) {
      throw ArgumentError.value(pulses, 'pulses', 'must not be empty');
    }
    if (pulses.length > maxPulses) {
      throw ArgumentError.value(
        pulses,
        'pulses',
        'must not exceed $maxPulses pulses',
      );
    }
    for (final pulse in pulses) {
      if (pulse.delayAfter.isNegative) {
        throw ArgumentError.value(
          pulse.delayAfter,
          'delayAfter',
          'must not be negative',
        );
      }
      if (pulse.delayAfter > maxDelayPerPulse) {
        throw ArgumentError.value(
          pulse.delayAfter,
          'delayAfter',
          'must not exceed $maxDelayPerPulse',
        );
      }
    }
    final total = pulses.fold<Duration>(
      Duration.zero,
      (sum, pulse) => sum + pulse.delayAfter,
    );
    if (total > maxTotalDuration) {
      throw ArgumentError.value(
        total,
        'pulses',
        'total delay must not exceed $maxTotalDuration',
      );
    }
  }

  /// Max pulses a single pattern may contain.
  static const maxPulses = 16;

  /// Max delay any single pulse may schedule before the next one.
  static const maxDelayPerPulse = Duration(seconds: 2);

  /// Max total run time (sum of every [HapticPulse.delayAfter]) a pattern
  /// may schedule.
  static const maxTotalDuration = Duration(seconds: 5);

  final List<HapticPulse> pulses;

  /// A short, escalating "this was great" build-up — light, then medium,
  /// then heavy, each a beat apart.
  static final reward = HapticPattern([
    const HapticPulse(
      level: HapticLevel.light,
      delayAfter: Duration(milliseconds: 80),
    ),
    const HapticPulse(
      level: HapticLevel.medium,
      delayAfter: Duration(milliseconds: 80),
    ),
    const HapticPulse(level: HapticLevel.heavy),
  ]);

  /// A quick double-tap feel for a chained combo continuing.
  static final combo = HapticPattern([
    const HapticPulse(
      level: HapticLevel.light,
      delayAfter: Duration(milliseconds: 60),
    ),
    const HapticPulse(level: HapticLevel.medium),
  ]);

  /// A firm double-buzz "something went wrong" cue, with a distinct pause
  /// between the 2 pulses so it doesn't read as a single longer buzz.
  static final error = HapticPattern([
    const HapticPulse(
      level: HapticLevel.heavy,
      delayAfter: Duration(milliseconds: 150),
    ),
    const HapticPulse(level: HapticLevel.heavy),
  ]);
}

/// Schedules and plays back a [HapticPattern] pulse by pulse, through
/// [fireHaptic] (so every existing `hapticsEnabled`/`hapticSoftMode`
/// contract already applies to every pulse, for free — this never calls
/// `HapticFeedback.*` directly).
///
/// [play]ing a new pattern always cancels whatever pattern is still
/// running first — never stacks multiple patterns' pulses on top of each
/// other, which is what actually rate-limits a "rage tap" spamming
/// [play]: at most 1 pattern's pulses are ever in flight, no matter how
/// often [play] is called.
class HapticChoreographer {
  HapticChoreographer({
    void Function(HapticLevel level)? fire,
    Timer Function(Duration delay, void Function() callback)? createTimer,
  }) : _fire = fire ?? fireHaptic,
       _createTimer = createTimer ?? Timer.new;

  final void Function(HapticLevel level) _fire;
  final Timer Function(Duration delay, void Function() callback) _createTimer;

  Timer? _timer;
  // Bumped by every play()/cancel() — a scheduled callback checks it's
  // still the current generation before firing, so a callback already
  // queued when play()/cancel() happens can never fire late and stomp on
  // whatever started after it (no lifecycle leak past cancel()/dispose()).
  int _generation = 0;

  /// Plays [pattern] from its first pulse, cancelling any pattern still
  /// in progress.
  void play(HapticPattern pattern) {
    cancel();
    _runFrom(pattern, 0, _generation);
  }

  void _runFrom(HapticPattern pattern, int index, int generation) {
    if (generation != _generation) return;
    _fire(pattern.pulses[index].level);
    final next = index + 1;
    if (next >= pattern.pulses.length) return;
    _timer = _createTimer(
      pattern.pulses[index].delayAfter,
      () => _runFrom(pattern, next, generation),
    );
  }

  /// Stops whatever pattern is currently playing (a no-op if none is).
  /// Safe to call from `dispose()` — leaves no pending timer behind.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _generation++;
  }
}

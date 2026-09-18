import 'package:get/get.dart';

import 'game_session_controller.dart';
import 'utils/sdk_result.dart';

/// Pure gameplay clock: no dependency on Flutter/Flame bindings, wall clock,
/// or any timer — every advance is driven by a caller-supplied delta, so the
/// exact same sequence of [advance] calls always produces the exact same
/// [elapsed]/step count (see `PerformanceTierService`'s `FrameBudgetTracker`
/// for the same "pure core, thin binding-aware wrapper" split this mirrors).
///
/// [paused] freezes [elapsed] — a call to [advance] while paused is a no-op,
/// so time spent backgrounded/paused is never counted, and resuming never
/// needs to "catch up" or subtract anything.
class GameClock {
  GameClock({
    this.maxDeltaPerTick = const Duration(milliseconds: 250),
    Duration? fixedStep,
  }) : _fixedStep = fixedStep;

  /// Caps a single [advance] call's delta — without this, a real delta
  /// spanning an app backgrounded for minutes/hours would jump [elapsed] by
  /// that same huge amount in one step.
  final Duration maxDeltaPerTick;
  final Duration? _fixedStep;

  Duration _elapsed = Duration.zero;
  Duration _accumulator = Duration.zero;
  double _scale = 1;
  bool paused = false;

  Duration get elapsed => _elapsed;
  double get scale => _scale;

  /// Rejects a non-finite or non-positive [value] and leaves [scale]
  /// unchanged — an invalid scale must never "poison" the clock (e.g. NaN
  /// propagating into every future [elapsed]).
  SdkResult<double> setScale(double value) {
    if (!value.isFinite || value <= 0) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Time scale must be finite and > 0',
      );
    }
    _scale = value;
    return SdkSuccess(value);
  }

  /// Advances the clock by [realDelta] (clamped to `[0, maxDeltaPerTick]`,
  /// then multiplied by [scale]). A no-op while [paused].
  ///
  /// With no fixed step configured, [elapsed] just advances by the scaled
  /// delta and this always returns 0. With a fixed step, this instead
  /// accumulates the scaled delta and only advances [elapsed] in whole
  /// [Duration] multiples of it — leftover time carries into the next call
  /// — returning how many whole steps were taken this call (0 if not
  /// enough accumulated yet).
  int advance(Duration realDelta) {
    if (paused) return 0;
    final clamped = realDelta < Duration.zero
        ? Duration.zero
        : (realDelta > maxDeltaPerTick ? maxDeltaPerTick : realDelta);
    final scaledMicros = (clamped.inMicroseconds * _scale).round();
    final scaledDelta = Duration(microseconds: scaledMicros);

    final fixedStep = _fixedStep;
    if (fixedStep == null) {
      _elapsed += scaledDelta;
      return 0;
    }
    _accumulator += scaledDelta;
    var steps = 0;
    while (_accumulator >= fixedStep) {
      _accumulator -= fixedStep;
      _elapsed += fixedStep;
      steps++;
    }
    return steps;
  }
}

/// Bridges [GameClock] to Flame's per-frame `update(dt)` loop (via [tick])
/// and to Flutter via [elapsed] ([Rx], safe to read from `Obx` for a
/// countdown/HUD timer) — both sides observe the exact same clock instance,
/// so there's no separate synchronization step for them to drift apart on.
///
/// Pause has exactly ONE owner: when [session] is supplied,
/// [GameSessionController]'s own multi-reason pause state (already
/// deduplicating user/system pause — see `game_session_controller.dart`) is
/// the sole source of truth and [tick] simply no-ops while it reports
/// [GameSessionPhase.paused]; this controller never tracks a second,
/// competing pause flag in that case. Without a [session], [setPaused] is
/// the fallback for a standalone timer that has no game session at all.
class GameTimeController extends GetxService {
  GameTimeController({this.session, Duration? maxDeltaPerTick, Duration? fixedStep})
    : _clock = GameClock(
        maxDeltaPerTick: maxDeltaPerTick ?? const Duration(milliseconds: 250),
        fixedStep: fixedStep,
      );

  final GameSessionController? session;
  final GameClock _clock;
  final elapsed = Duration.zero.obs;

  static GameTimeController? get maybe =>
      Get.isRegistered<GameTimeController>()
      ? Get.find<GameTimeController>()
      : null;

  void setPaused(bool value) {
    if (session != null) return;
    _clock.paused = value;
  }

  SdkResult<double> setScale(double value) => _clock.setScale(value);

  /// Advances by [dtSeconds] (Flame's `Component.update(dt)` convention —
  /// a `double` in seconds) and publishes the new [elapsed].
  int tick(double dtSeconds) {
    final owningSession = session;
    if (owningSession != null) {
      _clock.paused =
          owningSession.snapshot.value.phase == GameSessionPhase.paused;
    }
    final steps = _clock.advance(
      Duration(microseconds: (dtSeconds * Duration.microsecondsPerSecond).round()),
    );
    elapsed.value = _clock.elapsed;
    return steps;
  }
}

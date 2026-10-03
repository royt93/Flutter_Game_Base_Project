import 'package:get/get.dart';

import 'debug_log.dart';
import 'lifecycle_coordinator.dart';
import 'utils/sdk_result.dart';

enum GameSessionPhase { loading, ready, playing, paused, won, lost }

enum GamePauseReason { user, system }

class GameSessionSnapshot {
  const GameSessionSnapshot(this.phase, {this.pauseReasons = const {}});
  final GameSessionPhase phase;
  final Set<GamePauseReason> pauseReasons;
  bool get isTerminal =>
      phase == GameSessionPhase.won || phase == GameSessionPhase.lost;
  GameSessionSnapshot copyWith({
    GameSessionPhase? phase,
    Set<GamePauseReason>? pauseReasons,
  }) => GameSessionSnapshot(
    phase ?? this.phase,
    pauseReasons: Set.unmodifiable(pauseReasons ?? this.pauseReasons),
  );
}

/// Single source of truth for a game's session lifecycle.
class GameSessionController extends GetxController {
  GameSessionController({this.lifecycle}) : hookName = 'game-session' {
    _warnIfLifecycleMissing();
  }

  /// BUG-93 audit fix: use this constructor instead of the default one
  /// when a consumer app builds MORE THAN ONE [GameSessionController]
  /// against the SAME [RoyLifecycleCoordinator] (e.g. 2 different demo
  /// screens' independent sessions) — give each a distinct [hookName].
  /// [RoyLifecycleCoordinator.removeHook] matches by name, not by
  /// instance, so 2 controllers sharing the default 'game-session' name
  /// would have EITHER one's [onClose] silently remove the OTHER's hook
  /// too.
  GameSessionController.withHookName({this.lifecycle, required this.hookName}) {
    if (hookName.isEmpty) {
      throw ArgumentError.value(hookName, 'hookName', 'must not be empty');
    }
    _warnIfLifecycleMissing();
  }

  /// BUG-90: a caller constructing this controller without a real
  /// [RoyLifecycleCoordinator] used to fail completely silently — `onInit`
  /// just skips `lifecycle?.registerHook(...)` via `?.`, with nothing ever
  /// observing it, so "forgot to wire background auto-pause" only showed
  /// up as a tester noticing the session kept running while backgrounded.
  /// This doesn't forbid the null case (some callers, e.g. a one-off
  /// unit-tested session with no real app lifecycle, legitimately don't
  /// need it) — it just makes the omission observable via [dlog] instead
  /// of invisible.
  void _warnIfLifecycleMissing() {
    if (lifecycle == null) {
      dlog(
        'GameSessionController("$hookName"): lifecycle is null — '
        'background/foreground auto-pause/resume will not fire for this '
        'session. Pass a real RoyLifecycleCoordinator if that is not '
        'intentional.',
      );
    }
  }

  final RoyLifecycleCoordinator? lifecycle;

  /// Name this controller registers/removes its lifecycle hook under via
  /// [lifecycle]. See [GameSessionController.withHookName]'s doc for why
  /// this must be unique per [RoyLifecycleCoordinator] a consumer shares
  /// across more than one controller instance.
  final String hookName;

  final snapshot = const GameSessionSnapshot(GameSessionPhase.loading).obs;
  final events = <GameSessionPhase>[].obs;

  /// Gets the instance if already registered (safe to call from
  /// game/widget tests).
  static GameSessionController? get maybe =>
      Get.isRegistered<GameSessionController>()
      ? Get.find<GameSessionController>()
      : null;

  @override
  void onInit() {
    super.onInit();
    lifecycle?.registerHook(hookName, (event) async {
      if (event == RoyLifecycleEvent.background) {
        pause(GamePauseReason.system);
      } else {
        resume(GamePauseReason.system);
      }
    });
  }

  SdkResult<GameSessionSnapshot> markReady() =>
      _transition(GameSessionPhase.ready, from: {GameSessionPhase.loading});
  SdkResult<GameSessionSnapshot> start() =>
      _transition(GameSessionPhase.playing, from: {GameSessionPhase.ready});
  SdkResult<GameSessionSnapshot> win() =>
      _transition(GameSessionPhase.won, from: {GameSessionPhase.playing});
  SdkResult<GameSessionSnapshot> lose() =>
      _transition(GameSessionPhase.lost, from: {GameSessionPhase.playing});

  SdkResult<GameSessionSnapshot> pause(GamePauseReason reason) {
    final current = snapshot.value;
    if (current.isTerminal) return _reject('Terminal session cannot pause');
    if (current.phase != GameSessionPhase.playing &&
        current.phase != GameSessionPhase.paused) {
      return _reject('Session is not playing');
    }
    final reasons = {...current.pauseReasons, reason};
    final wasPaused = current.phase == GameSessionPhase.paused;
    snapshot.value = current.copyWith(
      phase: GameSessionPhase.paused,
      pauseReasons: reasons,
    );
    // BUG-90: record the phase change in `events` (this session's history)
    // — only on the FIRST pause (playing -> paused), not every subsequent
    // overlapping pause reason (e.g. system pausing on top of an already
    // user-paused session), since the phase itself doesn't change again
    // until the session is fully resumed.
    if (!wasPaused) events.add(GameSessionPhase.paused);
    return SdkSuccess(snapshot.value);
  }

  SdkResult<GameSessionSnapshot> resume(GamePauseReason reason) {
    final current = snapshot.value;
    if (current.phase != GameSessionPhase.paused ||
        !current.pauseReasons.contains(reason)) {
      return _reject('Pause reason is not active');
    }
    final reasons = {...current.pauseReasons}..remove(reason);
    final nextPhase = reasons.isEmpty
        ? GameSessionPhase.playing
        : GameSessionPhase.paused;
    snapshot.value = current.copyWith(phase: nextPhase, pauseReasons: reasons);
    // Same reasoning as `pause()` above: only the resume that actually
    // clears every pause reason (phase genuinely returns to playing) is a
    // real transition worth recording — a resume that leaves another
    // reason still active doesn't change the observable phase.
    if (nextPhase == GameSessionPhase.playing) {
      events.add(GameSessionPhase.playing);
    }
    return SdkSuccess(snapshot.value);
  }

  SdkResult<GameSessionSnapshot> restart() {
    snapshot.value = const GameSessionSnapshot(GameSessionPhase.loading);
    // Resets, not appends — `events` is this session's history, and a
    // restart starts a NEW session; keeping every prior session's history
    // here would grow unboundedly across many restarts (e.g. an
    // endless-runner replayed hundreds of times in one long app run).
    events.assignAll([GameSessionPhase.loading]);
    return SdkSuccess(snapshot.value);
  }

  SdkResult<GameSessionSnapshot> _transition(
    GameSessionPhase next, {
    required Set<GameSessionPhase> from,
  }) {
    if (!from.contains(snapshot.value.phase)) {
      return _reject('Invalid transition ${snapshot.value.phase} -> $next');
    }
    snapshot.value = GameSessionSnapshot(next);
    events.add(next);
    return SdkSuccess(snapshot.value);
  }

  SdkFailure<GameSessionSnapshot> _reject(String message) => SdkFailure(
    kind: SdkErrorKind.validation,
    message: message,
    retryable: false,
  );

  @override
  void onClose() {
    lifecycle?.removeHook(hookName);
    super.onClose();
  }
}

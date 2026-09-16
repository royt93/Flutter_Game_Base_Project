import 'package:get/get.dart';

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
  GameSessionController({this.lifecycle});
  final RoyLifecycleCoordinator? lifecycle;
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
    lifecycle?.registerHook('game-session', (event) async {
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
    snapshot.value = current.copyWith(
      phase: GameSessionPhase.paused,
      pauseReasons: reasons,
    );
    return SdkSuccess(snapshot.value);
  }

  SdkResult<GameSessionSnapshot> resume(GamePauseReason reason) {
    final current = snapshot.value;
    if (current.phase != GameSessionPhase.paused ||
        !current.pauseReasons.contains(reason)) {
      return _reject('Pause reason is not active');
    }
    final reasons = {...current.pauseReasons}..remove(reason);
    snapshot.value = current.copyWith(
      phase: reasons.isEmpty
          ? GameSessionPhase.playing
          : GameSessionPhase.paused,
      pauseReasons: reasons,
    );
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
    lifecycle?.removeHook('game-session');
    super.onClose();
  }
}

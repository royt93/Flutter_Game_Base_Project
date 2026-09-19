import 'dart:math' as math;

import 'package:get/get.dart';

import 'consent_state_service.dart';
import 'lifecycle_coordinator.dart';
import 'storage_service.dart';
import 'utils/clamped_clock.dart';

/// Immutable snapshot of the current process's session — a fresh one is
/// created at construction (cold start) and again on any [RoyLifecycleEvent
/// .resumed] that arrives after longer than [AppSessionTracker.sessionTimeout]
/// in the background.
class SessionInfo {
  const SessionInfo({
    required this.sessionId,
    required this.sequence,
    required this.installTimeMs,
  });

  /// Random per-session id — a new one every time a new session starts,
  /// never persisted (not meant to identify the device across sessions;
  /// use `ExperimentBucketingService.anonymousId` for that).
  final String sessionId;

  /// This device's Nth session ever, 1-indexed.
  final int sequence;

  /// First-ever app open, in epoch ms — set once, never changes again.
  final int installTimeMs;
}

/// Session id, install/session counters, and foreground duration — one
/// place every feature reads instead of each hand-rolling its own
/// "first open"/"session count" bookkeeping.
///
/// **One session per process**: [current] is set once at construction
/// (cold start) — [sequence] is persisted and incremented exactly once per
/// construction, satisfying "cold start increments count exactly once"
/// without any extra bookkeeping.
///
/// **Foreground duration uses [Stopwatch]** (real elapsed time), not
/// [nowMsClamped] — a duration measurement doesn't care about wall-clock
/// anomalies, only real elapsed time, and `Stopwatch` gives that directly.
/// Time spent backgrounded is never added to it.
///
/// **Resume policy**: a resume that follows less than [sessionTimeout] of
/// background time continues the *same* session (foreground duration keeps
/// accumulating). A resume after longer than that starts a brand new
/// session (new [SessionInfo.sessionId], [SessionInfo.sequence] bumped,
/// foreground duration reset) — the common "session timeout" convention
/// most mobile analytics SDKs use.
///
/// **Corrupt/negative sequence**: a hand-edited or corrupted persisted
/// sequence that reads negative is clamped to 0 before incrementing —
/// never propagates a negative value forward, and a fresh cold start after
/// corruption always reports at least sequence 1.
///
/// **Consent gate**: [analyticsContext] returns `{}` unless
/// `ConsentCategory.analytics` is granted on the registered
/// [ConsentStateService] (FEAT-61) — this tracker never sends anything
/// itself, but a caller attaching this context to an analytics event must
/// not leak session/install data before consent.
class AppSessionTracker extends GetxService {
  AppSessionTracker({
    this.sessionTimeout = const Duration(minutes: 30),
    RoyLifecycleCoordinator? lifecycle,
    String Function()? generateSessionId,
    Stopwatch Function()? createStopwatch,
  }) : _generateSessionId = generateSessionId ?? _defaultSessionId,
       _createStopwatch = createStopwatch ?? Stopwatch.new {
    _foregroundStopwatch = _createStopwatch();
    _startNewSession();
    final coordinator = lifecycle ?? RoyLifecycleCoordinator.maybe;
    if (coordinator != null) {
      _lifecycle = coordinator;
      coordinator.registerHook(_hookName, (event) async {
        handleLifecycleEvent(event);
      });
    }
  }

  final Duration sessionTimeout;
  final String Function() _generateSessionId;
  final Stopwatch Function() _createStopwatch;
  RoyLifecycleCoordinator? _lifecycle;
  static const _hookName = 'app_session_tracker';

  static AppSessionTracker? get maybe =>
      Get.isRegistered<AppSessionTracker>()
      ? Get.find<AppSessionTracker>()
      : null;

  late SessionInfo _current;
  SessionInfo get current => _current;

  late Stopwatch _foregroundStopwatch;
  Duration _accumulatedForeground = Duration.zero;
  int? _backgroundedAtMs;

  Duration get foregroundDuration =>
      _accumulatedForeground +
      (_foregroundStopwatch.isRunning ? _foregroundStopwatch.elapsed : Duration.zero);

  void _startNewSession() {
    _current = SessionInfo(
      sessionId: _generateSessionId(),
      sequence: _nextSequence(),
      installTimeMs: _readOrInitInstallTime(),
    );
    _accumulatedForeground = Duration.zero;
    _foregroundStopwatch
      ..reset()
      ..start();
  }

  int _readOrInitInstallTime() {
    final existing = StorageService.to.getInt(
      StorageKeys.appSessionInstallTimeMs,
      def: 0,
    );
    if (existing > 0) return existing;
    final now = nowMsClamped();
    StorageService.to.setInt(StorageKeys.appSessionInstallTimeMs, now);
    return now;
  }

  int _nextSequence() {
    final raw = StorageService.to.getInt(
      StorageKeys.appSessionSequence,
      def: 0,
    );
    final safe = raw < 0 ? 0 : raw;
    final next = safe + 1;
    StorageService.to.setInt(StorageKeys.appSessionSequence, next);
    return next;
  }

  /// Called by the registered [RoyLifecycleCoordinator] hook — exposed
  /// publicly (rather than private) so a caller without a coordinator can
  /// drive it directly, and so tests can too without standing up a full
  /// `WidgetsBinding` observer.
  void handleLifecycleEvent(RoyLifecycleEvent event) {
    if (event == RoyLifecycleEvent.background) {
      _accumulatedForeground += _foregroundStopwatch.elapsed;
      _foregroundStopwatch
        ..stop()
        ..reset();
      _backgroundedAtMs = nowMsClamped();
      return;
    }

    final backgroundedAt = _backgroundedAtMs;
    _backgroundedAtMs = null;
    final awayMs = backgroundedAt == null ? 0 : nowMsClamped() - backgroundedAt;
    if (awayMs >= sessionTimeout.inMilliseconds) {
      _startNewSession();
    } else {
      _foregroundStopwatch.start();
    }
  }

  Map<String, Object?> _rawAnalyticsContext() => {
    'sessionId': _current.sessionId,
    'sessionSequence': _current.sequence,
    'installTimeMs': _current.installTimeMs,
    'foregroundDurationMs': foregroundDuration.inMilliseconds,
  };

  /// Session/install/foreground-duration context meant to be attached to
  /// an analytics event — returns `{}` unless analytics consent is
  /// currently granted (no registered `ConsentStateService` counts as not
  /// granted).
  Map<String, Object?> analyticsContext() =>
      (ConsentStateService.maybe?.isGranted(ConsentCategory.analytics) ??
          false)
      ? _rawAnalyticsContext()
      : const {};

  static String _defaultSessionId() {
    final random = math.Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  @override
  void onClose() {
    _lifecycle?.removeHook(_hookName);
    super.onClose();
  }
}

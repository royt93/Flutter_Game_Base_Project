import 'package:get/get.dart';

import 'debug_log.dart';
import 'lifecycle_coordinator.dart';
import 'reproduction_capsule.dart';
import 'utils/sdk_result.dart';

enum GameSessionPhase { loading, ready, playing, paused, won, lost }

enum GamePauseReason { user, system }

String _phaseToJson(GameSessionPhase phase) => phase.name;
GameSessionPhase _phaseFromJson(Object? raw) => GameSessionPhase.values
    .firstWhere((p) => p.name == raw, orElse: () => GameSessionPhase.loading);
String _pauseReasonToJson(GamePauseReason reason) => reason.name;
GamePauseReason? _pauseReasonFromJson(Object? raw) {
  for (final r in GamePauseReason.values) {
    if (r.name == raw) return r;
  }
  return null;
}

/// ENH-96: one recorded phase transition in a [GameSessionController]'s
/// timeline — [offsetMs] is elapsed time since the session's own
/// [Stopwatch] started (see [GameSessionController.withTimeline]'s doc),
/// never a wall-clock timestamp, so a recorded/exported timeline never
/// leaks when (in real-world time) a session was played, only its
/// internal pacing — same anti-fingerprinting posture `ReplayRecorder`
/// already documents for its own offsets.
class GameSessionTimelineEntry {
  const GameSessionTimelineEntry({
    required this.offsetMs,
    required this.phase,
    this.pauseReasons = const {},
    this.metadata = const {},
  });

  final int offsetMs;
  final GameSessionPhase phase;
  final Set<GamePauseReason> pauseReasons;

  /// Already-sanitized (allowlisted + PII-blacklist-filtered) outcome
  /// metadata — see [GameSessionController.winWithMetadata]'s doc for the
  /// filtering rule. Empty for every non-terminal entry.
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => {
    'offsetMs': offsetMs,
    'phase': _phaseToJson(phase),
    'pauseReasons': [for (final r in pauseReasons) _pauseReasonToJson(r)],
    'metadata': metadata,
  };

  static GameSessionTimelineEntry fromJson(Map<String, Object?> json) {
    final rawReasons = json['pauseReasons'];
    final reasons = <GamePauseReason>{};
    if (rawReasons is List) {
      for (final r in rawReasons) {
        final parsed = _pauseReasonFromJson(r);
        if (parsed != null) reasons.add(parsed);
      }
    }
    final rawMetadata = json['metadata'];
    return GameSessionTimelineEntry(
      offsetMs: json['offsetMs'] is int ? json['offsetMs'] as int : 0,
      phase: _phaseFromJson(json['phase']),
      pauseReasons: Set.unmodifiable(reasons),
      metadata: rawMetadata is Map
          ? Map.unmodifiable(rawMetadata.cast<String, Object?>())
          : const {},
    );
  }
}

/// ENH-96: a full, exportable snapshot of one session's recorded
/// [GameSessionTimelineEntry] list — see
/// [GameSessionController.exportTimeline].
class GameSessionTimelineExport {
  const GameSessionTimelineExport({
    required this.schemaVersion,
    required this.durationMs,
    required this.terminalPhase,
    required this.entries,
  });

  final int schemaVersion;
  final int durationMs;
  final GameSessionPhase? terminalPhase;
  final List<GameSessionTimelineEntry> entries;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'durationMs': durationMs,
    'terminalPhase': terminalPhase == null
        ? null
        : _phaseToJson(terminalPhase!),
    'entries': [for (final e in entries) e.toJson()],
  };

  static GameSessionTimelineExport fromJson(Map<String, Object?> json) {
    final rawEntries = json['entries'];
    final terminalRaw = json['terminalPhase'];
    return GameSessionTimelineExport(
      schemaVersion: json['schemaVersion'] is int
          ? json['schemaVersion'] as int
          : 0,
      durationMs: json['durationMs'] is int ? json['durationMs'] as int : 0,
      terminalPhase: terminalRaw == null ? null : _phaseFromJson(terminalRaw),
      entries: rawEntries is List
          ? [
              for (final e in rawEntries)
                if (e is Map)
                  GameSessionTimelineEntry.fromJson(e.cast<String, Object?>()),
            ]
          : const [],
    );
  }
}

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
  static const int _defaultTimelineCapacity = 50;

  GameSessionController({this.lifecycle})
    : hookName = 'game-session',
      timelineCapacity = _defaultTimelineCapacity,
      allowedMetadataKeys = const {},
      _createStopwatch = Stopwatch.new {
    _warnIfLifecycleMissing();
    _initTimeline();
  }

  /// BUG-93 audit fix: use this constructor instead of the default one
  /// when a consumer app builds MORE THAN ONE [GameSessionController]
  /// against the SAME [RoyLifecycleCoordinator] (e.g. 2 different demo
  /// screens' independent sessions) — give each a distinct [hookName].
  /// [RoyLifecycleCoordinator.removeHook] matches by name, not by
  /// instance, so 2 controllers sharing the default 'game-session' name
  /// would have EITHER one's [onClose] silently remove the OTHER's hook
  /// too.
  GameSessionController.withHookName({this.lifecycle, required this.hookName})
    : timelineCapacity = _defaultTimelineCapacity,
      allowedMetadataKeys = const {},
      _createStopwatch = Stopwatch.new {
    if (hookName.isEmpty) {
      throw ArgumentError.value(hookName, 'hookName', 'must not be empty');
    }
    _warnIfLifecycleMissing();
    _initTimeline();
  }

  /// ENH-96: adds a bounded, privacy-sanitized outcome timeline on top of
  /// [events] — a consumer that doesn't need per-run causal history (pause
  /// reasons, win/lose metadata, monotonic offsets) keeps using the default
  /// constructor/[withHookName] unchanged; [events] itself is untouched by
  /// this feature either way (every constructor keeps appending to it
  /// exactly as before).
  ///
  /// [timelineCapacity] must be `> 0` (ENH-85 runtime-validated constructor
  /// invariant — a value sourced from remote config could otherwise sail
  /// through as `0`/negative and corrupt the ring buffer silently).
  /// [allowedMetadataKeys] is a default-DENY allowlist: a key passed to
  /// [winWithMetadata]/[loseWithMetadata] is kept in the recorded/exported
  /// timeline ONLY if it's in this set AND not in
  /// [ReproductionCapsule.defaultRedactedKeys] (the blacklist always wins,
  /// even over an explicit allowlist entry — see that doc). [createStopwatch]
  /// exists purely so tests can inject a fake, deterministic clock; a real
  /// app never needs to pass it.
  GameSessionController.withTimeline({
    this.lifecycle,
    this.hookName = 'game-session',
    this.timelineCapacity = _defaultTimelineCapacity,
    this.allowedMetadataKeys = const {},
    Stopwatch Function()? createStopwatch,
  }) : _createStopwatch = createStopwatch ?? Stopwatch.new {
    if (hookName.isEmpty) {
      throw ArgumentError.value(hookName, 'hookName', 'must not be empty');
    }
    if (timelineCapacity <= 0) {
      throw ArgumentError.value(
        timelineCapacity,
        'timelineCapacity',
        'must be > 0',
      );
    }
    _warnIfLifecycleMissing();
    _initTimeline();
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

  /// ENH-96: max entries [timeline] retains — oldest evicted first once
  /// exceeded. Every constructor sets this (default
  /// [_defaultTimelineCapacity] for the 2 pre-ENH-96 constructors, same as
  /// if a consumer never looks at [timeline] at all).
  final int timelineCapacity;

  /// ENH-96: default-DENY allowlist for [winWithMetadata]/[loseWithMetadata]
  /// — see [GameSessionController.withTimeline]'s doc. Empty by default
  /// (the 2 pre-ENH-96 constructors), meaning [win]/[lose] (which pass no
  /// metadata anyway) and any metadata a caller passes are both recorded
  /// with an empty sanitized map.
  final Set<String> allowedMetadataKeys;

  final Stopwatch Function() _createStopwatch;
  late Stopwatch _stopwatch;
  late int _stopwatchBaseMs;
  final List<GameSessionTimelineEntry> _timeline = [];

  void _initTimeline() {
    _stopwatch = _createStopwatch()..start();
    _stopwatchBaseMs = _stopwatch.elapsedMilliseconds;
    _timeline.clear();
    _appendTimelineEntry(GameSessionPhase.loading);
  }

  int get _currentOffsetMs => _stopwatch.elapsedMilliseconds - _stopwatchBaseMs;

  void _appendTimelineEntry(
    GameSessionPhase phase, {
    Set<GamePauseReason> pauseReasons = const {},
    Map<String, Object?> metadata = const {},
  }) {
    _timeline.add(
      GameSessionTimelineEntry(
        offsetMs: _currentOffsetMs,
        phase: phase,
        pauseReasons: Set.unmodifiable(pauseReasons),
        metadata: Map.unmodifiable(metadata),
      ),
    );
    while (_timeline.length > timelineCapacity) {
      _timeline.removeAt(0);
    }
  }

  /// ENH-96: unlike [events] (which only records a REAL phase change —
  /// `playing` -> `paused` -> `playing` — and stays silent for an
  /// overlapping reason that doesn't move the observable phase), the
  /// timeline appends a NEW `paused` entry for every pause-reason-set
  /// change, even one that leaves the phase at `paused` throughout (a
  /// second reason pausing on top of an already-paused session, or a
  /// resume that still leaves one reason active) — this is the whole point
  /// of the richer timeline over `events`: preserving the exact causal
  /// history of WHICH reasons were active WHEN, not just phase changes.
  void _recordPauseReasons(Set<GamePauseReason> reasons) {
    _appendTimelineEntry(GameSessionPhase.paused, pauseReasons: reasons);
  }

  /// Every entry recorded so far, oldest first, capped at
  /// [timelineCapacity] — see [GameSessionController.withTimeline]'s doc.
  List<GameSessionTimelineEntry> get timeline => List.unmodifiable(_timeline);

  /// A full, privacy-safe snapshot of [timeline] ready to hand to
  /// `DiagnosticsExportBundle`/a support ticket/a log line.
  GameSessionTimelineExport exportTimeline() {
    final current = snapshot.value;
    return GameSessionTimelineExport(
      schemaVersion: 1,
      durationMs: _timeline.isEmpty ? 0 : _timeline.last.offsetMs,
      terminalPhase: current.isTerminal ? current.phase : null,
      entries: List.unmodifiable(_timeline),
    );
  }

  /// Keeps a metadata entry ONLY if its key is explicitly in
  /// [allowedMetadataKeys] (default-DENY — an unlisted key is dropped even
  /// if harmless) AND NOT in
  /// [ReproductionCapsule.defaultRedactedKeys] (the PII blacklist always
  /// wins, even over an explicit allowlist entry — a consumer that
  /// allowlists `userId` by mistake still gets it redacted) AND its value
  /// is a JSON-safe scalar (`num`/`String`/`bool`/`null`) — anything else
  /// (a nested map/list/object) is dropped rather than risk smuggling an
  /// unreviewed nested PII field through.
  Map<String, Object?> _sanitizeMetadata(Map<String, Object?> raw) {
    final out = <String, Object?>{};
    for (final entry in raw.entries) {
      if (!allowedMetadataKeys.contains(entry.key)) continue;
      if (ReproductionCapsule.defaultRedactedKeys.contains(entry.key)) {
        continue;
      }
      final value = entry.value;
      if (value == null || value is num || value is String || value is bool) {
        out[entry.key] = value;
      }
    }
    return out;
  }

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
  SdkResult<GameSessionSnapshot> win() => winWithMetadata(const {});
  SdkResult<GameSessionSnapshot> lose() => loseWithMetadata(const {});

  /// ENH-96: same transition as [win], plus [metadata] recorded on the
  /// terminal [GameSessionTimelineEntry] after sanitization (see
  /// [_sanitizeMetadata]'s doc) — [win] itself just delegates here with an
  /// empty map, so its own behavior/signature is 100% unchanged.
  SdkResult<GameSessionSnapshot> winWithMetadata(
    Map<String, Object?> metadata,
  ) => _transition(
    GameSessionPhase.won,
    from: {GameSessionPhase.playing},
    metadata: metadata,
  );

  /// ENH-96: same transition as [lose], plus [metadata] recorded on the
  /// terminal [GameSessionTimelineEntry] after sanitization.
  SdkResult<GameSessionSnapshot> loseWithMetadata(
    Map<String, Object?> metadata,
  ) => _transition(
    GameSessionPhase.lost,
    from: {GameSessionPhase.playing},
    metadata: metadata,
  );

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
    // ENH-96: the timeline records every pause-reason change (even one
    // that doesn't move the observable phase) — see `_recordPauseReasons`'
    // doc for why this differs from `events`' coarser phase-only history.
    _recordPauseReasons(reasons);
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
      _appendTimelineEntry(GameSessionPhase.playing);
    } else {
      _recordPauseReasons(reasons);
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
    // ENH-96: same reset posture for the timeline — a fresh Stopwatch so
    // offsets restart from 0, not a continuation of the previous run's
    // elapsed time.
    _initTimeline();
    return SdkSuccess(snapshot.value);
  }

  SdkResult<GameSessionSnapshot> _transition(
    GameSessionPhase next, {
    required Set<GameSessionPhase> from,
    Map<String, Object?> metadata = const {},
  }) {
    if (!from.contains(snapshot.value.phase)) {
      return _reject('Invalid transition ${snapshot.value.phase} -> $next');
    }
    snapshot.value = GameSessionSnapshot(next);
    events.add(next);
    _appendTimelineEntry(next, metadata: _sanitizeMetadata(metadata));
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

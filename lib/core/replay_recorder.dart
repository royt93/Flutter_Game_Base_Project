import 'package:get/get.dart';

import 'save_integrity.dart';
import 'utils/seeded_random.dart';

/// 1 recorded input/decision event — [offsetMs] is a monotonic offset from
/// the moment [ReplayRecorder.start] was called (never wall-clock time, so
/// a replay run doesn't need to happen at the same real-world moment).
/// [payload] is entirely caller-defined — this class never inspects or
/// interprets it, same "pure envelope, caller owns the shape" convention as
/// `LeaderboardEntry`/`VictoryCardTemplate.statLines`.
///
/// **Privacy note (FEAT-45/IDEA-42 RFC):** neither this class nor
/// [ReplayRecorder] ever adds a field beyond what's explicitly passed to
/// [ReplayRecorder.record] — no device id, no user id, no platform
/// fingerprint is collected automatically. Whatever PII ends up in
/// [payload] is entirely the calling app's own choice.
class ReplayEvent {
  const ReplayEvent({
    required this.offsetMs,
    required this.type,
    required this.payload,
  });

  final int offsetMs;
  final String type;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => {
    'offsetMs': offsetMs,
    'type': type,
    'payload': payload,
  };

  /// Throws [FormatException] for a missing/wrong-typed field — this is
  /// only ever called from a context that already caught that (see
  /// [ReplayCapsule.fromJsonUnsigned]), so a throw here is expected to be
  /// caught one level up, not surfaced raw to a caller.
  static ReplayEvent fromJson(Map<String, Object?> json) {
    final offsetMs = json['offsetMs'];
    final type = json['type'];
    final payload = json['payload'];
    if (offsetMs is! int || type is! String || payload is! Map) {
      throw const FormatException(
        'ReplayEvent.fromJson: offsetMs (int), type (String) and payload '
        '(Map) are all required',
      );
    }
    return ReplayEvent(
      offsetMs: offsetMs,
      type: type,
      payload: payload.cast<String, Object?>(),
    );
  }
}

/// A versioned, signable envelope capturing everything needed to replay 1
/// recording session: the RNG [seed] (feed straight into
/// `SeededRandom(seed)`/`SeededRandomService(seed)`), the [appVersion] it
/// was captured under, and the ordered [events].
///
/// **Determinism note (RFC):** this class only carries the data — it
/// CANNOT make a caller's own game logic deterministic. Replaying the same
/// capsule only reproduces the same outcome if the game logic reads
/// randomness EXCLUSIVELY through the recorded [seed] (e.g. via
/// `SeededRandom`/`SeededRandomService`, FEAT-45) and reacts to nothing
/// but the recorded [events] in order — any other input (wall-clock reads,
/// network, an unseeded `Random()`, platform-specific float rounding)
/// breaks replay determinism, and no amount of capsule-format cleverness
/// can fix that after the fact.
class ReplayCapsule {
  /// A capsule built directly in memory (e.g. by [ReplayRecorder]) is
  /// always in the CURRENT schema by construction — [schemaVersion] only
  /// varies for a capsule parsed from possibly-older/foreign JSON, which
  /// is why it isn't a constructor parameter here.
  const ReplayCapsule({
    required this.seed,
    required this.appVersion,
    required this.events,
  });

  /// Bumped only if this envelope's own shape changes. Deliberately no
  /// `migrate` hook (unlike `VersionedJsonStore`) — YAGNI until a second
  /// schema version actually exists; [fromJsonUnsigned] just rejects
  /// anything that isn't exactly [schemaVersion] for now.
  static const int schemaVersion = 1;

  final int seed;
  final String appVersion;
  final List<ReplayEvent> events;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'seed': seed,
    'appVersion': appVersion,
    'events': [for (final e in events) e.toJson()],
  };

  /// Safe, non-throwing parse: `null` for a wrong/missing [schemaVersion]
  /// or any missing/wrong-typed field — a corrupt or future-schema capsule
  /// is rejected outright rather than partially trusted, same posture as
  /// `VersionedJsonStore`'s own trust boundary.
  static ReplayCapsule? fromJsonUnsigned(Map<String, Object?> json) {
    final version = json['schemaVersion'];
    if (version != schemaVersion) return null;
    final seed = json['seed'];
    final appVersion = json['appVersion'];
    final rawEvents = json['events'];
    if (seed is! int || appVersion is! String || rawEvents is! List) {
      return null;
    }
    try {
      final events = [
        for (final e in rawEvents)
          ReplayEvent.fromJson((e as Map).cast<String, Object?>()),
      ];
      return ReplayCapsule(seed: seed, appVersion: appVersion, events: events);
    } catch (_) {
      return null;
    }
  }

  /// Signs this capsule's JSON with [secret] (via `save_integrity.dart`'s
  /// `signExport`) — hand the result to [importSigned] on the receiving
  /// end to detect a hand-edited/corrupted capsule before it's trusted.
  Map<String, Object?> exportSigned(String secret) =>
      signExport(toJson(), secret);

  /// Verifies [signedJson] against [secret] and parses it — `null` (never
  /// throws) for a missing/wrong checksum, a tampered field, or any of the
  /// [fromJsonUnsigned] rejection cases.
  static ReplayCapsule? importSigned(
    Map<String, Object?> signedJson,
    String secret,
  ) {
    Map<String, Object?> json;
    try {
      json = verifyAndStrip(signedJson, secret);
    } on FormatException {
      return null;
    }
    return fromJsonUnsigned(json);
  }
}

/// Records gameplay/input events into a bounded ring buffer during a QA
/// session, then packages them (plus the session's RNG seed) into a
/// [ReplayCapsule] a developer can import elsewhere to reproduce a bug
/// that was hard to describe from a screen recording alone.
///
/// Not started by default (see [isRecording]) — [record] is a no-op until
/// [start] is called, so a game can call it unconditionally on every
/// input without an `if (recording)` check at every call site.
///
/// **Performance note:** [record] is O(1) — a fixed-size circular buffer
/// write, no JSON encoding, no I/O — so it's safe on a gameplay hot path.
/// The O(n) work (building the ordered event list) only happens in
/// [buildCapsule], which a caller invokes explicitly (e.g. from a debug
/// panel's "Export" button), never automatically.
class ReplayRecorder extends GetxService {
  ReplayRecorder({this.capacity = 500})
    : assert(capacity > 0, 'capacity must be greater than 0') {
    _buffer = List<ReplayEvent?>.filled(capacity, null);
  }

  final int capacity;
  late final List<ReplayEvent?> _buffer;
  int _writeIndex = 0;
  int _count = 0;
  int? _seed;
  final Stopwatch _stopwatch = Stopwatch();

  /// Gets the instance if already registered (safe to call from
  /// game/widget tests).
  static ReplayRecorder? get maybe =>
      Get.isRegistered<ReplayRecorder>() ? Get.find<ReplayRecorder>() : null;

  // Checks the stopwatch, not just `_seed != null` — `_seed` stays set
  // after `stop()` (so `buildCapsule` still knows which seed to report),
  // but the session itself is no longer actively recording at that point.
  bool get isRecording => _seed != null && _stopwatch.isRunning;

  /// Number of events currently held (`<= capacity`).
  int get eventCount => _count;

  /// Starts (or restarts) a recording session under [seed] — clears
  /// whatever a previous session had recorded.
  void start({required int seed}) {
    _seed = seed;
    _writeIndex = 0;
    _count = 0;
    _buffer.fillRange(0, capacity, null);
    _stopwatch
      ..reset()
      ..start();
  }

  /// Stops the current session (if any). [record] becomes a no-op again
  /// until the next [start]; [buildCapsule] can still be called to export
  /// whatever was captured.
  void stop() => _stopwatch.stop();

  /// Records 1 event with [type]/[payload] at the current offset since
  /// [start]. A no-op (not an error) if [start] was never called or
  /// [stop] already ran — so a caller can wire this into a hot path
  /// unconditionally without checking [isRecording] first.
  void record(String type, Map<String, Object?> payload) {
    if (_seed == null || !_stopwatch.isRunning) return;
    _buffer[_writeIndex] = ReplayEvent(
      offsetMs: _stopwatch.elapsedMilliseconds,
      type: type,
      payload: payload,
    );
    _writeIndex = (_writeIndex + 1) % capacity;
    if (_count < capacity) _count++;
  }

  /// Builds a [ReplayCapsule] from everything currently in the buffer, in
  /// oldest-to-newest order. Never throws for an empty/not-yet-started
  /// recorder — [ReplayCapsule.seed] is just `0` in that case (there's
  /// nothing meaningful to replay regardless).
  ReplayCapsule buildCapsule({required String appVersion}) {
    final events = <ReplayEvent>[];
    if (_count < capacity) {
      for (var i = 0; i < _count; i++) {
        events.add(_buffer[i]!);
      }
    } else {
      // Buffer full and has wrapped: oldest entry sits at _writeIndex.
      for (var i = 0; i < capacity; i++) {
        events.add(_buffer[(_writeIndex + i) % capacity]!);
      }
    }
    return ReplayCapsule(
      seed: _seed ?? 0,
      appVersion: appVersion,
      events: events,
    );
  }
}

/// The first index at which [expected] and [actual] differ — `null` if
/// they're identical throughout. Reported with both values so a caller
/// (e.g. a replay-divergence debug view) has enough context to see
/// exactly where and how a replay diverged from what was originally
/// recorded, per-event or per-checkpoint (whatever unit the caller
/// compares).
class ReplayDivergence {
  const ReplayDivergence({
    required this.index,
    required this.expected,
    required this.actual,
  });

  final int index;
  final Object? expected;
  final Object? actual;
}

/// Compares 2 ordered outcome lists (e.g. a recorded session's outcomes vs
/// a fresh replay's outcomes) and returns the FIRST point they differ —
/// including a length mismatch, treated as the shorter list "missing" the
/// longer one's extra entries starting there.
ReplayDivergence? findFirstDivergence(
  List<Object?> expected,
  List<Object?> actual,
) {
  final shorter = expected.length < actual.length
      ? expected.length
      : actual.length;
  for (var i = 0; i < shorter; i++) {
    if (expected[i] != actual[i]) {
      return ReplayDivergence(
        index: i,
        expected: expected[i],
        actual: actual[i],
      );
    }
  }
  if (expected.length != actual.length) {
    return ReplayDivergence(
      index: shorter,
      expected: shorter < expected.length ? expected[shorter] : null,
      actual: shorter < actual.length ? actual[shorter] : null,
    );
  }
  return null;
}

/// Replays [capsule]'s events through [handler] — invoked once per event
/// with a fresh [SeededRandomService] seeded from the capsule (so the
/// SAME namespace-fork behaviour a live session got, FEAT-45, is exactly
/// what a replay gets too) — and reports the first point the produced
/// outcomes diverge from what was originally recorded, or `null` if the
/// replay reproduced the session exactly.
///
/// [handler] is caller-supplied because replaying is inherently
/// game-specific — this only wires the shared, reusable parts (seed,
/// event ordering, divergence detection); it never touches gameplay logic
/// itself. By convention, a recorded event that wants to be checked on
/// replay carries its recorded outcome in `payload['expectedOutcome']`; an
/// event that omits that key is replayed (its handler still runs, in
/// order, so later events see correct RNG/state) but never counted as a
/// divergence.
ReplayDivergence? replayCapsule(
  ReplayCapsule capsule,
  Object? Function(ReplayEvent event, SeededRandomService rng) handler, {
  SeededRandomService? rng,
}) {
  final effectiveRng = rng ?? SeededRandomService(capsule.seed);
  final expected = <Object?>[];
  final actual = <Object?>[];
  for (final event in capsule.events) {
    final outcome = handler(event, effectiveRng);
    if (event.payload.containsKey('expectedOutcome')) {
      expected.add(event.payload['expectedOutcome']);
      actual.add(outcome);
    }
  }
  return findFirstDivergence(expected, actual);
}

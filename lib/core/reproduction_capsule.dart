import 'dart:convert';

import 'replay_recorder.dart';
import 'save_integrity.dart';
import 'utils/seeded_random.dart';
import 'utils/trusted_clock.dart';

/// Result of [ReproductionCapsule.replay] — 2 independent signals a
/// captured session was reproduced faithfully.
class ReproductionReplayResult {
  const ReproductionReplayResult({required this.divergence, this.rngMismatches});

  /// First point the replay's outcomes diverged from what was recorded —
  /// `null` if every checked event matched (see `replayCapsule`'s doc for
  /// the `expectedOutcome` convention).
  final ReplayDivergence? divergence;

  /// Namespaces whose RNG state after replay didn't match what
  /// [ReproductionCapsule.capture] captured live — `null` if the capsule
  /// carried no `rngSnapshots` section to check against (e.g. dropped to
  /// stay under the size budget), meaning this secondary check simply
  /// didn't run; an empty list means it ran and found no mismatch.
  final List<String>? rngMismatches;

  /// True only if BOTH signals agree the replay reproduced the session
  /// exactly.
  bool get matches => divergence == null && (rngMismatches?.isEmpty ?? true);
}

/// Combines [ReplayRecorder] (recorded input/decision events),
/// [SeededRandomService] (per-namespace RNG state), and
/// [TrustedClockService] (clock-tamper judgement) into 1 redacted, signed
/// artifact serving 2 purposes: (a) support — a dev imports it to
/// reproduce exactly the event sequence that led to a bug; (b) anti-cheat
/// — verify a played session wasn't tampered with, by replaying it and
/// comparing outcomes (and, independently, RNG state) against what was
/// recorded.
///
/// Deliberately a thin glue layer, not a reimplementation: signing reuses
/// `save_integrity.dart`'s `signExport`/`verifyAndStrip` (same convention
/// every other signed artifact in this package already uses — see
/// [ReplayCapsule.exportSigned]/[DiagnosticsExportBundle.sign]), and event
/// replay reuses [replayCapsule]/[findFirstDivergence] unchanged.
class ReproductionCapsule {
  ReproductionCapsule._();

  static const int schemaVersion = 1;

  /// ~50KB — deliberately tighter than [DiagnosticsExportBundle]'s 200KB
  /// default: this is meant to be pasted inline into a support ticket or
  /// an anti-cheat log line, not attached as a file.
  static const int defaultMaxBytes = 50 * 1024;

  /// [ReplayEvent.payload] keys replaced with `'<redacted>'` by default —
  /// same default-deny, opt-in-by-name posture
  /// [DiagnosticsExportBundle.build]'s `configAllowedKeys` already
  /// established, inverted here (a replay payload is free-form game data,
  /// not a fixed config map, so a deny list fits better than an allow
  /// list).
  static const Set<String> defaultRedactedKeys = {
    'email',
    'phone',
    'name',
    'address',
    'deviceId',
    'userId',
    'ip',
    'token',
    'password',
  };

  /// Captures everything needed to reproduce/verify [recorder]'s current
  /// session: its [ReplayCapsule] (redacted per [redactedKeys]), [rng]'s
  /// current per-namespace RNG state, and [trustedClock]'s most recent
  /// [ClockJudgement] (if any) — signed via [secret] so a receiver can
  /// detect tampering before trusting it.
  ///
  /// If the signed JSON exceeds [maxBytes], the RNG snapshot section is
  /// dropped first (least essential — [replay] recomputes the same RNG
  /// state deterministically from the recorded seed regardless; the
  /// snapshot is only an extra cross-check), then the clock section —
  /// `errors`/`truncated` record what was dropped, same posture
  /// [DiagnosticsExportBundle] already uses.
  static Map<String, Object?> capture({
    required ReplayRecorder recorder,
    required SeededRandomService rng,
    required String appVersion,
    required String secret,
    TrustedClockService? trustedClock,
    Set<String> redactedKeys = defaultRedactedKeys,
    int maxBytes = defaultMaxBytes,
  }) {
    final replay = _redact(
      recorder.buildCapsule(appVersion: appVersion),
      redactedKeys,
    );
    final rngSnapshots = {
      for (final entry in rng.snapshotAll().entries)
        entry.key: entry.value.toJson(),
    };
    final clockJudgement = trustedClock?.lastJudgement;
    final errors = <String, String>{};
    var truncated = false;

    Map<String, Object?> build({
      required bool includeRng,
      required bool includeClock,
    }) => {
      'schemaVersion': schemaVersion,
      'appVersion': appVersion,
      'replay': replay.toJson(),
      if (includeRng) 'rngSnapshots': rngSnapshots,
      if (includeClock && clockJudgement != null)
        'clockJudgement': clockJudgement.name,
      'errors': errors,
      'truncated': truncated,
    };

    var body = build(includeRng: true, includeClock: true);
    if (_byteSize(body) > maxBytes) {
      truncated = true;
      errors['rngSnapshots'] = 'dropped: capsule size cap exceeded';
      body = build(includeRng: false, includeClock: true);
    }
    if (_byteSize(body) > maxBytes) {
      errors['clockJudgement'] = 'dropped: capsule size cap exceeded';
      body = build(includeRng: false, includeClock: false);
    }
    if (_byteSize(body) > maxBytes) {
      errors['capsule'] =
          'still exceeds size cap after dropping every optional section';
    }

    return signExport(body, secret);
  }

  /// Verifies [signed] via [secret] (throws [FormatException] on a
  /// missing/tampered checksum or a malformed `replay` section — same
  /// "fail loud on untrusted input" posture [RandomSnapshot.fromJson]/
  /// [ReplayEvent.fromJson] already use), then replays its events through
  /// [handler] and reports how faithfully the replay reproduced the
  /// original session — see [ReproductionReplayResult].
  static ReproductionReplayResult replay(
    Map<String, Object?> signed,
    String secret,
    Object? Function(ReplayEvent event, SeededRandomService rng) handler,
  ) {
    final json = verifyAndStrip(signed, secret);
    final replayJson = json['replay'];
    if (replayJson is! Map) {
      throw const FormatException(
        'ReproductionCapsule.replay: missing or malformed "replay" section',
      );
    }
    final capsule = ReplayCapsule.fromJsonUnsigned(
      replayJson.cast<String, Object?>(),
    );
    if (capsule == null) {
      throw const FormatException(
        'ReproductionCapsule.replay: "replay" section failed to parse',
      );
    }

    final rng = SeededRandomService(capsule.seed);
    final divergence = replayCapsule(capsule, handler, rng: rng);

    List<String>? rngMismatches;
    final rawSnapshots = json['rngSnapshots'];
    if (rawSnapshots is Map) {
      rngMismatches = [];
      final liveSnapshots = rng.snapshotAll();
      for (final entry in rawSnapshots.entries) {
        final namespace = entry.key.toString();
        final captured = RandomSnapshot.fromJson(
          (entry.value as Map).cast<String, Object?>(),
        );
        final live = liveSnapshots[namespace];
        if (live == null ||
            live.state != captured.state ||
            live.algorithmVersion != captured.algorithmVersion) {
          rngMismatches.add(namespace);
        }
      }
    }

    return ReproductionReplayResult(
      divergence: divergence,
      rngMismatches: rngMismatches,
    );
  }

  static ReplayCapsule _redact(ReplayCapsule capsule, Set<String> redactedKeys) {
    if (redactedKeys.isEmpty) return capsule;
    return ReplayCapsule(
      seed: capsule.seed,
      appVersion: capsule.appVersion,
      events: [
        for (final event in capsule.events)
          ReplayEvent(
            offsetMs: event.offsetMs,
            type: event.type,
            payload: {
              for (final entry in event.payload.entries)
                entry.key: redactedKeys.contains(entry.key)
                    ? '<redacted>'
                    : entry.value,
            },
          ),
      ],
    );
  }

  static int _byteSize(Map<String, Object?> body) =>
      utf8.encode(jsonEncode(body)).length;
}

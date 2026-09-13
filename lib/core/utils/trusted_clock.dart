import '../storage_service.dart';

/// A wall-clock reading paired with a monotonic, boot/process-relative
/// reading taken at the same instant — see [TrustedClockService] for why
/// [TrustedClockService.nowMsTrusted] needs both together, not just one.
class ClockSample {
  const ClockSample({required this.wallMs, required this.monotonicMs});

  /// `DateTime.now()`-based reading, in UTC epoch milliseconds — can jump
  /// arbitrarily (user-editable, NTP correction, timezone change).
  final int wallMs;

  /// A reading that only ever increases while THIS process is alive
  /// (e.g. `Stopwatch.elapsedMilliseconds`), and resets to (near) 0 on a
  /// fresh process start. Immune to the user changing the wall clock.
  final int monotonicMs;
}

/// How a new [ClockSample] compares to the previously recorded one.
enum ClockJudgement {
  /// Wall-clock delta roughly matches monotonic delta — ordinary time
  /// passing (including normal drift/NTP correction within tolerance).
  normal,

  /// Wall clock moved backward relative to its own last reading.
  rewind,

  /// Wall clock jumped forward far more than the monotonic reading did
  /// — the device clock was very likely changed by hand (or by a
  /// misbehaving auto-sync) while this process was running.
  suspiciousForwardJump,

  /// The monotonic reading went backward, which only happens when this
  /// is a fresh process (a prior process's monotonic reading, persisted
  /// to storage, is naturally larger than a just-started
  /// `Stopwatch`'s). There is no in-process monotonic baseline to compare
  /// the wall-clock delta against for this transition.
  reboot,
}

/// Pure classifier — no storage, no singletons — comparing [current]
/// against the [previous] recorded sample. Exposed directly (not just
/// through [TrustedClockService]) so a test can drive the full
/// normal/rewind/jump/reboot matrix without touching [StorageService].
ClockJudgement classifyClockSample({
  required ClockSample previous,
  required ClockSample current,
  Duration normalTolerance = const Duration(seconds: 5),
  Duration suspiciousJumpThreshold = const Duration(hours: 1),
}) {
  final monotonicDeltaMs = current.monotonicMs - previous.monotonicMs;
  if (monotonicDeltaMs < 0) {
    return ClockJudgement.reboot;
  }

  final wallDeltaMs = current.wallMs - previous.wallMs;
  if (wallDeltaMs < -normalTolerance.inMilliseconds) {
    return ClockJudgement.rewind;
  }

  final driftMs = wallDeltaMs - monotonicDeltaMs;
  if (driftMs > suspiciousJumpThreshold.inMilliseconds) {
    return ClockJudgement.suspiciousForwardJump;
  }

  return ClockJudgement.normal;
}

/// Optional seam for a caller-supplied trusted time source (e.g. an NTP
/// round-trip, or a server timestamp from any authenticated request the
/// app already makes) — deliberately not implemented by this package (no
/// network dependency baked in, same reasoning as every other seam here:
/// [AnalyticsProvider]/[CrashReporter]/[PurchaseSeam]).
///
/// When present, [TrustedClockService] uses a confirmation from this to
/// immediately re-anchor past a quarantined [ClockJudgement.suspiciousForwardJump]
/// instead of waiting for the real wall clock to naturally catch back up.
abstract class TrustedTimeSource {
  /// Returns a confirmed-trustworthy "now" in UTC epoch milliseconds, or
  /// `null` if no trusted reading is available right now (e.g. offline).
  Future<int?> fetchTrustedNowMs();
}

/// A rewind-proof clock that RECOVERS from a suspicious forward jump
/// instead of permanently locking onto it (IDEA-40) — the failure mode
/// `utils/clamped_clock.dart`'s plain watermark clamp has: once a forward
/// jump (deliberate or an honest clock misconfiguration) bumps the
/// watermark to some far-future instant, every time-gated system it
/// backs stays locked until the REAL wall clock naturally catches up to
/// that instant — which, for a big jump, can be months or years.
///
/// The fix: a [ClockJudgement.suspiciousForwardJump] sample never
/// advances the trusted baseline. Only [ClockJudgement.normal] (and a
/// forward-moving [ClockJudgement.reboot]) samples do. So the worst case
/// after an honest "oops, changed my clock" moment is a short wait for
/// the real clock to pass the baseline again — not a wait for it to pass
/// the bogus jumped value.
///
/// **Deliberately out of scope for this class** (kept as a smaller, safer
/// surface — see IDEA-40's `## Quyết định` for the reasoning): this does
/// NOT replace [StorageKeys.maxMsSeen]-based `nowMsClamped()`, and no
/// existing service in this package has been migrated to call this
/// instead. It's a standalone, fully-tested capability available for a
/// service to adopt.
class TrustedClockService {
  TrustedClockService({
    this.normalTolerance = const Duration(seconds: 5),
    this.suspiciousJumpThreshold = const Duration(hours: 1),
    ClockSample Function()? sampleNow,
    this.trustedTimeSource,
  }) : _sampleNow = sampleNow ?? _defaultSample;

  final Duration normalTolerance;
  final Duration suspiciousJumpThreshold;
  final ClockSample Function() _sampleNow;

  /// Optional — see [TrustedTimeSource].
  final TrustedTimeSource? trustedTimeSource;

  // 1 Stopwatch per process, started on first use — the monotonic
  // reference every ClockSample in this process is measured against.
  // Static (not per-instance) so 2 TrustedClockService instances in the
  // same process (e.g. a real one plus a throwaway in a test) still
  // agree on "how much process time has passed", matching what a real
  // singleton service would see.
  static final Stopwatch _processStopwatch = Stopwatch()..start();

  static ClockSample _defaultSample() => ClockSample(
    wallMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    monotonicMs: _processStopwatch.elapsedMilliseconds,
  );

  ClockJudgement? _lastJudgement;

  /// The most recent [ClockJudgement] [nowMsTrusted] computed — `null`
  /// before the first ever call (nothing to compare against yet).
  /// Exposed for a debug/QA panel to show live, not consumed internally.
  ClockJudgement? get lastJudgement => _lastJudgement;

  /// Trusted "now", in UTC epoch milliseconds. Never goes backward
  /// (rewind-proof, same guarantee `nowMsClamped()` gives), and never
  /// permanently locks onto a suspicious far-future jump (see class doc).
  ///
  /// Migrates from the legacy `StorageKeys.maxMsSeen` watermark on first
  /// ever call (IDEA-40 slice 4) — an install already running the plain
  /// [nowMsClamped]-backed clock keeps its existing rewind-protection
  /// floor instead of restarting from a lower value, which would both
  /// look like a spurious backward jump and could hand back a window an
  /// old exploit already burned.
  int nowMsTrusted() {
    final storage = StorageService.to;
    final sample = _sampleNow();

    final storedBaseline = storage.getInt(
      StorageKeys.trustedClockBaselineMs,
      def: 0,
    );

    // A dedicated existence check — NOT `prevWallMs == 0` — is required
    // here: 0 is a perfectly legitimate wall-clock reading in tests (and,
    // in principle, epoch 0 in production), so treating it as the "never
    // initialized" sentinel would make any real sample that happens to
    // land back on the stored 0 re-run first-call migration instead of
    // being classified normally.
    final hasPrevSample = storage.allKeys().contains(
      StorageKeys.trustedClockPrevWallMs,
    );
    if (!hasPrevSample) {
      // First ever sample for this install — nothing to classify yet.
      // Migrate from the legacy watermark (see doc above) if higher than
      // this fresh wall-clock reading.
      final legacyWatermark = storage.getInt(StorageKeys.maxMsSeen, def: 0);
      final baseline = legacyWatermark > sample.wallMs
          ? legacyWatermark
          : sample.wallMs;
      _persist(sample, baseline);
      return baseline;
    }

    final prevWallMs = storage.getInt(
      StorageKeys.trustedClockPrevWallMs,
      def: 0,
    );
    final prevMonotonicMs = storage.getInt(
      StorageKeys.trustedClockPrevMonotonicMs,
      def: 0,
    );
    final judgement = classifyClockSample(
      previous: ClockSample(wallMs: prevWallMs, monotonicMs: prevMonotonicMs),
      current: sample,
      normalTolerance: normalTolerance,
      suspiciousJumpThreshold: suspiciousJumpThreshold,
    );
    _lastJudgement = judgement;

    switch (judgement) {
      case ClockJudgement.normal:
      case ClockJudgement.reboot:
        // Both a plain forward tick AND a reboot advance the baseline
        // when the new wall reading is ahead of it — a reboot can't be
        // cross-checked against monotonic elapsed time (the whole point
        // of "reboot"), so it degrades to the same rewind-safe-only
        // guarantee `nowMsClamped()` already gives (documented
        // limitation, not a new one: `clamped_clock.dart` is equally
        // unable to catch a kill-app-wind-clock-reopen cycle).
        //
        // The new sample becomes the trusted "previous" going forward —
        // ONLY for a trusted judgement. See the other 2 cases below for
        // why an untrusted sample must never become that reference.
        final newBaseline = sample.wallMs > storedBaseline
            ? sample.wallMs
            : storedBaseline;
        _persist(sample, newBaseline);
        return newBaseline;
      case ClockJudgement.rewind:
      case ClockJudgement.suspiciousForwardJump:
        // Neither the baseline NOR the "previous sample" reference
        // advances here — this is what makes recovery possible (IDEA-40's
        // actual fix). If a quarantined jump's bogus wall reading were
        // persisted as the new "previous", the very next honest sample
        // (wall clock corrected back near reality) would itself look
        // like a huge REWIND relative to that bogus reference and get
        // quarantined too — a self-inflicted permanent lock, exactly the
        // failure mode this class exists to avoid. Keeping the last
        // TRUSTED sample as the comparison point means a corrected clock
        // is compared against reality, not against the bad reading.
        return storedBaseline;
    }
  }

  /// Lets a caller-supplied [TrustedTimeSource] confirm the CURRENT wall
  /// clock reading is legitimate, immediately re-anchoring the baseline
  /// to it even if the most recent [nowMsTrusted] call quarantined it as
  /// a [ClockJudgement.suspiciousForwardJump]. A no-op (never regresses
  /// the baseline) if the confirmed time is behind it, or if
  /// [trustedTimeSource] is unset or returns `null`.
  Future<void> reconcileWithTrustedSource() async {
    final source = trustedTimeSource;
    if (source == null) return;
    final confirmedMs = await source.fetchTrustedNowMs();
    if (confirmedMs == null) return;

    final storage = StorageService.to;
    final storedBaseline = storage.getInt(
      StorageKeys.trustedClockBaselineMs,
      def: 0,
    );
    if (confirmedMs <= storedBaseline) return;
    // Also re-anchors the "previous sample" reference (not just the
    // baseline) to this confirmed point — otherwise the NEXT call would
    // still classify against the stale pre-quarantine reference (frozen
    // by design, see `nowMsTrusted`'s doc) and could re-quarantine a
    // perfectly normal follow-up sample.
    final monotonicNow = _sampleNow().monotonicMs;
    _persist(ClockSample(wallMs: confirmedMs, monotonicMs: monotonicNow), confirmedMs);
  }

  void _persist(ClockSample sample, int baseline) {
    final storage = StorageService.to;
    storage.setInt(StorageKeys.trustedClockPrevWallMs, sample.wallMs);
    storage.setInt(
      StorageKeys.trustedClockPrevMonotonicMs,
      sample.monotonicMs,
    );
    storage.setInt(StorageKeys.trustedClockBaselineMs, baseline);
  }
}

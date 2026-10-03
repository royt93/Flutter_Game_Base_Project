import '../presentation/widgets/common/leaderboard_list.dart';
import 'local_scoreboard_service.dart';
import 'replay_recorder.dart';
import 'utils/clamped_clock.dart';
import 'utils/fnv1a.dart';
import 'utils/seeded_random.dart';

/// How often [SeededChallengeService.currentSeed]'s `periodKey` rolls over —
/// `daily` ties to [todayEpochDayClamped], `weekly` to that same day number
/// floor-divided by 7 (same ISO-ish "group of 7 epoch days" convention
/// `DailyQuestService`/`SeasonEventService`'s own period keys already use
/// elsewhere in this package).
enum ChallengePeriod { daily, weekly }

/// FEAT-97: ties together this kit's existing deterministic-replay
/// primitives — [SeededRandomService] (RNG snapshot/resume),
/// [ReplayRecorder]/[ReplayCapsule] (recorded event replay + divergence
/// detection), and [LocalScoreboardService] (on-device ranking) — into one
/// "same challenge, reproducible run, fully offline" building block, so a
/// consuming game doesn't have to wire all 3 together itself and risk a
/// seed/clock/replay mismatch doing it.
///
/// **Deliberately a thin glue layer, not a reimplementation**: every
/// correctness property (RNG determinism, replay divergence detection,
/// leaderboard ranking, clock-rewind resistance) is inherited unchanged
/// from the primitive that already owns it — this class only derives the
/// shared seed and scopes a [LocalScoreboardService] instance per
/// `(challengeId, periodKey)` pair.
///
/// **No backend/network**: every piece of state here is either derived
/// (the seed) or local-only ([LocalScoreboardService]'s on-device table) —
/// nothing in this class makes a network call or depends on one.
class SeededChallengeService {
  SeededChallengeService({
    required this.challengeId,
    required this.period,
    int scoreboardCapacity = 50,
  }) : _scoreboardCapacity = scoreboardCapacity {
    if (challengeId.trim().isEmpty) {
      throw ArgumentError.value(
        challengeId,
        'challengeId',
        'must not be empty',
      );
    }
    if (scoreboardCapacity <= 0) {
      throw ArgumentError.value(
        scoreboardCapacity,
        'scoreboardCapacity',
        'must be > 0',
      );
    }
  }

  final String challengeId;
  final ChallengePeriod period;
  final int _scoreboardCapacity;

  /// Clock-derived — see [ChallengePeriod]'s doc. Always goes through
  /// [todayEpochDayClamped], so winding the device clock BACK can never
  /// reopen a period that has already advanced past (same anti-cheat
  /// clamp every other time-gated system in this package relies on); it
  /// only ever "loses" real future time, never replays a past one.
  String get periodKey {
    final day = todayEpochDayClamped();
    return switch (period) {
      ChallengePeriod.daily => 'd$day',
      ChallengePeriod.weekly => 'w${day ~/ 7}',
    };
  }

  /// Deterministically derived from `(periodKey, challengeId)` — the SAME
  /// pair always yields the SAME seed, on any instance/process/restart
  /// (FNV-1a is a pure function of its input string, see `utils/fnv1a.dart`
  /// — no process-local state). Changes only when [periodKey] rolls over
  /// to a new period, or when a different [challengeId] is used.
  int get currentSeed => fnv1aHash('$periodKey:$challengeId');

  /// Starts a fresh run for the current period: a [SeededRandomService]
  /// seeded from [currentSeed] for the caller's own gameplay namespaces
  /// (e.g. `rng.stream('gameplay')`), optionally paired with [recorder]
  /// (if given, [ReplayRecorder.start]ed with the same seed) so the run
  /// can later be packaged into a [ReplayCapsule] via [endRun].
  SeededRandomService startRun({ReplayRecorder? recorder}) {
    recorder?.start(seed: currentSeed);
    return SeededRandomService(currentSeed);
  }

  /// Stops [recorder] and packages everything it captured since
  /// [startRun] into a [ReplayCapsule] — hand this to [replay] (locally,
  /// or after exporting it elsewhere) to verify the run reproduces
  /// deterministically.
  ReplayCapsule endRun(ReplayRecorder recorder, {String appVersion = '1'}) {
    recorder.stop();
    return recorder.buildCapsule(appVersion: appVersion);
  }

  /// Replays [capsule] through [handler] (same contract as the free
  /// function [replayCapsule]) and reports whether the replay reproduced
  /// the original run's outcomes exactly — see [ReplayDivergence] for what
  /// counts as a mismatch and why `handler` must read randomness only
  /// through the [SeededRandomService] it's given.
  SeededChallengeReplayResult replay(
    ReplayCapsule capsule,
    Object? Function(ReplayEvent event, SeededRandomService rng) handler,
  ) {
    final divergence = replayCapsule(capsule, handler);
    return SeededChallengeReplayResult(divergence: divergence);
  }

  /// The [LocalScoreboardService] for THIS challenge's CURRENT period —
  /// scoped under a storage key combining [challengeId] and [periodKey], so
  /// a new period starts a fresh table automatically (BUG-95-style
  /// freshness: a caller never has to manually clear the old period's
  /// board) and 2 different challenges never share rows.
  LocalScoreboardService get _scoreboard => LocalScoreboardService(
    capacity: _scoreboardCapacity,
    storageKey: 'seeded_challenge_v1_${challengeId}_$periodKey',
  );

  /// Submits [score] for [playerLabel] into this challenge's current-period
  /// local scoreboard. See [LocalScoreboardService.submitScore].
  void submitScore(String playerLabel, int score) =>
      _scoreboard.submitScore(playerLabel, score);

  /// This challenge's current-period top [n] scores. See
  /// [LocalScoreboardService.topN].
  List<LeaderboardEntry> topScores(int n) => _scoreboard.topN(n);
}

/// Outcome of [SeededChallengeService.replay] — `null` [divergence] means
/// the replay reproduced every checked outcome exactly.
class SeededChallengeReplayResult {
  const SeededChallengeReplayResult({required this.divergence});

  final ReplayDivergence? divergence;

  bool get matches => divergence == null;
}

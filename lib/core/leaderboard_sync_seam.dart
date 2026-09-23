import 'package:get/get.dart';

import 'local_scoreboard_service.dart';

/// One row of a synced leaderboard — the seam's own data shape, deliberately
/// simpler than the widget-facing `LeaderboardEntry`
/// (`presentation/widgets/common/leaderboard_list.dart`): a raw `int` score
/// instead of a locale-formatted display string, since a sync adapter
/// round-trips raw numbers with a real backend.
class ScoreEntry {
  const ScoreEntry({
    required this.playerLabel,
    required this.score,
    this.rank,
  });

  final String playerLabel;
  final int score;

  /// 1-based rank, when the source (seam or local fallback) can supply one.
  /// Null if not applicable/known.
  final int? rank;
}

/// Platform-neutral leaderboard-sync seam — mirrors [PurchaseSeam]/
/// [CloudSaveProvider]'s design: the package pulls in no leaderboard SDK (no
/// Play Games Services, no Game Center, no custom backend client); a
/// consuming app registers its own adapter via
/// `Get.put<LeaderboardSyncSeam>(myAdapter, permanent: true)`.
///
/// [LocalScoreboardService] keeps working fully standalone with no seam
/// registered — this interface, and [LeaderboardSyncCoordinator] below, are
/// purely additive, never a replacement.
abstract class LeaderboardSyncSeam {
  /// Submits [score] to the backend's [boardId] leaderboard, for whichever
  /// player is currently signed in to the adapter's own SDK (Play Games
  /// Services/Game Center identify the player themselves — no player-id
  /// param here).
  Future<void> submitScore(String boardId, int score);

  /// The top [limit] scores on [boardId], highest first.
  Future<List<ScoreEntry>> fetchTop(String boardId, {int limit = 10});

  /// Up to [radius] rows above and below the current signed-in player's own
  /// rank on [boardId].
  Future<List<ScoreEntry>> fetchAroundPlayer(String boardId, {int radius = 2});

  /// Null-safe accessor for call sites that may run before/without a seam
  /// registered (mirrors [PurchaseSeam.maybe]).
  static LeaderboardSyncSeam? get maybe =>
      Get.isRegistered<LeaderboardSyncSeam>()
      ? Get.find<LeaderboardSyncSeam>()
      : null;
}

/// Optional orchestrator wiring [LocalScoreboardService] (always-on, local
/// cache) together with a [LeaderboardSyncSeam] (a real backend, when
/// registered). Neither service has to be used directly — this exists for
/// the common case of "submit to both, read from the backend but never go
/// blank when it's unreachable".
///
/// - [submitScore] writes to [local] immediately (synchronous, always
///   succeeds), then best-effort forwards to the seam — a seam failure
///   never loses the local copy.
/// - [fetchTop]/[fetchAroundPlayer] try the seam first (when registered)
///   and fall back to [local]'s cached rows on any failure (offline,
///   timeout, backend error) or when no seam is registered at all.
class LeaderboardSyncCoordinator {
  LeaderboardSyncCoordinator({required this.local, LeaderboardSyncSeam? seam})
    : _seam = seam;

  final LocalScoreboardService local;
  final LeaderboardSyncSeam? _seam;

  LeaderboardSyncSeam? get _resolvedSeam => _seam ?? LeaderboardSyncSeam.maybe;

  /// Writes to [local] first (always succeeds), then best-effort forwards
  /// to the seam if one is registered — a seam error is swallowed since
  /// [local] already has the authoritative copy.
  Future<void> submitScore(
    String boardId,
    String playerLabel,
    int score,
  ) async {
    local.submitScore(playerLabel, score);
    final seam = _resolvedSeam;
    if (seam == null) return;
    try {
      await seam.submitScore(boardId, score);
    } catch (_) {
      // Best-effort — local already has the authoritative copy.
    }
  }

  Future<List<ScoreEntry>> fetchTop(String boardId, {int limit = 10}) async {
    final seam = _resolvedSeam;
    if (seam != null) {
      try {
        return await seam.fetchTop(boardId, limit: limit);
      } catch (_) {
        // Fall through to the local fallback below.
      }
    }
    return [
      for (final entry in local.topN(limit))
        ScoreEntry(
          playerLabel: entry.name,
          score: _parseScore(entry.score),
          rank: entry.rank,
        ),
    ];
  }

  Future<List<ScoreEntry>> fetchAroundPlayer(
    String boardId,
    String playerLabel, {
    int radius = 2,
  }) async {
    final seam = _resolvedSeam;
    if (seam != null) {
      try {
        return await seam.fetchAroundPlayer(boardId, radius: radius);
      } catch (_) {
        // Fall through to the local fallback below.
      }
    }
    return [
      for (final entry in local.entriesAround(playerLabel, radius: radius))
        ScoreEntry(
          playerLabel: entry.name,
          score: _parseScore(entry.score),
          rank: entry.rank,
        ),
    ];
  }

  /// [LeaderboardEntry.score] is already [fmtNum]-formatted (thousands
  /// separator only, never a decimal point) — stripping non-digits round
  /// trips it back to the raw int losslessly.
  static int _parseScore(String formatted) =>
      int.tryParse(formatted.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
}

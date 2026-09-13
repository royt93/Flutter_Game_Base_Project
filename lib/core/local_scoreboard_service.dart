import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../presentation/widgets/common/leaderboard_list.dart';
import 'storage_service.dart';
import 'utils/format.dart';
import 'versioned_json_store.dart';

class _ScoreEntry {
  const _ScoreEntry({
    required this.playerLabel,
    required this.score,
    required this.sequence,
  });

  final String playerLabel;
  final int score;

  /// Monotonically increasing insertion order (0, 1, 2, ...), persisted
  /// alongside the score so a tie-break survives a reload. Not wall-clock
  /// time: two `submitScore` calls in the same process can legitimately
  /// land in the same millisecond, which would make a timestamp-based
  /// tie-break non-deterministic — an explicit counter never collides.
  final int sequence;
}

/// Local, single-device high-score table — a cache/offline-first
/// precursor to a real backend/Game Center leaderboard, and useful on its
/// own even without one. Unlike [LeaderboardList] (pure display, ranking
/// data always supplied by the caller), this service actually ranks a new
/// [submitScore] against every previous submission on this device.
///
/// Every submission is kept as its own row (not deduped per player) — same
/// "arcade high-score table" shape as the classic top-10 list, where the
/// same player can hold multiple ranks. Ties break by earlier submission
/// ranking higher, so ordering is fully deterministic regardless of
/// `List.sort`'s lack of a stability guarantee.
///
/// [topN] returns [LeaderboardEntry] directly — rank assigned from sorted
/// position, `score` formatted via [fmtNum] — so a caller can feed it
/// straight into [LeaderboardList] with no further transform.
class LocalScoreboardService extends GetxService {
  LocalScoreboardService({this.capacity = 50})
    : assert(capacity > 0, 'capacity must be greater than 0');

  static const _storageKey = 'local_scoreboard_v1';

  /// Max rows kept on disk. Submissions beyond this are dropped, lowest
  /// score first, the moment they'd rank last.
  final int capacity;

  List<_ScoreEntry>? _cached;
  int _nextSequence = 0;

  /// Gets the instance if already registered (safe to call from
  /// game/widget tests).
  static LocalScoreboardService? get maybe =>
      Get.isRegistered<LocalScoreboardService>()
      ? Get.find<LocalScoreboardService>()
      : null;

  VersionedJsonStore<List<_ScoreEntry>> get _store =>
      VersionedJsonStore<List<_ScoreEntry>>(
        storage: StorageService.to,
        key: _storageKey,
        schemaVersion: 1,
        toJson: (value) => {
          'entries': [
            for (final entry in value)
              {
                'playerLabel': entry.playerLabel,
                'score': entry.score,
                'sequence': entry.sequence,
              },
          ],
        },
        fromJson: _parseEntries,
        migrate: (fromVersion, json) => json,
      );

  static List<_ScoreEntry> _parseEntries(Map<String, Object?> json) {
    final raw = json['entries'];
    if (raw is! List) return <_ScoreEntry>[];
    final result = <_ScoreEntry>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = item.cast<String, Object?>();
      final label = map['playerLabel'];
      final score = map['score'];
      final sequence = map['sequence'];
      if (label is! String || label.trim().isEmpty) continue;
      if (score is! int || score < 0) continue;
      if (sequence is! int) continue;
      result.add(
        _ScoreEntry(playerLabel: label, score: score, sequence: sequence),
      );
    }
    return result;
  }

  // Lazily hydrated on first touch — same reasoning as
  // AchievementService/DailyQuestService: avoids depending on
  // StorageService already being Get.put'd before this service is
  // constructed.
  List<_ScoreEntry> get _entries {
    if (_cached != null) return _cached!;
    try {
      _cached = _store.load() ?? <_ScoreEntry>[];
    } catch (_) {
      _cached = <_ScoreEntry>[];
    }
    _nextSequence = _cached!.isEmpty
        ? 0
        : _cached!.map((e) => e.sequence).reduce((a, b) => a > b ? a : b) + 1;
    _sortAndTrim();
    return _cached!;
  }

  void _sortAndTrim() {
    _cached!.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.sequence.compareTo(b.sequence);
    });
    if (_cached!.length > capacity) {
      _cached!.removeRange(capacity, _cached!.length);
    }
  }

  // Same save-serialization pattern as AchievementService/DailyQuestService
  // (BUG-17): a burst of rapid submitScore calls without awaiting in
  // between must still land on disk in the order they were made.
  bool _saving = false;
  Future<void> _saveChain = Future.value();

  Future<void> _runSave() async {
    _saving = true;
    try {
      await _store.save(_entries);
    } catch (_) {
      // Swallow — a transient save failure must not wedge every
      // subsequent submit's save behind a permanently-rejected chain.
    } finally {
      _saving = false;
    }
  }

  /// Awaits every save queued so far — lets a test deterministically wait
  /// for a burst of rapid `submitScore` calls to fully settle instead of
  /// guessing a delay.
  @visibleForTesting
  Future<void> get debugPendingSaves => _saveChain;

  /// Submits a new score for [playerLabel], immediately re-ranked against
  /// every previous submission on this device. Dropped right away
  /// (never persisted) if it would rank below [capacity].
  void submitScore(String playerLabel, int score) {
    if (playerLabel.trim().isEmpty) {
      throw ArgumentError.value(
        playerLabel,
        'playerLabel',
        'must not be empty',
      );
    }
    if (score < 0) {
      throw ArgumentError.value(score, 'score', 'must not be negative');
    }
    final entries = _entries;
    entries.add(
      _ScoreEntry(
        playerLabel: playerLabel,
        score: score,
        sequence: _nextSequence++,
      ),
    );
    _sortAndTrim();
    _saveChain = _saving
        ? _saveChain.then((_) => _runSave())
        : _runSave();
  }

  /// The top [n] scores, highest first, ready to pass straight to
  /// [LeaderboardList] — `rank` is the sorted position (1-based), `score`
  /// formatted via [fmtNum]. Returns fewer than [n] entries if fewer have
  /// ever been submitted; an empty list for `n <= 0` (never throws).
  List<LeaderboardEntry> topN(int n) {
    if (n <= 0) return const <LeaderboardEntry>[];
    final entries = _entries;
    final count = n < entries.length ? n : entries.length;
    return [
      for (var i = 0; i < count; i++)
        LeaderboardEntry(
          rank: i + 1,
          name: entries[i].playerLabel,
          score: fmtNum(entries[i].score),
        ),
    ];
  }
}

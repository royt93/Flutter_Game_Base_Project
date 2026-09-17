import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'storage_service.dart';
import 'utils/clamped_clock.dart';
import 'versioned_json_store.dart';

/// How often a quest's progress/claim state resets.
enum QuestPeriod {
  /// Resets every calendar day (`todayEpochDayClamped()` boundary).
  daily,

  /// Resets every 7-day block (`todayEpochDayClamped() ~/ 7`).
  weekly,
}

class _QuestDef {
  const _QuestDef(this.targetCount, this.period);
  final int targetCount;
  final QuestPeriod period;
}

/// One quest's persisted progress, scoped to the period it was earned in
/// ([periodKey]). A record whose [periodKey] no longer matches the quest's
/// *current* period key is stale — read accessors treat it as "not started
/// this period" rather than mutating it eagerly, so a quest registered
/// after its period boundary already rolled over still resets correctly on
/// its first touch.
class _QuestRecord {
  const _QuestRecord({
    required this.periodKey,
    required this.progress,
    required this.claimed,
  });

  final int periodKey;
  final int progress;
  final bool claimed;

  _QuestRecord copyWith({int? progress, bool? claimed}) => _QuestRecord(
    periodKey: periodKey,
    progress: progress ?? this.progress,
    claimed: claimed ?? this.claimed,
  );
}

/// Caller-declared daily/weekly quest tracker — the third reset-cadence
/// mechanism alongside [AchievementService] (permanent, never resets) and
/// `DailyLoginService` (fixed login-streak calendar, not arbitrary
/// objectives). Quests ("win 3 matches", "use 1 booster") are declared up
/// front via [register] (id, target, reset period), same "caller owns the
/// declaration, service only tracks progress" convention as
/// [AchievementService.register].
///
/// Reset is driven entirely by [todayEpochDayClamped] (see
/// `utils/clamped_clock.dart`) so winding the device clock back can't be
/// used to re-claim an already-claimed quest early.
class DailyQuestService extends GetxService {
  DailyQuestService({String? storageKey})
    : _storageKey = storageKey ?? 'daily_quest_progress_v1';

  // ENH-71: instance field (was `static const`) so 2 instances can point
  // at 2 independent quest-progress tables — e.g. 1 per SaveSlotManager
  // slot via its `keyFor(slotId, suffix)` (same pattern ENH-69 used for
  // LocalScoreboardService). Defaulting to the same literal every prior
  // release used keeps an existing consumer app's save reading exactly the
  // same table it always did.
  final String _storageKey;
  static final int _maxInt = 0x7FFFFFFFFFFFFFFF;

  final Map<String, _QuestDef> _defs = {};
  Map<String, _QuestRecord>? _cached;

  /// Gets the instance if already registered (safe to call from
  /// game/widget tests).
  static DailyQuestService? get maybe => Get.isRegistered<DailyQuestService>()
      ? Get.find<DailyQuestService>()
      : null;

  VersionedJsonStore<Map<String, _QuestRecord>> get _store =>
      VersionedJsonStore<Map<String, _QuestRecord>>(
        storage: StorageService.to,
        key: _storageKey,
        schemaVersion: 1,
        toJson: (value) => {
          for (final entry in value.entries)
            entry.key: {
              'periodKey': entry.value.periodKey,
              'progress': entry.value.progress,
              'claimed': entry.value.claimed,
            },
        },
        fromJson: _parseRecords,
        migrate: (fromVersion, json) => json,
      );

  static Map<String, _QuestRecord> _parseRecords(Map<String, Object?> json) {
    final result = <String, _QuestRecord>{};
    for (final entry in json.entries) {
      final id = entry.key.trim();
      final value = entry.value;
      if (id.isEmpty || value is! Map) continue;
      final map = value.cast<String, Object?>();
      final periodKey = map['periodKey'];
      final progress = map['progress'];
      final claimed = map['claimed'];
      if (periodKey is! int || progress is! int || claimed is! bool) {
        continue;
      }
      if (progress < 0) continue;
      result[id] = _QuestRecord(
        periodKey: periodKey,
        progress: progress,
        claimed: claimed,
      );
    }
    return result;
  }

  // Lazily hydrated on first touch — same reasoning as AchievementService's
  // `_progressMap`: avoids depending on StorageService already being
  // Get.put'd before this service is constructed.
  Map<String, _QuestRecord> get _records {
    if (_cached != null) return _cached!;
    try {
      _cached = _store.load() ?? <String, _QuestRecord>{};
    } catch (_) {
      _cached = <String, _QuestRecord>{};
    }
    return _cached!;
  }

  // Same save-serialization pattern as AchievementService (BUG-17): a burst
  // of rapid incrementProgress/claim calls without awaiting in between must
  // still land on disk in the order they were made, not whichever I/O
  // happens to finish first.
  bool _saving = false;
  Future<void> _saveChain = Future.value();

  Future<void> _runSave() async {
    _saving = true;
    try {
      await _store.save(_records);
    } catch (_) {
      // Swallow — a transient save failure must not wedge every
      // subsequent call's save behind a permanently-rejected chain.
    } finally {
      _saving = false;
    }
  }

  void _scheduleSave() {
    _saveChain = _saving
        ? _saveChain.then((_) => _runSave())
        : _runSave();
  }

  /// Awaits every save queued so far — lets a test deterministically wait
  /// for a burst of rapid calls to fully settle instead of guessing a
  /// delay.
  @visibleForTesting
  Future<void> get debugPendingSaves => _saveChain;

  int _currentPeriodKey(QuestPeriod period) {
    final day = todayEpochDayClamped();
    return period == QuestPeriod.daily ? day : day ~/ 7;
  }

  void _validateId(String questId) {
    if (questId.trim().isEmpty) {
      throw ArgumentError.value(questId, 'questId', 'must not be empty');
    }
  }

  /// Declares [questId]'s [targetCount] and reset [period] up front. Safe
  /// to call again for the same id (e.g. re-declared every app boot) —
  /// only updates the declaration, never touches stored progress.
  void register(
    String questId,
    int targetCount, {
    QuestPeriod period = QuestPeriod.daily,
  }) {
    _validateId(questId);
    if (targetCount <= 0) {
      throw ArgumentError.value(
        targetCount,
        'targetCount',
        'must be greater than 0',
      );
    }
    _defs[questId] = _QuestDef(targetCount, period);
  }

  /// Current progress toward [questId]'s target, `0` if never registered
  /// or if the stored progress belongs to a period that has since rolled
  /// over (never throws).
  int progressOf(String questId) {
    final def = _defs[questId];
    if (def == null) return 0;
    final record = _records[questId];
    final periodKey = _currentPeriodKey(def.period);
    if (record == null || record.periodKey != periodKey) return 0;
    return record.progress;
  }

  /// [questId]'s registered target count, or `null` if never registered.
  int? targetOf(String questId) => _defs[questId]?.targetCount;

  /// `true` once [progressOf] reaches the registered target for the
  /// current period. `false` (never throws) for an id that was never
  /// [register]ed.
  bool isCompleted(String questId) {
    final def = _defs[questId];
    if (def == null) return false;
    return progressOf(questId) >= def.targetCount;
  }

  /// `true` if [questId]'s reward was already [claim]ed for the current
  /// period. `false` (never throws) for an id that was never [register]ed
  /// or whose stored claim belongs to a rolled-over period.
  bool isClaimed(String questId) {
    final def = _defs[questId];
    if (def == null) return false;
    final record = _records[questId];
    final periodKey = _currentPeriodKey(def.period);
    if (record == null || record.periodKey != periodKey) return false;
    return record.claimed;
  }

  /// Adds [amount] to [questId]'s progress for the current period —
  /// rebasing to `0` first if the stored record belongs to a period that
  /// has since rolled over. Safe to call after the quest is already
  /// completed: progress keeps accumulating, [isCompleted] stays `true`,
  /// never throws or "un-claims".
  ///
  /// Throws [StateError] if [questId] was never [register]ed — unlike
  /// [AchievementService], the reset period must be known up front for
  /// every increment, so there's no safe "track it anyway" fallback.
  void incrementProgress(String questId, int amount) {
    _validateId(questId);
    final def = _defs[questId];
    if (def == null) {
      throw StateError('quest "$questId" was not registered');
    }
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'must be greater than 0');
    }
    final periodKey = _currentPeriodKey(def.period);
    final records = _records;
    final existing = records[questId];
    final stale = existing == null || existing.periodKey != periodKey;
    final base = stale ? 0 : existing.progress;
    if (amount > _maxInt - base) {
      throw RangeError('progress overflow for $questId');
    }
    records[questId] = _QuestRecord(
      periodKey: periodKey,
      progress: base + amount,
      claimed: stale ? false : existing.claimed,
    );
    _scheduleSave();
  }

  /// Claims [questId]'s reward for the current period. Returns `true` only
  /// if this call actually claimed it (was completed and not already
  /// claimed this period) — `false` for an unregistered id, an
  /// incomplete quest, or one already claimed this period. Never throws.
  bool claim(String questId) {
    final def = _defs[questId];
    if (def == null) return false;
    if (!isCompleted(questId) || isClaimed(questId)) return false;

    final records = _records;
    // isCompleted() being true guarantees a record exists at the current
    // periodKey (progressOf only reads non-stale records).
    records[questId] = records[questId]!.copyWith(claimed: true);
    _scheduleSave();
    return true;
  }
}

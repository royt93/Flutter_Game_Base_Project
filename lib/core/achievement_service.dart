import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'storage_service.dart';
import 'versioned_json_store.dart';

/// Local achievement/badge progress tracker (no Game Center/Play Games
/// integration — that's a later, separate task).
///
/// This package doesn't hardcode any game-specific achievement list —
/// thresholds are declared by the *caller* up front via [register] (once
/// per achievement id, typically at app boot before any progress is
/// touched). [incrementProgress]/[isCompleted] then only need the id.
/// This was chosen over passing the threshold on every `incrementProgress`
/// call: callers add progress from many call sites scattered through game
/// logic, but only need to know the threshold value in one place (wherever
/// achievements are declared) — repeating it at every call site invites
/// them drifting out of sync.
///
/// Progress persists across restarts as one small JSON blob via
/// [VersionedJsonStore] (`achievementId -> progress`), rather than one raw
/// `StorageService` key per achievement. Thresholds themselves are **not**
/// persisted — they're cheap in-memory data the caller re-declares every
/// run via [register], same as the rest of the game's achievement list.
class AchievementService extends GetxService {
  AchievementService({String? storageKey})
    : _storageKey = storageKey ?? 'achievement_progress_v1';

  // ENH-71: instance field (was `static const`) so 2 instances can point
  // at 2 independent progress tables — e.g. 1 per SaveSlotManager slot via
  // its `keyFor(slotId, suffix)` (same pattern ENH-69 used for
  // LocalScoreboardService). Defaulting to the same literal every prior
  // release used keeps an existing consumer app's save reading exactly the
  // same table it always did.
  final String _storageKey;

  final Map<String, int> _thresholds = {};
  Map<String, int>? _progress;
  final StreamController<String> _unlockController =
      StreamController<String>.broadcast();

  /// Fires exactly once per achievement id, the moment [incrementProgress]
  /// pushes it from not-completed to completed (IDEA-43). Never fires from
  /// [register] alone — even if a newly-declared threshold is already
  /// retroactively met by existing progress — and never fires again from
  /// further increments once already completed.
  Stream<String> get onUnlock => _unlockController.stream;

  @override
  void onClose() {
    _unlockController.close();
    super.onClose();
  }

  /// Gets the instance if already registered (safe to call from
  /// game/widget tests).
  static AchievementService? get maybe => Get.isRegistered<AchievementService>()
      ? Get.find<AchievementService>()
      : null;

  VersionedJsonStore<Map<String, int>> get _store =>
      VersionedJsonStore<Map<String, int>>(
        storage: StorageService.to,
        key: _storageKey,
        schemaVersion: 1,
        toJson: (value) => value,
        fromJson: _parseProgress,
        migrate: (fromVersion, json) => json,
      );

  // Lazily hydrated on first touch, not in a constructor/onInit — avoids
  // depending on StorageService already being Get.put'd before this
  // service is constructed.
  Map<String, int> get _progressMap {
    if (_progress != null) return _progress!;
    try {
      _progress = _store.load() ?? <String, int>{};
    } catch (_) {
      // Domain fields are untrusted even after the envelope is valid. A
      // corrupt achievement entry must never prevent the app from booting.
      _progress = <String, int>{};
    }
    return _progress!;
  }

  Map<String, int> _parseProgress(Map<String, Object?> json) {
    final result = <String, int>{};
    for (final entry in json.entries) {
      final id = entry.key.trim();
      final value = entry.value;
      if (id.isEmpty || value is! int || value < 0) continue;
      result[id] = value;
    }
    return result;
  }

  // Serializes every save behind the currently in-flight one (BUG-17) —
  // fire-and-forget writes for the SAME key can otherwise complete out of
  // order (2 rapid incrementProgress calls racing their disk writes),
  // letting an older, already-superseded snapshot land on disk LAST and
  // silently roll back progress on next restart.
  //
  // `_saving` tracks whether a save is currently in flight so the FIRST
  // save of a burst still starts synchronously (matching the pre-fix
  // immediate-start behavior a caller may rely on to read back progress
  // right away without awaiting) — only a save that arrives WHILE another
  // is still in flight gets queued behind `_saveChain` instead. Each queued
  // link captures `_progressMap` (the same mutable map, already reflecting
  // every increment applied so far) only once it's actually its turn to
  // run, so a write initiated later always finishes later too. A failed
  // save is swallowed so one transient error doesn't permanently wedge
  // every increment after it.
  bool _saving = false;
  Future<void> _saveChain = Future.value();

  Future<void> _runSave(VersionedJsonStore<Map<String, int>> store) async {
    _saving = true;
    try {
      await store.save(_progressMap);
    } catch (_) {
      // Swallow — a transient save failure must not wedge every
      // subsequent increment's save behind a permanently-rejected chain.
    } finally {
      _saving = false;
    }
  }

  /// Awaits every save queued so far — lets a test deterministically wait
  /// for a burst of rapid `incrementProgress` calls to fully settle instead
  /// of guessing a delay.
  @visibleForTesting
  Future<void> get debugPendingSaves => _saveChain;

  /// Declares [achievementId]'s [threshold] up front. Safe to call again
  /// for the same id (e.g. re-declared every app boot) — only updates the
  /// threshold, never touches stored progress.
  void register(String achievementId, int threshold) {
    _validateId(achievementId);
    if (threshold <= 0) {
      throw ArgumentError.value(
        threshold,
        'threshold',
        'must be greater than 0',
      );
    }
    _thresholds[achievementId] = threshold;
  }

  /// Adds [amount] to [achievementId]'s progress. Safe to call after the
  /// achievement is already completed: progress keeps accumulating,
  /// [isCompleted] stays `true`, never throws or "re-unlocks".
  void incrementProgress(String achievementId, int amount) {
    _validateId(achievementId);
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'must be greater than 0');
    }
    final current = _progressMap[achievementId] ?? 0;
    if (amount > _maxInt - current) {
      throw RangeError('progress overflow for $achievementId');
    }
    final wasCompleted = isCompleted(achievementId);
    _progressMap[achievementId] = current + amount;
    if (!wasCompleted && isCompleted(achievementId)) {
      _unlockController.add(achievementId);
    }
    final store = _store;
    _saveChain = _saving
        ? _saveChain.then((_) => _runSave(store))
        : _runSave(store);
  }

  /// `true` once progress reaches the registered threshold. `false` (never
  /// throws) for an id that was never [register]ed or has no progress yet.
  bool isCompleted(String achievementId) {
    final threshold = _thresholds[achievementId];
    if (threshold == null) return false;
    return (_progressMap[achievementId] ?? 0) >= threshold;
  }

  /// Current progress for [achievementId] — `0` (never throws) for an id
  /// with no progress yet, whether or not it was ever [register]ed. Keeps
  /// reflecting the true accumulated value even past the threshold (an
  /// already-completed achievement isn't "capped" at its threshold here).
  int progressOf(String achievementId) {
    _validateId(achievementId);
    return _progressMap[achievementId] ?? 0;
  }

  /// The threshold declared via [register] for [achievementId], or `null`
  /// if it was never registered — distinct from [isCompleted]'s treatment
  /// of "never registered" as `false`, since a progress-bar UI needs to
  /// tell "no achievement declared" apart from "declared, not yet met".
  int? thresholdOf(String achievementId) {
    _validateId(achievementId);
    return _thresholds[achievementId];
  }

  /// `progressOf(id) / thresholdOf(id)` clamped to `[0.0, 1.0]` — `0.0`
  /// (never throws) if [achievementId] was never [register]ed or has no
  /// progress yet. Ready to feed straight into a progress-bar-shaped widget
  /// (`ProgressBarStars`, `CircularProgressRing`) without the caller having
  /// to null-check [thresholdOf] or clamp [progressOf]'s uncapped value.
  double progressRatio(String achievementId) {
    final threshold = thresholdOf(achievementId);
    if (threshold == null || threshold <= 0) return 0.0;
    return (progressOf(achievementId) / threshold).clamp(0.0, 1.0);
  }

  static final int _maxInt = 0x7FFFFFFFFFFFFFFF;

  void _validateId(String achievementId) {
    if (achievementId.trim().isEmpty) {
      throw ArgumentError.value(
        achievementId,
        'achievementId',
        'must not be empty',
      );
    }
  }
}

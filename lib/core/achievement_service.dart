import 'dart:async';

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
  static const _storageKey = 'achievement_progress_v1';

  final Map<String, int> _thresholds = {};
  Map<String, int>? _progress;

  /// Gets the instance if already registered (safe to call from
  /// game/widget tests).
  static AchievementService? get maybe =>
      Get.isRegistered<AchievementService>()
          ? Get.find<AchievementService>()
          : null;

  VersionedJsonStore<Map<String, int>> get _store =>
      VersionedJsonStore<Map<String, int>>(
        storage: StorageService.to,
        key: _storageKey,
        schemaVersion: 1,
        toJson: (value) => value,
        fromJson: (json) => json.map((k, v) => MapEntry(k, v as int)),
        migrate: (fromVersion, json) => json,
      );

  // Lazily hydrated on first touch, not in a constructor/onInit — avoids
  // depending on StorageService already being Get.put'd before this
  // service is constructed.
  Map<String, int> get _progressMap => _progress ??= _store.load() ?? {};

  /// Declares [achievementId]'s [threshold] up front. Safe to call again
  /// for the same id (e.g. re-declared every app boot) — only updates the
  /// threshold, never touches stored progress.
  void register(String achievementId, int threshold) {
    _thresholds[achievementId] = threshold;
  }

  /// Adds [amount] to [achievementId]'s progress. Safe to call after the
  /// achievement is already completed: progress keeps accumulating,
  /// [isCompleted] stays `true`, never throws or "re-unlocks".
  void incrementProgress(String achievementId, int amount) {
    _progressMap[achievementId] = (_progressMap[achievementId] ?? 0) + amount;
    unawaited(_store.save(_progressMap));
  }

  /// `true` once progress reaches the registered threshold. `false` (never
  /// throws) for an id that was never [register]ed or has no progress yet.
  bool isCompleted(String achievementId) {
    final threshold = _thresholds[achievementId];
    if (threshold == null) return false;
    return (_progressMap[achievementId] ?? 0) >= threshold;
  }
}

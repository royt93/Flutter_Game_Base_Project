import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'storage_service.dart';
import 'utils/clamped_clock.dart';
import 'versioned_json_store.dart';

/// One event's active window, as returned by
/// [SeasonEventService.currentWindow].
class SeasonEventWindow {
  const SeasonEventWindow({required this.start, required this.end});

  /// Window start, inclusive.
  final DateTime start;

  /// Window end, exclusive.
  final DateTime end;
}

/// Repeating, has-a-time-window event/season schedule — the piece
/// `CountdownChip` needs a caller to compute by hand today. Unlike
/// `DailyLoginService`'s fixed calendar-day cycle, an event here repeats
/// on its own caller-declared cadence (`length` active, then `cooldown`
/// idle, then repeats), anchored to whenever [currentWindow] is first
/// called for that [eventId] — not to a calendar boundary.
///
/// Entirely driven by [nowMsClamped] (never `DateTime.now()` directly,
/// same convention as every other time-gated reward system in this
/// package) — winding the device clock back can't roll a window back to
/// an earlier, already-elapsed cycle, since the clamp never lets the
/// clock this service reads go backward.
class SeasonEventService extends GetxService {
  static const _storageKey = 'season_event_anchors_v1';

  Map<String, int>? _cached;

  /// Gets the instance if already registered (safe to call from
  /// game/widget tests).
  static SeasonEventService? get maybe => Get.isRegistered<SeasonEventService>()
      ? Get.find<SeasonEventService>()
      : null;

  VersionedJsonStore<Map<String, int>> get _store =>
      VersionedJsonStore<Map<String, int>>(
        storage: StorageService.to,
        key: _storageKey,
        schemaVersion: 1,
        toJson: (value) => value,
        fromJson: _parseAnchors,
        migrate: (fromVersion, json) => json,
      );

  static Map<String, int> _parseAnchors(Map<String, Object?> json) {
    final result = <String, int>{};
    for (final entry in json.entries) {
      final id = entry.key.trim();
      final value = entry.value;
      if (id.isEmpty || value is! int || value < 0) continue;
      result[id] = value;
    }
    return result;
  }

  // Lazily hydrated on first touch — same reasoning as
  // AchievementService/DailyQuestService: avoids depending on
  // StorageService already being Get.put'd before this service is
  // constructed.
  Map<String, int> get _anchors {
    if (_cached != null) return _cached!;
    try {
      _cached = _store.load() ?? <String, int>{};
    } catch (_) {
      _cached = <String, int>{};
    }
    return _cached!;
  }

  // Same save-serialization pattern as every other ledger-shaped service
  // in this package (BUG-17).
  bool _saving = false;
  Future<void> _saveChain = Future.value();

  Future<void> _runSave() async {
    _saving = true;
    try {
      await _store.save(_anchors);
    } catch (_) {
      // Swallow — a transient save failure must not wedge every
      // subsequent call's save behind a permanently-rejected chain.
    } finally {
      _saving = false;
    }
  }

  /// Awaits every save queued so far — lets a test deterministically wait
  /// for [currentWindow]'s first-ever anchor write to fully settle
  /// instead of guessing a delay.
  @visibleForTesting
  Future<void> get debugPendingSaves => _saveChain;

  /// The active/most-recent window for [eventId] — [length] active,
  /// then [cooldown] idle, repeating indefinitely from whichever instant
  /// this was first called for [eventId] (persisted from then on, so
  /// every later call — including after a restart — returns a window on
  /// the exact same repeating schedule).
  ///
  /// Repeated calls within the same [length] + [cooldown] cycle return
  /// the identical [SeasonEventWindow] (same `start`/`end`); once a full
  /// cycle elapses, the next call returns the next cycle's window.
  SeasonEventWindow currentWindow(
    String eventId, {
    required Duration length,
    required Duration cooldown,
  }) {
    if (eventId.trim().isEmpty) {
      throw ArgumentError.value(eventId, 'eventId', 'must not be empty');
    }
    if (length <= Duration.zero) {
      throw ArgumentError.value(length, 'length', 'must be greater than 0');
    }
    if (cooldown < Duration.zero) {
      throw ArgumentError.value(cooldown, 'cooldown', 'must not be negative');
    }

    final now = nowMsClamped();
    final anchors = _anchors;
    var anchorMs = anchors[eventId];
    if (anchorMs == null) {
      anchorMs = now;
      anchors[eventId] = anchorMs;
      _saveChain = _saving
          ? _saveChain.then((_) => _runSave())
          : _runSave();
    }

    final cycleMs = length.inMilliseconds + cooldown.inMilliseconds;
    final elapsed = now - anchorMs;
    final cycleIndex = elapsed ~/ cycleMs;
    final startMs = anchorMs + cycleIndex * cycleMs;

    return SeasonEventWindow(
      start: DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true),
      end: DateTime.fromMillisecondsSinceEpoch(
        startMs + length.inMilliseconds,
        isUtc: true,
      ),
    );
  }
}

import 'package:flutter/foundation.dart';

import '../storage_service.dart';

/// A "never goes backward" clock — a monotonic day/ms clock shared by every
/// time-based reward system (daily reward, streaks, season...). It's a
/// standalone helper here, rather than logic scattered across each place
/// that needs it, so every date-based reward system goes through the same
/// protection layer.
///
/// **What this defends against:** the "advance the clock → claim the reward
/// → wind it back → repeat" loop. Once clamped, winding the clock back has
/// no effect, so every cheat attempt permanently burns the player's real
/// future time (losing the corresponding daily/streak/season checkpoint).
/// That's the strongest protection a client can offer without a trusted
/// server time source.
///
/// **What this does NOT defend against:** jumping the clock forward one-way.
/// So **don't** apply this clamp to anything where "staying in the future"
/// is exactly what the cheater wants — e.g. a weekend event: setting the
/// device to Saturday and leaving it there already achieves their goal, and
/// a monotonic clamp would make that state permanent, which makes things
/// worse.

/// Counts how many times a clock-rewind attempt was actually blocked by the
/// clamp (i.e. `current < maxSeen`, the device clock went strictly
/// backward) in [nowMsClamped]/[todayEpochDayClamped]. Not incremented on
/// the normal "clock moved forward" path, nor on a same-value re-read
/// (`current == maxSeen`, e.g. calling again later the same day) — neither
/// is a rewind attempt (BUG-48). Exposed for the debug/QA overlay to show
/// as a live diagnostic; tests reset it directly.
int clockRewindBlockedCount = 0;

int _debugTimeOffsetMs = 0;

/// The debug-only offset currently added to the real wall clock by every
/// [nowMsClamped]/[todayEpochDayClamped] read — always `0` unless
/// [setDebugTimeOffsetMs] was called. Exposed read-only for a debug/QA
/// panel to show the current "time travel" state.
int get debugTimeOffsetMs => _debugTimeOffsetMs;

/// Sets the debug-only offset [nowMsClamped]/[todayEpochDayClamped] add to
/// the real wall clock before every read — FEAT-93's DebugQaOverlay "Time
/// Travel" tab, letting a QA tester see a time-gated system (Daily Login/
/// Quest/Energy/Season Event) react to +2h/+24h/+7d without touching the
/// OS clock (which routinely causes unwanted side effects elsewhere on the
/// device). A no-op outside `kDebugMode`/`kProfileMode` — same posture as
/// [dlog] (`debug_log.dart`) — so nothing outside an already debug-gated
/// UI can ever move this, and it's always exactly `0` in a release build.
///
/// The offset itself is never persisted — only its EFFECT is (via the same
/// `maxMsSeen`/`maxEpochDaySeen` watermark ratchet a real forward clock
/// jump already causes, see this file's own class doc). Setting it back to
/// `0` does NOT "undo" a prior jump's watermark advance, matching exactly
/// how winding a REAL device clock back after a forward jump behaves too —
/// a QA build's storage should be treated as burned/reset-worthy after
/// deliberately time-traveling, same as after manually changing the
/// system clock during testing today.
void setDebugTimeOffsetMs(int offsetMs) {
  if (!kDebugMode && !kProfileMode) return;
  _debugTimeOffsetMs = offsetMs;
}

/// Current millisecond timestamp, clamped to never go below the largest
/// value seen so far.
///
/// Reads/writes the ambient [StorageService.to] singleton by default. Pass
/// [storage] explicitly for a class that holds its own injected
/// `StorageService` instance instead of going through the global singleton
/// (e.g. `VersionedJsonStore`) — using the wrong instance here would clamp
/// against a different watermark than the one the caller actually persists
/// its own data through.
int nowMsClamped([StorageService? storage]) {
  final store = storage ?? StorageService.to;
  final current =
      DateTime.now().toUtc().millisecondsSinceEpoch + _debugTimeOffsetMs;
  final maxSeen = store.getInt(StorageKeys.maxMsSeen);
  if (current > maxSeen) {
    store.setInt(StorageKeys.maxMsSeen, current);
    return current;
  }
  // BUG-48: `current == maxSeen` (same millisecond re-read, or — far more
  // commonly for the day-granularity sibling below — a second call the
  // same day) is NOT a rewind attempt; only `current < maxSeen` is.
  if (current < maxSeen) clockRewindBlockedCount++;
  return maxSeen;
}

/// Days since epoch (UTC), clamped to never go below the largest value seen so far.
int todayEpochDayClamped() {
  final current =
      (DateTime.now().toUtc().millisecondsSinceEpoch + _debugTimeOffsetMs) ~/
      86400000;
  final maxSeen = StorageService.to.getInt(StorageKeys.maxEpochDaySeen);
  if (current > maxSeen) {
    StorageService.to.setInt(StorageKeys.maxEpochDaySeen, current);
    return current;
  }
  // BUG-48: repeated calls within the same day (`current == maxSeen`) are
  // normal — only `current < maxSeen` is an actual blocked rewind.
  if (current < maxSeen) clockRewindBlockedCount++;
  return maxSeen;
}

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
/// clamp (i.e. `current <= maxSeen`, the device clock was NOT ahead of the
/// stored watermark) in [nowMsClamped]/[todayEpochDayClamped]. Not
/// incremented on the normal "clock moved forward" path. Exposed for the
/// debug/QA overlay to show as a live diagnostic; tests reset it directly.
int clockRewindBlockedCount = 0;

/// Current millisecond timestamp, clamped to never go below the largest value seen so far.
int nowMsClamped() {
  final current = DateTime.now().toUtc().millisecondsSinceEpoch;
  final maxSeen = StorageService.to.getInt(StorageKeys.maxMsSeen);
  if (current > maxSeen) {
    StorageService.to.setInt(StorageKeys.maxMsSeen, current);
    return current;
  }
  clockRewindBlockedCount++;
  return maxSeen;
}

/// Days since epoch (UTC), clamped to never go below the largest value seen so far.
int todayEpochDayClamped() {
  final current = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
  final maxSeen = StorageService.to.getInt(StorageKeys.maxEpochDaySeen);
  if (current > maxSeen) {
    StorageService.to.setInt(StorageKeys.maxEpochDaySeen, current);
    return current;
  }
  clockRewindBlockedCount++;
  return maxSeen;
}

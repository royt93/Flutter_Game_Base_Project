import 'dart:convert';

import 'package:get/get.dart';

import 'storage_service.dart';
import 'utils/clamped_clock.dart';

enum CooldownStatus { ready, running }

/// Immutable point-in-time read of one cooldown's state.
class CooldownSnapshot {
  const CooldownSnapshot({
    required this.key,
    required this.status,
    required this.remaining,
  });

  final String key;
  final CooldownStatus status;
  final Duration remaining;
}

/// Keyed cooldown tracker (reward claim timers, booster reuse delays,
/// PvP action gates, ...) that survives app restart and resists
/// clock-rewind cheating.
///
/// Every read is computed lazily from [nowMsClamped] against a persisted
/// `key -> endMs` map — the same anti-cheat clamp `utils/clamped_clock.dart`
/// gives daily rewards/streaks and [EnergyService] uses for its own regen
/// math. There is deliberately **no timer of any kind** here, per-key or
/// shared: N active cooldowns cost zero background timers, same as
/// [EnergyService] never runs one for its own regen. A UI countdown (e.g.
/// `CooldownCountdownChip`) drives its own per-second tick to animate a
/// value this service already computed instantly.
class PersistentCooldownService extends GetxService {
  /// Gets the instance if already registered (safe to call from call sites
  /// that may run before/without this service registered, e.g. widget
  /// tests).
  static PersistentCooldownService? get maybe =>
      Get.isRegistered<PersistentCooldownService>()
      ? Get.find<PersistentCooldownService>()
      : null;

  /// Bumped on every [start]/[cancel] — wrap a read in `Obx` (or listen to
  /// this directly) to rebuild when a cooldown's structural state changes.
  /// Never bumped by the mere passage of time: nothing here polls a clock,
  /// so there is nothing to notify on a tick.
  final revision = 0.obs;

  /// Starts (or restarts, if already running) the cooldown at [key] to end
  /// [duration] from now. Persists immediately (not write-behind-buffered)
  /// — a missed write on kill here would let a booster/reward be reused
  /// for free, the same "real transaction" class as a purchase.
  void start(String key, Duration duration) {
    if (key.isEmpty) {
      throw ArgumentError.value(key, 'key', 'must not be empty');
    }
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'must be > 0');
    }
    final state = _readState();
    state[key] = nowMsClamped() + duration.inMilliseconds;
    _persist(state);
    revision.value++;
  }

  /// Cancels the cooldown at [key] — [statusOf] reports
  /// [CooldownStatus.ready] immediately afterward. A no-op on storage (but
  /// still bumps [revision]) if [key] wasn't running.
  void cancel(String key) {
    final state = _readState();
    state.remove(key);
    _persist(state);
    revision.value++;
  }

  CooldownStatus statusOf(String key) => remainingOf(key) > Duration.zero
      ? CooldownStatus.running
      : CooldownStatus.ready;

  Duration remainingOf(String key) {
    final endMs = _readState()[key];
    if (endMs == null) return Duration.zero;
    final remainingMs = endMs - nowMsClamped();
    return remainingMs > 0
        ? Duration(milliseconds: remainingMs)
        : Duration.zero;
  }

  CooldownSnapshot snapshotOf(String key) => CooldownSnapshot(
    key: key,
    status: statusOf(key),
    remaining: remainingOf(key),
  );

  /// Reads the persisted map, dropping (never trusting) any entry whose
  /// key/value doesn't strictly type-check — a corrupted or hand-edited
  /// entry is treated as if it had never been set (never-started ==
  /// ready), never coerced into a value that could read as already
  /// elapsed sooner than a real [start] would have produced.
  Map<String, int> _readState() {
    final raw = StorageService.to.getString(StorageKeys.cooldownStateV1);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <String, int>{};
      for (final entry in decoded.entries) {
        final k = entry.key;
        final v = entry.value;
        if (k is String && v is int) {
          result[k] = v;
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  /// Persists [state], first dropping any entry that has already elapsed
  /// so the blob doesn't grow forever with finished cooldowns — the
  /// "cleanup expired entries" pass happens here, on write, instead of a
  /// separate scheduled sweep.
  void _persist(Map<String, int> state) {
    final now = nowMsClamped();
    state.removeWhere((_, endMs) => endMs <= now);
    StorageService.to.setString(StorageKeys.cooldownStateV1, jsonEncode(state));
  }
}

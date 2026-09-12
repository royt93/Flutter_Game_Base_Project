import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'storage_service.dart';
import 'utils/clamped_clock.dart';
import 'versioned_json_store.dart';

/// Length of the repeating daily-login-streak cycle: day 1..7, then wraps
/// back to day 1 (see `doc/task/todo/FEAT-07-daily-login-streak-calendar.md`).
const int kDailyLoginCycleLength = 7;

/// Result of a [DailyLoginService.claimToday] call.
class DailyLoginClaimResult {
  const DailyLoginClaimResult({
    required this.streakDay,
    required this.streakWasReset,
  });

  /// Streak position after this claim, 1..[kDailyLoginCycleLength].
  final int streakDay;

  /// Whether a skipped day reset the streak back to day 1 as part of this
  /// claim (`false` for an ordinary next-day claim, a same-day no-op, or
  /// wrapping from day 7 back to day 1 after completing a full cycle).
  final bool streakWasReset;
}

class _DailyLoginState {
  const _DailyLoginState({
    required this.lastClaimedEpochDay,
    required this.streakDay,
    required this.claimedDaysInCycle,
  });

  static const initial = _DailyLoginState(
    lastClaimedEpochDay: -1,
    streakDay: 0,
    claimedDaysInCycle: {},
  );

  /// Epoch day (from `todayEpochDayClamped()`) of the last successful
  /// claim. `-1` means never claimed.
  final int lastClaimedEpochDay;

  /// Current position in the cycle, 1..[kDailyLoginCycleLength]; `0` before
  /// the first ever claim.
  final int streakDay;

  /// Which cycle days (1..[kDailyLoginCycleLength]) have been claimed since
  /// the last reset/wrap — for a 7-day login-streak calendar UI.
  final Set<int> claimedDaysInCycle;
}

/// Tracks the daily-login streak: last claimed day, current position
/// (1..7, cycling) in the reward cycle, and which days of the current cycle
/// have already been claimed.
///
/// The ONLY source of "what day is it" is `todayEpochDayClamped()`
/// (`utils/clamped_clock.dart`) — this service never calls `DateTime.now()`
/// directly, so winding the device clock back can't be used to claim the
/// same day twice or dodge the streak-reset penalty for a skipped day.
class DailyLoginService extends GetxService {
  static const String _storageKey = 'daily_login_state_v1';

  late final VersionedJsonStore<_DailyLoginState> _store =
      VersionedJsonStore<_DailyLoginState>(
        storage: StorageService.to,
        key: _storageKey,
        schemaVersion: 1,
        toJson: (s) => {
          'lastClaimedEpochDay': s.lastClaimedEpochDay,
          'streakDay': s.streakDay,
          'claimedDaysInCycle': s.claimedDaysInCycle.toList(),
        },
        fromJson: (json) => _DailyLoginState(
          lastClaimedEpochDay: json['lastClaimedEpochDay'] as int? ?? -1,
          streakDay: json['streakDay'] as int? ?? 0,
          claimedDaysInCycle:
              (json['claimedDaysInCycle'] as List?)?.cast<int>().toSet() ??
              {},
        ),
        migrate: (fromVersion, json) => json,
      );

  _DailyLoginState? _cached;

  _DailyLoginState get _state => _cached ??= _store.load() ?? _DailyLoginState.initial;

  // Serializes every save behind the currently in-flight one (BUG-18, same
  // root cause/fix as AchievementService's BUG-17) — fire-and-forget writes
  // for the same key can otherwise complete out of order, letting an older,
  // already-superseded streak snapshot land on disk LAST and roll the
  // streak back (or re-open an already-claimed day) on next restart.
  //
  // `_saving` lets the FIRST save of a burst still start synchronously
  // (existing tests read `_state` back on a fresh `DailyLoginService()`
  // right after a `claimToday()` call with no await in between, relying on
  // that immediate-start behavior) — only a save arriving while another is
  // still in flight gets queued behind `_saveChain`.
  bool _saving = false;
  Future<void> _saveChain = Future.value();

  Future<void> _runSave() async {
    _saving = true;
    try {
      await _store.save(_cached!);
    } catch (_) {
      // Swallow — a transient save failure must not wedge every
      // subsequent claim's save behind a permanently-rejected chain.
    } finally {
      _saving = false;
    }
  }

  /// Awaits every save queued so far — lets a test deterministically wait
  /// for a burst of rapid `claimToday` calls to fully settle instead of
  /// guessing a delay.
  @visibleForTesting
  Future<void> get debugPendingSaves => _saveChain;

  /// Gets the instance if already registered (safe to call from widget tests).
  static DailyLoginService? get maybe =>
      Get.isRegistered<DailyLoginService>() ? Get.find<DailyLoginService>() : null;

  /// Current streak position, 1..[kDailyLoginCycleLength]; `0` before the
  /// very first claim.
  int get currentStreakDay => _state.streakDay;

  /// Which cycle days (1..[kDailyLoginCycleLength]) have been claimed since
  /// the last reset/wrap.
  Set<int> get claimedDaysInCycle => Set.unmodifiable(_state.claimedDaysInCycle);

  /// Whether today's reward is still claimable (i.e. not already claimed).
  bool canClaimToday() => _state.lastClaimedEpochDay != todayEpochDayClamped();

  /// Claims today's reward: advances the streak by one day, or resets it to
  /// day 1 if at least one full day was skipped since the last claim.
  /// Marks today claimed. A no-op (returns the unchanged current state,
  /// `streakWasReset: false`) if today was already claimed.
  DailyLoginClaimResult claimToday() {
    final today = todayEpochDayClamped();
    final state = _state;

    if (state.lastClaimedEpochDay == today) {
      return DailyLoginClaimResult(streakDay: state.streakDay, streakWasReset: false);
    }

    final continuesStreak = state.lastClaimedEpochDay == today - 1;
    final streakWasReset = !continuesStreak;
    final nextStreakDay = streakWasReset ? 1 : (state.streakDay % kDailyLoginCycleLength) + 1;
    // A fresh cycle (streakWasReset, or wrapping from day 7 back to day 1
    // after completing one) starts the claimed-days calendar over.
    final nextClaimed = nextStreakDay == 1
        ? <int>{1}
        : {...state.claimedDaysInCycle, nextStreakDay};

    _cached = _DailyLoginState(
      lastClaimedEpochDay: today,
      streakDay: nextStreakDay,
      claimedDaysInCycle: nextClaimed,
    );
    _saveChain = _saving ? _saveChain.then((_) => _runSave()) : _runSave();

    return DailyLoginClaimResult(streakDay: nextStreakDay, streakWasReset: streakWasReset);
  }
}

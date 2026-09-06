import 'dart:async';

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
    unawaited(_store.save(_cached!));

    return DailyLoginClaimResult(streakDay: nextStreakDay, streakWasReset: streakWasReset);
  }
}

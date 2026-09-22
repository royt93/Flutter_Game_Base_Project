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
    required this.currentRunLength,
    required this.longestStreakEver,
  });

  static const initial = _DailyLoginState(
    lastClaimedEpochDay: -1,
    streakDay: 0,
    claimedDaysInCycle: {},
    currentRunLength: 0,
    longestStreakEver: 0,
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

  /// IDEA-49: TRUE number of consecutive claimed days, unbounded by
  /// [kDailyLoginCycleLength] — unlike [streakDay] (which wraps back to 1
  /// every 7 days purely for the calendar UI), this keeps counting past 7
  /// for as long as the streak isn't broken. Resets to 1 on the same claim
  /// that resets [streakDay].
  final int currentRunLength;

  /// IDEA-49: highest [currentRunLength] ever reached — a permanent
  /// record that survives a streak reset (unlike [currentRunLength]
  /// itself, which resets to 1 the moment a day is skipped).
  final int longestStreakEver;
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
  DailyLoginService({String? storageKey})
    : _storageKey = storageKey ?? 'daily_login_state_v1';

  // ENH-71: instance field (was `static const`) so 2 instances can point
  // at 2 independent streak states — e.g. 1 per SaveSlotManager slot via
  // its `keyFor(slotId, suffix)` (same pattern ENH-69 used for
  // LocalScoreboardService). Defaulting to the same literal every prior
  // release used keeps an existing consumer app's save reading exactly the
  // same table it always did.
  final String _storageKey;

  late final VersionedJsonStore<_DailyLoginState> _store =
      VersionedJsonStore<_DailyLoginState>(
        storage: StorageService.to,
        key: _storageKey,
        schemaVersion: 1,
        toJson: (s) => {
          'lastClaimedEpochDay': s.lastClaimedEpochDay,
          'streakDay': s.streakDay,
          'claimedDaysInCycle': s.claimedDaysInCycle.toList(),
          'currentRunLength': s.currentRunLength,
          'longestStreakEver': s.longestStreakEver,
        },
        fromJson: _parseState,
        migrate: (fromVersion, json) => json,
      );

  _DailyLoginState? _cached;

  _DailyLoginState get _state {
    if (_cached != null) return _cached!;
    try {
      _cached = _store.load() ?? _DailyLoginState.initial;
    } catch (_) {
      _cached = _DailyLoginState.initial;
    }
    return _cached!;
  }

  /// Domain trust boundary: an envelope can be valid JSON while its fields
  /// are stale, malformed or internally contradictory. Resetting the whole
  /// daily-login state is the safest recovery because it cannot grant a
  /// reward or preserve an invalid streak.
  static _DailyLoginState _parseState(Map<String, Object?> json) {
    final last = json['lastClaimedEpochDay'];
    final streak = json['streakDay'];
    final claimed = json['claimedDaysInCycle'];
    if (last is! int || streak is! int || claimed is! List) {
      return _DailyLoginState.initial;
    }
    final days = <int>{};
    for (final value in claimed) {
      if (value is! int || value < 1 || value > kDailyLoginCycleLength) {
        return _DailyLoginState.initial;
      }
      days.add(value);
    }
    if (last < -1 || streak < 0 || streak > kDailyLoginCycleLength) {
      return _DailyLoginState.initial;
    }
    if (last == -1 && (streak != 0 || days.isNotEmpty)) {
      return _DailyLoginState.initial;
    }
    if (last >= 0 && (streak == 0 || !days.contains(streak))) {
      return _DailyLoginState.initial;
    }

    // IDEA-49: added after `currentRunLength`/`longestStreakEver` already
    // existed on disk for some saves — a JSON written before this field
    // existed simply omits the key (not "present but wrong type"), so that
    // case migrates gracefully (best-effort: `streak`, the only signal an
    // old save has about an active run) rather than being treated as
    // corrupt. A key that IS present but wrong-typed is genuine corruption
    // and still falls back to `initial`, same as every other field here.
    final hasRun = json.containsKey('currentRunLength');
    final hasLongest = json.containsKey('longestStreakEver');
    if (hasRun && json['currentRunLength'] is! int) {
      return _DailyLoginState.initial;
    }
    if (hasLongest && json['longestStreakEver'] is! int) {
      return _DailyLoginState.initial;
    }
    final currentRunLength = hasRun ? json['currentRunLength']! as int : streak;
    final longestStreakEver = hasLongest
        ? json['longestStreakEver']! as int
        : currentRunLength;

    if (currentRunLength < 0 || longestStreakEver < currentRunLength) {
      return _DailyLoginState.initial;
    }
    if (last == -1 && currentRunLength != 0) {
      return _DailyLoginState.initial;
    }
    if (last >= 0 && currentRunLength < 1) {
      return _DailyLoginState.initial;
    }

    return _DailyLoginState(
      lastClaimedEpochDay: last,
      streakDay: streak,
      claimedDaysInCycle: days,
      currentRunLength: currentRunLength,
      longestStreakEver: longestStreakEver,
    );
  }

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
  bool _saveDirty = false;
  Future<void> _saveChain = Future.value();

  Future<void> _runSave() async {
    try {
      await _store.save(_cached!);
    } catch (_) {
      // Swallow — a transient save failure must not wedge every
      // subsequent claim's save behind a permanently-rejected chain.
    }
  }

  // BUG-45: the originally-proposed fix (chain unconditionally via
  // `_saveChain = _saveChain.then((_) => _runSave())`, dropping `_saving`
  // entirely) turned out to be WRONG — proven by TDD, not assumed: the
  // comment above this field already documents a real existing test that
  // reads a second instance back with NO `await` at all between that and
  // `claimToday()`, relying on the FIRST save of a burst starting (and,
  // for the in-memory fallback `StorageService` that test uses,
  // completing) synchronously. `.then()` (and an `await` INSIDE another
  // async function's own body awaiting a nested async call — also tried,
  // also confirmed broken the same way) is ALWAYS deferred via
  // `scheduleMicrotask`, even on an already-complete Future — only a
  // plain, un-awaited direct call to an async function whose own body
  // never actually suspends runs fully synchronously. So the fix below
  // calls `_runSave()` directly (never wrapped in `await` from another
  // async function), and reschedules itself via `Future.whenComplete`
  // instead of looping inside an `async` method.
  //
  // This keeps `_saving`, but fixes the ORIGINAL bug's actual defect —
  // `finally { _saving = false; }` running before a queued `.then()` got a
  // chance to observe it — by never resetting `_saving` until a whole pass
  // completes with no new request arriving during it. `_scheduleSave`
  // itself never awaits anything, so its own `if (_saving)` check-and-set
  // is atomic; nothing can observe `_saving` mid-transition.
  void _scheduleSave() {
    if (_saving) {
      _saveDirty = true;
      return;
    }
    _saving = true;
    _runSaveAndReschedule();
  }

  void _runSaveAndReschedule() {
    _saveDirty = false;
    _saveChain = _runSave().whenComplete(() {
      if (_saveDirty) {
        _runSaveAndReschedule();
      } else {
        _saving = false;
      }
    });
  }

  /// Awaits every save queued so far — lets a test deterministically wait
  /// for a burst of rapid `claimToday` calls to fully settle instead of
  /// guessing a delay.
  @visibleForTesting
  Future<void> get debugPendingSaves => _saveChain;

  /// Gets the instance if already registered (safe to call from widget tests).
  static DailyLoginService? get maybe => Get.isRegistered<DailyLoginService>()
      ? Get.find<DailyLoginService>()
      : null;

  /// Current streak position, 1..[kDailyLoginCycleLength]; `0` before the
  /// very first claim.
  int get currentStreakDay => _state.streakDay;

  /// IDEA-49: highest number of TRUE consecutive claimed days ever
  /// reached — unlike [currentStreakDay] (which wraps 1..7 purely for the
  /// calendar UI), this counts past 7 and never resets when a streak
  /// breaks; it only ever grows. Starts at `0` before any claim.
  int get longestStreakEver => _state.longestStreakEver;

  /// Which cycle days (1..[kDailyLoginCycleLength]) have been claimed since
  /// the last reset/wrap.
  Set<int> get claimedDaysInCycle =>
      Set.unmodifiable(_state.claimedDaysInCycle);

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
      return DailyLoginClaimResult(
        streakDay: state.streakDay,
        streakWasReset: false,
      );
    }

    final continuesStreak = state.lastClaimedEpochDay == today - 1;
    final streakWasReset = !continuesStreak;
    final nextStreakDay = streakWasReset
        ? 1
        : (state.streakDay % kDailyLoginCycleLength) + 1;
    // A fresh cycle (streakWasReset, or wrapping from day 7 back to day 1
    // after completing one) starts the claimed-days calendar over.
    final nextClaimed = nextStreakDay == 1
        ? <int>{1}
        : {...state.claimedDaysInCycle, nextStreakDay};

    final nextRunLength = streakWasReset ? 1 : state.currentRunLength + 1;
    final nextLongest = nextRunLength > state.longestStreakEver
        ? nextRunLength
        : state.longestStreakEver;

    _cached = _DailyLoginState(
      lastClaimedEpochDay: today,
      streakDay: nextStreakDay,
      claimedDaysInCycle: nextClaimed,
      currentRunLength: nextRunLength,
      longestStreakEver: nextLongest,
    );
    _scheduleSave();

    return DailyLoginClaimResult(
      streakDay: nextStreakDay,
      streakWasReset: streakWasReset,
    );
  }
}

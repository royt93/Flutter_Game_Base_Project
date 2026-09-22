import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'storage_service.dart';
import 'utils/clamped_clock.dart';
import 'utils/economy_math.dart';

/// Energy/lives system that refills over time (Candy Crush-style "hearts").
///
/// Current energy is computed lazily from elapsed time since the last
/// baseline checkpoint, using [nowMsClamped] — **never** `DateTime.now()`
/// directly — so the same anti-cheat clamp `utils/clamped_clock.dart` gives
/// daily rewards/streaks also protects energy: winding the device clock
/// back can't farm free refills (see that file's doc comment for exactly
/// what the clamp does and doesn't defend against — a one-way forward jump
/// still isn't prevented, same as everywhere else that uses it).
class EnergyService extends GetxService {
  final int maxEnergy;
  final Duration refillInterval;

  EnergyService({
    this.maxEnergy = 5,
    this.refillInterval = const Duration(minutes: 30),
  }) {
    // BUG-19: a misconfigured maxEnergy/refillInterval (a caller passing a
    // hardcoded or remote-config-derived value that turns out <= 0) must
    // fail loudly at construction time rather than silently producing
    // nonsensical energy math (an always-empty/always-full bar, or a
    // division that never terminates a refill tick). A plain runtime
    // check (not an `assert`) so it still fires in release builds, where
    // asserts are stripped.
    if (maxEnergy <= 0) {
      throw ArgumentError.value(maxEnergy, 'maxEnergy', 'must be > 0');
    }
    if (refillInterval <= Duration.zero) {
      throw ArgumentError.value(
        refillInterval,
        'refillInterval',
        'must be > 0',
      );
    }
  }

  /// Gets the instance if already registered (safe to call from call sites
  /// that may run before/without energy registered, e.g. widget tests).
  static EnergyService? get maybe =>
      Get.isRegistered<EnergyService>() ? Get.find<EnergyService>() : null;

  /// Current energy, after crediting any whole refill ticks earned since
  /// the last checkpoint. Capped at [maxEnergy].
  int get currentEnergy {
    _regen();
    return _currentState().count;
  }

  /// True while a [grantInfiniteLives] window is still active.
  bool get hasInfiniteLives =>
      StorageService.to.getInt(StorageKeys.energyInfiniteUntilMs, def: 0) >
      nowMsClamped();

  /// Consumes [amount] energy. Returns false — and deducts nothing — if
  /// there isn't enough. Always succeeds without deducting while
  /// [hasInfiniteLives] is active.
  ///
  /// Throws [ArgumentError] for `amount <= 0` (BUG-19) — a negative amount
  /// would previously pass the `energy < amount` guard and increase energy
  /// above [maxEnergy]; zero would report success while consuming nothing.
  /// Both are caller bugs, not something a real player action can trigger.
  bool consumeEnergy([int amount = 1]) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'must be > 0');
    }
    if (hasInfiniteLives) return true;
    _regen();

    final state = _currentState();
    if (state.count < amount) return false;

    final nowFullBeforeSpend = state.count >= maxEnergy;
    _scheduleSave(
      _EnergyState(
        count: state.count - amount,
        // Đầy tim trước khi trừ -> đây là lượt tiêu đầu tiên, bắt đầu
        // tính giờ hồi tim mới kể từ đúng thời điểm này (không dùng mốc
        // cũ đã lỗi thời).
        lastMs: nowFullBeforeSpend ? nowMsClamped() : state.lastMs,
      ),
    );
    return true;
  }

  /// Grants temporary unlimited energy for [duration] — `consumeEnergy`
  /// succeeds without deducting until it elapses.
  Future<void> grantInfiniteLives(Duration duration) =>
      StorageService.to.setInt(
        StorageKeys.energyInfiniteUntilMs,
        nowMsClamped() + duration.inMilliseconds,
      );

  /// Time remaining until the next energy point regens. `Duration.zero`
  /// when already full ([maxEnergy] reached) or while [hasInfiniteLives] is
  /// active. Mirrors [_regen]'s own math exactly (same tick-remainder
  /// computation) rather than approximating, so a UI countdown built on
  /// this never drifts out of sync with when [currentEnergy] actually ticks
  /// up.
  Duration get timeUntilNextEnergy {
    if (hasInfiniteLives) return Duration.zero;
    _regen();

    final state = _currentState();
    if (state.count >= maxEnergy) return Duration.zero;

    final intervalMs = refillInterval.inMilliseconds;
    final now = nowMsClamped();
    final elapsed = (now - state.lastMs) % intervalMs;
    return Duration(milliseconds: intervalMs - elapsed);
  }

  /// Credits whole refill ticks earned since the stored baseline. Leaves
  /// any leftover (sub-tick) progress toward the next point intact instead
  /// of resetting it, so reading [currentEnergy] repeatedly never costs
  /// partial progress.
  ///
  /// Delegates the actual tick math to [regenEnergy] (IDEA-36) — the same
  /// pure function `tool/economy_sim.dart`'s headless balancing simulator
  /// calls, so the two can never drift apart into 2 subtly different
  /// formulas.
  void _regen() {
    final state = _currentState();
    final result = regenEnergy(
      count: state.count,
      maxEnergy: maxEnergy,
      lastMs: state.lastMs,
      nowMs: nowMsClamped(),
      intervalMs: refillInterval.inMilliseconds,
    );
    if (result.count == state.count && result.lastMs == state.lastMs) return;

    _scheduleSave(_EnergyState(count: result.count, lastMs: result.lastMs));
  }

  /// Reads the persisted `{count, lastMs}` checkpoint, clamping `count`
  /// into `[0, maxEnergy]` (BUG-19 — a corrupted/hand-edited/imported value
  /// outside that range would otherwise be trusted and returned forever,
  /// as-is, by every getter built on this).
  ///
  /// Falls back to the legacy two-key format (`StorageKeys.energyCount`/
  /// `energyLastMs`) when `StorageKeys.energyStateV1` hasn't been written
  /// yet — an existing install's save predates this single-blob format and
  /// must not silently reset to full energy.
  ///
  /// BUG-46: every read/mutate call site below uses [_currentState] (never
  /// this directly) — [_pendingState], while a write is in flight, is the
  /// AUTHORITATIVE latest state (already computed, just not landed on
  /// disk yet). Reading straight from storage here alone would let a
  /// second call arriving before the first write lands see the STALE
  /// pre-write state, compute its OWN delta from that same stale
  /// baseline, and silently lose the first call's change even though
  /// write ordering itself (`_scheduleSave`) is race-free — an even
  /// simpler double-tap free-energy exploit than write reordering alone.
  _EnergyState _readState() {
    final raw = StorageService.to.getString(StorageKeys.energyStateV1);
    if (raw != null) {
      try {
        final json = jsonDecode(raw);
        if (json is Map<String, Object?>) {
          final count = json['count'];
          final lastMs = json['lastMs'];
          if (count is int && lastMs is int) {
            return _EnergyState(
              count: count.clamp(0, maxEnergy),
              lastMs: lastMs,
            );
          }
        }
      } catch (_) {
        // Malformed JSON — fall through to the legacy-key fallback below,
        // same as a fresh install with nothing saved yet.
      }
    }

    final legacyCount = StorageService.to.getInt(
      StorageKeys.energyCount,
      def: maxEnergy,
    );
    final legacyLastMs = StorageService.to.getInt(
      StorageKeys.energyLastMs,
      def: nowMsClamped(),
    );
    return _EnergyState(
      count: legacyCount.clamp(0, maxEnergy),
      lastMs: legacyLastMs,
    );
  }

  Future<void> _writeState(_EnergyState state) => StorageService.to.setString(
    StorageKeys.energyStateV1,
    jsonEncode({'count': state.count, 'lastMs': state.lastMs}),
  );

  // BUG-46: consumeEnergy/_regen used to call `unawaited(_writeState(...))`
  // directly, with no ordering guarantee at all — 2 back-to-back
  // consumeEnergy() calls (double-tap) without an await in between raced 2
  // independent writes, and whichever finished LAST (real I/O order, not
  // call order) won, potentially leaving a STALE, higher energy count on
  // disk after a restart — a free-energy farm via double-tapping.
  //
  // Unlike the sibling ledger services fixed in BUG-45 (which keep an
  // in-memory field `_runSave` re-reads at actual write time), EnergyService
  // has no persistent cache — `state` is computed fresh by the caller and
  // must be captured at SCHEDULE time, not re-derived later. `_pendingState`
  // holds "the latest state a caller wants written" — overwritten (never
  // queued as a list) by every call, since only the newest value ever needs
  // to reach disk. Same atomicity property as BUG-45's `_saveDirty`: this
  // check-and-set never awaits anything, so it's race-free by construction.
  // `_latestState` is null until the first `_scheduleSave` call this
  // instance ever makes — from then on it's the AUTHORITATIVE in-memory
  // state (see `_currentState`), same role the other 8 ledger services'
  // permanent in-memory field plays, just lazily started instead of
  // eagerly hydrated (matches this class's existing "no persistent cache
  // until there's something to cache" design). `_saveDirty` — not
  // `_latestState == null` — is what `_runSaveAndReschedule` checks to
  // decide whether to loop again, since `_latestState` deliberately stays
  // set (never cleared) so reads keep seeing the true latest value even
  // while its own write is still in flight.
  _EnergyState? _latestState;
  bool _saving = false;
  bool _saveDirty = false;
  Future<void> _saveChain = Future.value();

  /// Awaits every save queued so far — lets a test deterministically wait
  /// for a burst of rapid `consumeEnergy`/regen writes to fully settle
  /// instead of guessing a delay (same convention as the sibling ledger
  /// services fixed in BUG-45).
  @visibleForTesting
  Future<void> get debugPendingSaves => _saveChain;

  _EnergyState _currentState() => _latestState ?? _readState();

  void _scheduleSave(_EnergyState state) {
    _latestState = state;
    _saveDirty = true;
    if (_saving) return;
    _saving = true;
    _runSaveAndReschedule();
  }

  void _runSaveAndReschedule() {
    _saveDirty = false;
    _saveChain = _writeState(_latestState!).whenComplete(() {
      if (_saveDirty) {
        _runSaveAndReschedule();
      } else {
        _saving = false;
      }
    });
  }

  /// The current regen baseline timestamp — exposed for tests that need to
  /// assert an exact elapsed-time expectation without drifting against the
  /// real wall clock.
  @visibleForTesting
  int get debugLastRegenMs => _currentState().lastMs;
}

class _EnergyState {
  const _EnergyState({required this.count, required this.lastMs});
  final int count;
  final int lastMs;
}

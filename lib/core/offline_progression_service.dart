import 'package:get/get.dart';

import 'storage_service.dart';
import 'utils/clamped_clock.dart';
import 'utils/economy_math.dart';
import 'utils/trusted_clock.dart';

/// Calculates idle/offline earnings accrued while the player was away:
/// `earnings = min(elapsed, maxOfflineCap) * productionRatePerSecond`, where
/// `elapsed` is time since the last claim.
///
/// Uses [nowMsClamped] — the same monotonic clock guarding daily
/// rewards/streaks — as its default source of "what time is it", so winding
/// the device clock back can't be used to re-farm offline earnings. A
/// caller can opt into the stricter [trustedClock] instead (ENH-86) — see
/// its own doc comment for when that's worth it over the default.
///
/// Doesn't include a "watch an ad to double" flow — that's an ad/UI concern
/// a consumer app layers on top of [claim] (e.g. call [claim] then award the
/// result again after a rewarded ad).
class OfflineProgressionService extends GetxService {
  /// Elapsed time beyond this doesn't count, e.g. an 8h cap means a 3-day
  /// absence still only pays out 8 hours' worth.
  Duration maxOfflineCap;

  /// Optional stricter clock (ENH-86) — when supplied, [pendingEarnings]
  /// and [claim] read "now" from [TrustedClockService.nowMsTrusted]
  /// instead of [nowMsClamped]. Left `null` (the default), behavior is
  /// completely unchanged from before this field existed.
  ///
  /// Worth adding over plain [nowMsClamped] specifically for a payout this
  /// large and one-shot: [nowMsClamped]'s watermark advances to WHATEVER
  /// wall-clock value it's handed, so winding the clock forward once,
  /// claiming, then winding it back still pays out the (fraudulent)
  /// elapsed time — the watermark then just stays stuck at that future
  /// value, permanently blocking further HONEST claims until real time
  /// catches up, which is a self-inflicted lock, not a fix. A
  /// [TrustedClockService] classifies that same forward jump as
  /// [ClockJudgement.suspiciousForwardJump] and refuses to advance its
  /// baseline for it, so [nowMsTrusted] instead returns the last
  /// trusted "now", `_earningsAt` computes zero elapsed time against it,
  /// and — unlike [nowMsClamped] — an honest sample right after recovers
  /// normally instead of staying locked. A consumer that wants to
  /// log/alert on a rejected claim can read
  /// [TrustedClockService.lastJudgement] itself right after calling
  /// [claim] — this service doesn't duplicate that reporting.
  final TrustedClockService? trustedClock;

  OfflineProgressionService({
    this.maxOfflineCap = const Duration(hours: 8),
    this.trustedClock,
  });

  int _now() => trustedClock?.nowMsTrusted() ?? nowMsClamped();

  /// Safe to call from a call site that may run before/without this service
  /// registered (e.g. widget tests).
  static OfflineProgressionService? get maybe =>
      Get.isRegistered<OfflineProgressionService>()
      ? Get.find<OfflineProgressionService>()
      : null;

  /// Falls back to [now] (never persisted) when nothing has been claimed
  /// yet, so a fresh install doesn't hand out a free `maxOfflineCap` of
  /// earnings on its very first read.
  ///
  /// Takes the caller's already-sampled [now] as the fallback instead of
  /// calling `nowMsClamped()` again — a second real-clock read here could
  /// land on a later millisecond than the first, permanently baking a few
  /// milliseconds of phantom earnings into every future claim (the two
  /// timestamps disagree forever after, since only one of them gets
  /// persisted as `offlineLastClaimedMs`).
  int _lastClaimedMsOr(int now) {
    final saved = StorageService.to.getInt(
      StorageKeys.offlineLastClaimedMs,
      def: 0,
    );
    return saved > 0 ? saved : now;
  }

  /// Validates BOTH inputs before any calculation or state change (BUG-27):
  /// a negative [maxOfflineCap] makes `.clamp(0, negativeUpperBound)` throw
  /// a confusing internal error instead of this documented one, and a
  /// negative/non-finite [productionRatePerSecond] would otherwise return
  /// negative/NaN/infinite "earnings". Throwing here — before [claim]'s
  /// caller reaches its `setInt` — also means an invalid call never
  /// advances `offlineLastClaimedMs`.
  ///
  /// Delegates the actual earnings math to [offlineEarnings] (IDEA-36) —
  /// the same pure function `tool/economy_sim.dart`'s headless balancing
  /// simulator calls, so the two can never drift apart into 2 subtly
  /// different formulas. (Its own validation covers the same 2 checks
  /// this doc describes — kept here too since the doc is the more
  /// discoverable place for a caller to learn about them.)
  double _earningsAt(int now, double productionRatePerSecond) {
    return offlineEarnings(
      lastClaimedMs: _lastClaimedMsOr(now),
      nowMs: now,
      maxOfflineCapMs: maxOfflineCap.inMilliseconds,
      productionRatePerSecond: productionRatePerSecond,
    );
  }

  /// Pure calculation given the current config — does not mutate anything
  /// (does not reset the "last claimed" timestamp).
  double pendingEarnings(double productionRatePerSecond) =>
      _earningsAt(_now(), productionRatePerSecond);

  /// Returns the earned amount and resets "last claimed" to now. Does not
  /// itself apply any ad-doubling — the caller decides whether to double it.
  Future<double> claim(double productionRatePerSecond) async {
    final now = _now();
    final earned = _earningsAt(now, productionRatePerSecond);
    await StorageService.to.setInt(StorageKeys.offlineLastClaimedMs, now);
    return earned;
  }
}

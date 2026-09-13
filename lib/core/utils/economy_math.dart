/// Pure, Flutter-free economy math shared by [EnergyService]/
/// [OfflineProgressionService] and `tool/economy_sim.dart` (IDEA-36).
///
/// This file has ZERO dependency on `flutter/`, `get`, or `StorageService`
/// on purpose: it's the single source of truth both the real services and
/// the headless balancing simulator call, so the simulator can never drift
/// from the real game's math (no separately-maintained "close enough"
/// reimplementation to fall out of sync).
library;

/// Result of one [regenEnergy] tick computation.
class EnergyRegenResult {
  const EnergyRegenResult({required this.count, required this.lastMs});

  /// Energy count after crediting any whole ticks earned.
  final int count;

  /// New regen-baseline timestamp — only advances by whole ticks (any
  /// sub-tick remainder toward the next point is preserved, not reset).
  final int lastMs;
}

/// Same formula as `EnergyService._regen()`: credits whole [intervalMs]
/// ticks earned between [lastMs] and [nowMs], capped at [maxEnergy].
/// A no-op (returns [count]/[lastMs] unchanged) when already full or when
/// no whole tick has elapsed yet.
EnergyRegenResult regenEnergy({
  required int count,
  required int maxEnergy,
  required int lastMs,
  required int nowMs,
  required int intervalMs,
}) {
  if (count >= maxEnergy) {
    return EnergyRegenResult(count: count, lastMs: lastMs);
  }

  final ticks = (nowMs - lastMs) ~/ intervalMs;
  if (ticks <= 0) {
    return EnergyRegenResult(count: count, lastMs: lastMs);
  }

  var newCount = count + ticks;
  if (newCount > maxEnergy) newCount = maxEnergy;
  final newLastMs = newCount >= maxEnergy ? nowMs : lastMs + ticks * intervalMs;
  return EnergyRegenResult(count: newCount, lastMs: newLastMs);
}

/// Same formula as `OfflineProgressionService._earningsAt()`: earnings
/// accrued between [lastClaimedMs] and [nowMs], capped at
/// [maxOfflineCapMs] elapsed, at [productionRatePerSecond].
///
/// Throws [ArgumentError] for a negative [maxOfflineCapMs] or a
/// non-finite/negative [productionRatePerSecond] — same validation as the
/// real service, so a misconfigured simulator scenario fails exactly the
/// same way a misconfigured real service would.
double offlineEarnings({
  required int lastClaimedMs,
  required int nowMs,
  required int maxOfflineCapMs,
  required double productionRatePerSecond,
}) {
  if (maxOfflineCapMs < 0) {
    throw ArgumentError.value(
      maxOfflineCapMs,
      'maxOfflineCapMs',
      'must be >= 0',
    );
  }
  if (!productionRatePerSecond.isFinite || productionRatePerSecond < 0) {
    throw ArgumentError.value(
      productionRatePerSecond,
      'productionRatePerSecond',
      'must be finite and >= 0',
    );
  }

  final elapsedMs = (nowMs - lastClaimedMs).clamp(0, maxOfflineCapMs);
  return elapsedMs / 1000 * productionRatePerSecond;
}

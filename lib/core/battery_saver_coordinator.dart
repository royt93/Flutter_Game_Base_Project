import 'performance_tier_service.dart';

/// Battery level reading seam, 0–100, or `null` if unavailable/unknown
/// right now (e.g. a platform channel hiccup, or a desktop target with no
/// battery at all) — this package stays neutral of a concrete
/// battery-reading plugin (same convention as `crash_reporter.dart`/
/// `analytics_provider.dart`/`connectivity_coordinator.dart`'s own
/// `ReachabilityProbe`): a consuming app injects
/// `() async => (await Battery().batteryLevel)` (or whatever plugin it
/// already uses) rather than this kit adding a new runtime dependency
/// every consumer pays for, even ones that never want battery-based
/// throttling.
typedef BatteryLevelProvider = Future<int?> Function();

/// Proactively forces [performanceTier] down to [PerformanceTier.low] when
/// the device's battery drops below [lowBatteryThreshold] — unlike
/// [PerformanceTierService]'s own FPS hysteresis (which only reacts AFTER
/// frame times already suffer), this acts on battery level directly, so a
/// device that's still rendering smoothly but running low still backs off
/// decorative shader/ticker work before it gets hot or the OS throttles it.
///
/// [check] is the entire API — caller-driven (same "no invented polling
/// loop" seam convention as `TrustedClockService.reconcileWithTrustedSource`/
/// `smart_reminder_scheduling.dart`'s `rescheduleEnergyReminder`): call it
/// on whatever cadence makes sense for the app (a periodic `Timer`, app
/// resume, a battery-level-changed platform event) — this class holds no
/// `Timer`/subscription of its own.
///
/// A `null` reading (battery level unavailable) is a no-op — it never
/// force-downgrades on missing data, and never releases an active
/// override either (an unrelated transient read failure mid-session
/// shouldn't un-throttle a genuinely low-battery device).
class BatterySaverCoordinator {
  BatterySaverCoordinator({
    required this.performanceTier,
    required this.batteryLevelProvider,
    this.lowBatteryThreshold = 20,
  });

  final PerformanceTierService performanceTier;
  final BatteryLevelProvider batteryLevelProvider;

  /// Battery percentage (0–100) below which [performanceTier] is forced to
  /// [PerformanceTier.low].
  final int lowBatteryThreshold;

  /// Whether the most recent [check] is actively holding
  /// [performanceTier] forced low — exposed for a debug/QA panel to show,
  /// not consumed internally.
  bool get isForcingLow => _forcingLow;
  bool _forcingLow = false;

  /// Reads [batteryLevelProvider] and applies (or releases) the override.
  ///
  /// Below [lowBatteryThreshold]: forces [PerformanceTierService.tier] to
  /// [PerformanceTier.low], overriding whatever the FPS tracker currently
  /// says.
  ///
  /// At or above [lowBatteryThreshold], only while an override from a
  /// PREVIOUS low-battery [check] is active: releases it by restoring
  /// [PerformanceTierService.tier] to [PerformanceTierService.measuredTier]
  /// — the tracker's own current FPS-based opinion, not necessarily
  /// [PerformanceTier.high] (battery recovering doesn't mean frame times
  /// did too). At or above the threshold with no active override, this is
  /// a no-op — [PerformanceTierService] keeps deciding its own tier from
  /// FPS exactly as if this coordinator didn't exist.
  Future<void> check() async {
    final level = await batteryLevelProvider();
    if (level == null) return;

    if (level < lowBatteryThreshold) {
      _forcingLow = true;
      performanceTier.tier.value = PerformanceTier.low;
    } else if (_forcingLow) {
      _forcingLow = false;
      performanceTier.tier.value = performanceTier.measuredTier;
    }
  }
}

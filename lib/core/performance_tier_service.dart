import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

/// Coarse runtime performance bucket a decorative shader/ticker layer
/// (`AuroraBgLayer`, `NeonAuraLayer` — see `ShaderTickerLayerState`) checks
/// to decide whether to keep animating.
enum PerformanceTier { high, low }

/// Pure FPS tracker: no dependency on `SchedulerBinding`/Flutter bindings at
/// all, so it can be driven with synthetic frame durations in a plain unit
/// test. Keeps a rolling window of the last [windowSize] frame durations
/// (ms); once the window fills, averages it into an FPS figure and applies
/// **hysteresis** — a lower [downgradeFpsThreshold] and a higher
/// [upgradeFpsThreshold] — so a device hovering right around one cutoff
/// doesn't flap between tiers every window.
class FrameBudgetTracker {
  FrameBudgetTracker({
    this.windowSize = 60,
    this.downgradeFpsThreshold = 40,
    this.upgradeFpsThreshold = 55,
  }) {
    // BUG-23: a misconfigured tracker (windowSize <= 0 leaves _window
    // permanently empty, so `_window.reduce(...)` below would throw once a
    // caller expects it to have filled) or threshold nonsense (NaN/negative,
    // or downgrade >= upgrade so tier could never recover) must fail loudly
    // at construction, not produce a tracker that's subtly broken forever.
    if (windowSize <= 0) {
      throw ArgumentError.value(windowSize, 'windowSize', 'must be > 0');
    }
    if (!downgradeFpsThreshold.isFinite || downgradeFpsThreshold < 0) {
      throw ArgumentError.value(
        downgradeFpsThreshold,
        'downgradeFpsThreshold',
        'must be finite and >= 0',
      );
    }
    if (!upgradeFpsThreshold.isFinite || upgradeFpsThreshold < 0) {
      throw ArgumentError.value(
        upgradeFpsThreshold,
        'upgradeFpsThreshold',
        'must be finite and >= 0',
      );
    }
    if (downgradeFpsThreshold >= upgradeFpsThreshold) {
      throw ArgumentError(
        'downgradeFpsThreshold ($downgradeFpsThreshold) must be < '
        'upgradeFpsThreshold ($upgradeFpsThreshold)',
      );
    }
  }

  final int windowSize;
  final double downgradeFpsThreshold;
  final double upgradeFpsThreshold;

  final List<double> _window = [];
  PerformanceTier _tier = PerformanceTier.high;

  PerformanceTier get tier => _tier;

  /// Appends [frameDurationMs] to the rolling window. Once the window has
  /// [windowSize] samples, recomputes the average FPS and applies
  /// hysteresis. Returns true only when this call actually flipped [tier].
  ///
  /// A non-finite or negative [frameDurationMs] is discarded (BUG-23) — it
  /// never joins the window, so it can't poison the rolling average.
  bool recordFrameMs(double frameDurationMs) {
    // BUG-23: a single non-finite/negative sample (a platform glitch, a
    // bogus timestamp) would otherwise poison the rolling average forever
    // (NaN propagates through every future avgMs; a negative value skews
    // it wrong) — skip it instead of ever adding it to the window.
    if (!frameDurationMs.isFinite || frameDurationMs < 0) return false;

    _window.add(frameDurationMs);
    if (_window.length > windowSize) _window.removeAt(0);
    if (_window.length < windowSize) return false;

    final avgMs = _window.reduce((a, b) => a + b) / _window.length;
    if (avgMs <= 0) return false;
    final avgFps = 1000 / avgMs;

    final previous = _tier;
    if (_tier == PerformanceTier.high && avgFps < downgradeFpsThreshold) {
      _tier = PerformanceTier.low;
    } else if (_tier == PerformanceTier.low && avgFps > upgradeFpsThreshold) {
      _tier = PerformanceTier.high;
    }
    return _tier != previous;
  }
}

/// Runtime, live-reactive FPS gate for decorative shader/ticker layers.
///
/// Unlike the OS Reduce Motion check in `ShaderTickerLayerState` (checked
/// once, since that flag is fixed for the process), this measures real
/// frame timings while the app runs and can flip [tier] mid-session — a
/// device that gets hot/throttles, or whose workload changes, drops to
/// [PerformanceTier.low] and can recover back to [PerformanceTier.high].
class PerformanceTierService extends GetxService {
  PerformanceTierService({FrameBudgetTracker? tracker})
    : _tracker = tracker ?? FrameBudgetTracker();

  final FrameBudgetTracker _tracker;
  final Rx<PerformanceTier> tier = PerformanceTier.high.obs;
  bool _listening = false;

  /// Null-safe accessor for call sites that may run before/without this
  /// service registered (mirrors `AudioManager.maybe`).
  static PerformanceTierService? get maybe =>
      Get.isRegistered<PerformanceTierService>()
      ? Get.find<PerformanceTierService>()
      : null;

  /// Starts listening to real frame timings. Call once after registering
  /// the service (e.g. in a consuming app's boot sequence) — not called
  /// automatically, matching this repo's convention of not forcing new
  /// core services into `example/`'s boot.
  void start() {
    if (_listening) return;
    _listening = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      recordFrame(timing.totalSpan.inMicroseconds / 1000);
    }
  }

  /// Testable seam for [_onTimings]: feeds one frame duration (ms) to the
  /// tracker and updates [tier] only on an actual transition. Lets tests
  /// drive tier changes without a real `SchedulerBinding` frame stream or
  /// constructing `FrameTiming` directly.
  void recordFrame(double frameDurationMs) {
    if (_tracker.recordFrameMs(frameDurationMs)) {
      tier.value = _tracker.tier;
    }
  }

  /// Removes the timings callback so nothing leaks if this service is ever
  /// disposed.
  void stopListening() {
    if (!_listening) return;
    _listening = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  @override
  void onClose() {
    stopListening();
    super.onClose();
  }
}

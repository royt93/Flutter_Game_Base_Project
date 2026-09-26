import 'package:get/get.dart';

/// Platform-neutral rewarded ad seam — this package ships no third-party ads SDK.
/// A consuming app registers its own adapter (e.g. backed by `applovin_admob_sdk`)
/// via `Get.put<AdRewardSeam>(myAdapter, permanent: true)`, mirroring
/// [PurchaseSeam]/[CrashReporter]/[AnalyticsProvider].
abstract class AdRewardSeam {
  /// Shows a rewarded ad. Returns true if the ad completed and reward was earned.
  Future<bool> showRewardedAd({String? placement});

  /// Whether a rewarded ad is currently loaded and ready to display.
  bool get isReady;

  /// Null-safe accessor for call sites that may run before/without an ad seam registered.
  static AdRewardSeam? get maybe =>
      Get.isRegistered<AdRewardSeam>() ? Get.find<AdRewardSeam>() : null;
}

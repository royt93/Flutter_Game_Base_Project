import 'package:get/get.dart';

/// Platform-neutral in-app-purchase seam — the package pulls in no IAP SDK
/// (no `in_app_purchase`, no RevenueCat, …); a consuming app registers its
/// own adapter via `Get.put<PurchaseSeam>(myAdapter, permanent: true)`,
/// same pattern as [CrashReporter]/[AnalyticsProvider]/[CloudSaveProvider]/
/// [RemoteConfigService].
///
/// `ShopItemCard`'s `onTap` is already fully decoupled from any purchase
/// API — this seam doesn't change that. It exists purely for
/// **consistency**: 1 standard interface to call from `onTap` (or any
/// future purchase UI), instead of every consuming app inventing its own
/// shape. Deliberately minimal — no consumable/subscription modeling, no
/// receipt validation, no restore-result diffing; the app's own adapter
/// owns that complexity.
abstract class PurchaseSeam {
  /// Attempts to buy [productId]. Returns true on success.
  Future<bool> buy(String productId);

  /// Restores previously bought products (the App Store/Play Store
  /// "restore purchases" flow).
  Future<void> restorePurchases();

  /// Whether [productId] is currently owned (after a prior [buy] or
  /// [restorePurchases]).
  bool isOwned(String productId);

  /// Null-safe accessor for call sites that may run before/without a
  /// seam registered (mirrors [CrashReporter.maybe]). No `Noop*` default
  /// is provided on purpose — unlike logging an analytics event, silently
  /// no-op'ing a purchase attempt would hide a real integration bug.
  static PurchaseSeam? get maybe =>
      Get.isRegistered<PurchaseSeam>() ? Get.find<PurchaseSeam>() : null;
}

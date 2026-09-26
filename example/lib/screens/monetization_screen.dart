import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

/// In-app demo adapter when no native store adapter is registered.
// ponytail: fake purchase seam for example app, replace with in_app_purchase in production.
class _DefaultDemoPurchaseAdapter implements PurchaseSeam {
  final Set<String> _owned = {};

  @override
  Future<bool> buy(String productId) async {
    _owned.add(productId);
    return true;
  }

  @override
  bool isOwned(String productId) => _owned.contains(productId);

  @override
  Future<void> restorePurchases() async {}
}

/// In-app demo ad adapter when no mediation SDK is registered.
// ponytail: fake ad seam for example app. Plug in applovin_admob_sdk here in production.
class _DefaultDemoAdRewardAdapter implements AdRewardSeam {
  @override
  bool get isReady => true;

  @override
  Future<bool> showRewardedAd({String? placement}) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return true;
  }
}

class MonetizationScreen extends StatefulWidget {
  const MonetizationScreen({super.key});

  @override
  State<MonetizationScreen> createState() => _MonetizationScreenState();
}

class _MonetizationScreenState extends State<MonetizationScreen> {
  static const _vipSku = 'pack_vip_no_ads';

  late final PurchaseSeam _purchases;
  late final PurchaseLedgerService _ledger;
  late final AdRewardSeam _ads;
  late final EconomyWallet _wallet;
  final _haptics = HapticChoreographer();

  String _status = 'Browse store offers or earn rewards through ads.';

  @override
  void initState() {
    super.initState();
    if (StorageService.maybe == null) {
      Get.put(StorageService(null), permanent: true);
    }
    _purchases =
        PurchaseSeam.maybe ??
        Get.put<PurchaseSeam>(_DefaultDemoPurchaseAdapter(), permanent: true);
    _ledger =
        PurchaseLedgerService.maybe ??
        Get.put(PurchaseLedgerService(), permanent: true);
    _ads =
        AdRewardSeam.maybe ??
        Get.put<AdRewardSeam>(_DefaultDemoAdRewardAdapter(), permanent: true);
    _wallet =
        EconomyWallet.maybe ??
        Get.put(EconomyWallet(storage: StorageService.to), permanent: true);
  }

  bool get _isVip => _ledger.owns(_vipSku);

  Future<void> _buyConsumable({
    required String sku,
    required String currency,
    required int amount,
    required String label,
  }) async {
    final success = await _purchases.buy(sku);
    if (!success) {
      _haptics.play(HapticPattern.error);
      if (!mounted) return;
      setState(() => _status = 'Purchase cancelled or failed.');
      return;
    }

    _ledger.grantConsumable(sku, 1);
    await _wallet.earn(
      currency: currency,
      amount: amount,
      transactionId: 'iap_${sku}_${DateTime.now().microsecondsSinceEpoch}',
    );

    _haptics.play(HapticPattern.reward);
    if (!mounted) return;
    setState(() => _status = 'Purchased $label! +$amount $currency.');
  }

  Future<void> _buyVip() async {
    final success = await _purchases.buy(_vipSku);
    if (!success) {
      _haptics.play(HapticPattern.error);
      if (!mounted) return;
      setState(() => _status = 'VIP purchase cancelled.');
      return;
    }

    _ledger.grantPermanent(_vipSku);
    _haptics.play(HapticPattern.reward);
    if (!mounted) return;
    setState(() => _status = 'Unlocked VIP No-Ads Pass permanently!');
  }

  Future<void> _restorePurchases() async {
    await _purchases.restorePurchases();
    if (_purchases.isOwned(_vipSku)) {
      _ledger.grantPermanent(_vipSku);
    }
    _haptics.play(HapticPattern.reward);
    if (!mounted) return;
    setState(() => _status = 'Purchases restored successfully.');
  }

  Future<void> _watchRewardedAd() async {
    // If player owns VIP No-Ads, skip ad playback directly as a VIP benefit.
    if (_isVip) {
      await _wallet.earn(
        currency: 'coins',
        amount: 50,
        transactionId: 'ad_vip_skip_${DateTime.now().microsecondsSinceEpoch}',
      );
      _haptics.play(HapticPattern.reward);
      if (!mounted) return;
      setState(() => _status = 'VIP Perk: Ad skipped! Received 50 coins.');
      return;
    }

    if (!_ads.isReady) {
      _haptics.play(HapticPattern.error);
      if (!mounted) return;
      setState(() => _status = 'Ad is not ready yet. Please try again soon.');
      return;
    }

    final rewarded = await _ads.showRewardedAd(placement: 'store_free_coins');
    if (rewarded) {
      await _wallet.earn(
        currency: 'coins',
        amount: 50,
        transactionId: 'ad_reward_${DateTime.now().microsecondsSinceEpoch}',
      );
      _haptics.play(HapticPattern.reward);
      if (!mounted) return;
      setState(() => _status = 'Watched ad! Received 50 coins.');
    } else {
      _haptics.play(HapticPattern.error);
      if (!mounted) return;
      setState(() => _status = 'Ad closed before completion. No reward earned.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'monetization'.tr, onBack: Get.back),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NeonTheme.s16,
                  vertical: NeonTheme.s8,
                ),
                child: PanelCard(
                  child: Text(_status, style: TextStyle(color: NeonTheme.ink)),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NeonTheme.s16,
                    vertical: NeonTheme.s8,
                  ),
                  children: [
                    // Account & VIP Status card
                    Obx(() {
                      final coins = _wallet.balanceOf('coins');
                      final gems = _wallet.balanceOf('gems');
                      return PanelCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isVip ? 'VIP Member' : 'Standard Player',
                                    style: TextStyle(
                                      color:
                                          _isVip ? NeonTheme.gold : NeonTheme.ink,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isVip
                                        ? 'No-Ads Active (Instant ad skip)'
                                        : 'Ads enabled',
                                    style: TextStyle(
                                      color: NeonTheme.inkSoft,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Coins: $coins | Gems: $gems',
                              style: TextStyle(
                                color: NeonTheme.cyan,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: NeonTheme.s16),
                    // In-App Purchases section
                    PanelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'In-App Purchases',
                            style: TextStyle(
                              color: NeonTheme.ink,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          CommonListTile(
                            title: 'Pouch of Coins (+100 Coins)',
                            subtitle: r'Consumable pack • $0.99',
                            trailing: CommonButton(
                              width: 90,
                              label: r'$0.99',
                              onTap:
                                  () => _buyConsumable(
                                    sku: 'pack_coins_100',
                                    currency: 'coins',
                                    amount: 100,
                                    label: 'Pouch of Coins',
                                  ),
                            ),
                          ),
                          const SizedBox(height: NeonTheme.s8),
                          CommonListTile(
                            title: 'Handful of Gems (+20 Gems)',
                            subtitle: r'Consumable pack • $1.99',
                            trailing: CommonButton(
                              width: 90,
                              label: r'$1.99',
                              onTap:
                                  () => _buyConsumable(
                                    sku: 'pack_gems_20',
                                    currency: 'gems',
                                    amount: 20,
                                    label: 'Handful of Gems',
                                  ),
                            ),
                          ),
                          const SizedBox(height: NeonTheme.s8),
                          CommonListTile(
                            title: 'VIP No-Ads Pass',
                            subtitle:
                                _isVip
                                    ? 'Owned (Permanent unlock)'
                                    : r'Remove all ads & instant claim • $2.99',
                            trailing: CommonButton(
                              width: 90,
                              label: _isVip ? 'Owned' : r'$2.99',
                              variant:
                                  _isVip
                                      ? CommonButtonVariant.secondary
                                      : CommonButtonVariant.primary,
                              onTap: _isVip ? null : _buyVip,
                            ),
                          ),
                          const SizedBox(height: 12),
                          CommonButton(
                            label: 'Restore Purchases',
                            variant: CommonButtonVariant.secondary,
                            onTap: _restorePurchases,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: NeonTheme.s16),
                    // Rewarded Ads Section (Ready for applovin_admob_sdk)
                    PanelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Rewarded Ads (AppLovin / AdMob)',
                                  style: TextStyle(
                                    color: NeonTheme.ink,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (_isVip) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'Instant VIP Skip',
                                  style: TextStyle(
                                    color: NeonTheme.lime,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: NeonTheme.s8),
                          Text(
                            _isVip
                                ? 'As a VIP, you earn full rewards instantly without watching any video ad.'
                                : 'Watch a short rewarded video ad to receive bonus game currency.',
                            style: TextStyle(color: NeonTheme.inkSoft),
                          ),
                          const SizedBox(height: 12),
                          CommonButton(
                            label:
                                _isVip
                                    ? 'Claim Free 50 Coins (VIP Skip)'
                                    : 'Watch Ad for +50 Coins',
                            onTap: _watchRewardedAd,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

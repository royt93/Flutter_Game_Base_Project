import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

/// In-app demo adapter when no native store adapter is registered.
// ponytail: fake purchase seam for example app, replace with in_app_purchase in production.
class _DefaultDemoPurchaseAdapter implements PurchaseSeam {
  final Set<String> _owned = {};
  int _orders = 0;

  /// The store's order id for the last successful [buy]. A real adapter must
  /// surface the store's own receipt/order id like this: it is what makes a
  /// redelivered purchase (restore, relaunch) credit once, not twice.
  String? lastReceiptId;

  @override
  Future<bool> buy(String productId) async {
    _owned.add(productId);
    lastReceiptId =
        'demo_order_${DateTime.now().microsecondsSinceEpoch}_${_orders++}';
    return true;
  }

  @override
  bool isOwned(String productId) => _owned.contains(productId);

  @override
  Future<void> restorePurchases() async {}
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
  late final EconomyWallet _wallet;
  late final RewardTransactionPipeline _rewards;
  final _haptics = HapticChoreographer();

  String _status = 'Browse store offers.';
  bool _actionInFlight = false;

  Future<void> _runMonetizationAction(Future<void> Function() action) async {
    if (_actionInFlight) return;
    setState(() => _actionInFlight = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        _haptics.play(HapticPattern.error);
        setState(() => _status = 'Action failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

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
    _wallet =
        EconomyWallet.maybe ??
        Get.put(EconomyWallet(storage: StorageService.to), permanent: true);
    _rewards =
        RewardTransactionPipeline.maybe ??
        Get.put(RewardTransactionPipeline(wallet: _wallet), permanent: true);
  }

  /// The store receipt for the purchase that just succeeded. An adapter that
  /// exposes none falls back to a per-tap id: unique, but it cannot dedupe a
  /// redelivery, so a production adapter must provide the real receipt.
  String _receiptFor(String sku) {
    final seam = _purchases;
    final receipt = seam is _DefaultDemoPurchaseAdapter
        ? seam.lastReceiptId
        : null;
    return receipt ?? 'demo_${sku}_${DateTime.now().microsecondsSinceEpoch}';
  }

  bool get _isVip => _ledger.owns(_vipSku);

  Future<void> _buyConsumable({
    required String sku,
    required String currency,
    required int amount,
    required String label,
  }) => _runMonetizationAction(() async {
    final success = await _purchases.buy(sku);
    if (!success) {
      _haptics.play(HapticPattern.error);
      if (!mounted) return;
      setState(() => _status = 'Purchase cancelled or failed.');
      return;
    }

    final grant = await _rewards.grantFromPurchase(
      receiptId: _receiptFor(sku),
      lines: [RewardLine(currency: currency, amount: amount)],
      receiptMeta: {'sku': sku},
    );
    if (!grant.isSuccess) {
      _haptics.play(HapticPattern.error);
      if (!mounted) return;
      setState(
        () => _status = 'Wallet could not be updated. Please try again.',
      );
      return;
    }

    _ledger.grantConsumable(sku, 1);
    _haptics.play(HapticPattern.reward);
    if (!mounted) return;
    setState(() => _status = 'Purchased $label! +$amount $currency.');
  });

  Future<void> _buyVip() => _runMonetizationAction(() async {
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
    setState(() => _status = 'Unlocked VIP Pass permanently!');
  });

  Future<void> _restorePurchases() => _runMonetizationAction(() async {
    await _purchases.restorePurchases();
    if (_purchases.isOwned(_vipSku)) {
      _ledger.grantPermanent(_vipSku);
    }
    _haptics.play(HapticPattern.reward);
    if (!mounted) return;
    setState(() => _status = 'Purchases restored successfully.');
  });

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
                                      color: _isVip
                                          ? NeonTheme.gold
                                          : NeonTheme.ink,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isVip ? 'VIP active' : 'Standard',
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
                              onTap: _actionInFlight
                                  ? null
                                  : () => _buyConsumable(
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
                              onTap: _actionInFlight
                                  ? null
                                  : () => _buyConsumable(
                                      sku: 'pack_gems_20',
                                      currency: 'gems',
                                      amount: 20,
                                      label: 'Handful of Gems',
                                    ),
                            ),
                          ),
                          const SizedBox(height: NeonTheme.s8),
                          CommonListTile(
                            title: 'VIP Pass',
                            subtitle: _isVip
                                ? 'Owned (Permanent unlock)'
                                : r'Permanent unlock • $2.99',
                            trailing: CommonButton(
                              width: 90,
                              label: _isVip ? 'Owned' : r'$2.99',
                              variant: _isVip
                                  ? CommonButtonVariant.secondary
                                  : CommonButtonVariant.primary,
                              onTap: _isVip || _actionInFlight ? null : _buyVip,
                            ),
                          ),
                          const SizedBox(height: 12),
                          CommonButton(
                            label: 'Restore Purchases',
                            variant: CommonButtonVariant.secondary,
                            onTap: _actionInFlight ? null : _restorePurchases,
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

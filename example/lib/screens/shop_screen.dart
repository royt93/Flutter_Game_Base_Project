import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:roy_casual_kit/roy_casual_kit.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  static const _catalog = {
    'potion': ItemDefinition(id: 'potion', maxStack: 99),
    'sword': ItemDefinition(id: 'sword', maxStack: 1, equippable: true),
    'skin_dragon': ItemDefinition(id: 'skin_dragon', maxStack: 1),
  };

  late final EconomyWallet _wallet;
  late final InventoryService _inventory;
  final _haptics = HapticChoreographer();
  String _status = 'Select an item to purchase.';

  @override
  void initState() {
    super.initState();
    if (StorageService.maybe == null) {
      Get.put(StorageService(null), permanent: true);
    }
    _wallet =
        EconomyWallet.maybe ??
        Get.put(EconomyWallet(storage: StorageService.to), permanent: true);
    _inventory =
        InventoryService.maybe ??
        Get.put(
          InventoryService(storage: StorageService.to, itemCatalog: _catalog),
          permanent: true,
        );
  }

  @override
  void dispose() {
    _haptics.cancel();
    super.dispose();
  }

  Future<void> _buyItem({
    required String itemId,
    required String currency,
    required int price,
    required String label,
  }) async {
    final currentBalance = _wallet.balanceOf(currency);
    if (currentBalance < price) {
      _haptics.play(HapticPattern.error);
      setState(() {
        _status = 'Not enough $currency (need $price, have $currentBalance).';
      });
      return;
    }

    final spendResult = await _wallet.trySpend(
      currency: currency,
      amount: price,
      transactionId:
          'shop_buy_${itemId}_${DateTime.now().microsecondsSinceEpoch}',
    );

    if (!spendResult.isSuccess) {
      _haptics.play(HapticPattern.error);
      setState(() {
        _status = 'Purchase failed.';
      });
      return;
    }

    await _inventory.grant(
      lines: [InventoryLine(itemId: itemId, quantity: 1)],
      transactionId:
          'shop_grant_${itemId}_${DateTime.now().microsecondsSinceEpoch}',
    );
    _haptics.play(HapticPattern.reward);

    if (!mounted) return;
    setState(() {
      _status = 'Bought $label for $price $currency!';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'shop'.tr, onBack: Get.back),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(NeonTheme.s16),
                  children: [
                    PanelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Obx(
                            () => Text(
                              'Wallet: coins ${_wallet.balanceOf('coins')} | gems ${_wallet.balanceOf('gems')}',
                              style: TextStyle(
                                color: NeonTheme.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: NeonTheme.s8),
                          Text(
                            _status,
                            style: TextStyle(color: NeonTheme.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: NeonTheme.s16),
                    PanelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Items for Sale',
                            style: TextStyle(
                              color: NeonTheme.ink,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: NeonTheme.s16),
                          Wrap(
                            spacing: NeonTheme.s8,
                            runSpacing: NeonTheme.s16,
                            alignment: WrapAlignment.spaceEvenly,
                            children: [
                              ShopItemCard(
                                icon: Icons.local_drink_rounded,
                                iconColor: NeonTheme.lime,
                                title: 'Health Potion',
                                priceLabel: '30 coins',
                                onBuy: () => _buyItem(
                                  itemId: 'potion',
                                  currency: 'coins',
                                  price: 30,
                                  label: 'Health Potion',
                                ),
                              ),
                              ShopItemCard(
                                icon: Icons.shield_rounded,
                                iconColor: NeonTheme.cyan,
                                title: 'Iron Sword',
                                priceLabel: '100 coins',
                                onBuy: () => _buyItem(
                                  itemId: 'sword',
                                  currency: 'coins',
                                  price: 100,
                                  label: 'Iron Sword',
                                ),
                              ),
                              ShopItemCard(
                                icon: Icons.auto_awesome_rounded,
                                iconColor: NeonTheme.gold,
                                title: 'Neon Dragon Skin',
                                priceLabel: '15 gems',
                                ribbonText: 'HOT',
                                ribbonColor: NeonTheme.magenta,
                                onBuy: () => _buyItem(
                                  itemId: 'skin_dragon',
                                  currency: 'gems',
                                  price: 15,
                                  label: 'Neon Dragon Skin',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: NeonTheme.s16),
                    PanelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Your Inventory',
                            style: TextStyle(
                              color: NeonTheme.ink,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: NeonTheme.s8),
                          Obx(() {
                            final slots = _inventory.snapshot.value.slots;
                            if (slots.isEmpty) {
                              return Text(
                                'Inventory is empty. Buy something above!',
                                style: TextStyle(color: NeonTheme.inkSoft),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final slot in slots)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '• ${slot.itemId} x${slot.quantity}',
                                      style: TextStyle(
                                        color: NeonTheme.ink,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }),
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

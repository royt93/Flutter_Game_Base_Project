import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/inventory_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/shop_item_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:roy_casual_kit_example/screens/shop_screen.dart';

Finder _button(String label) => find.widgetWithText(CommonButton, label);

Widget _wrap(Widget child) => GetMaterialApp(
  translations: AppTranslations(),
  locale: AppTranslations.fallback,
  fallbackLocale: AppTranslations.fallback,
  home: child,
);

Future<void> _boot() async {
  SharedPreferences.setMockInitialValues({});
  Get.put(
    StorageService(await SharedPreferences.getInstance()),
    permanent: true,
  );
}

void main() {
  tearDown(Get.reset);

  testWidgets('renders ShopScreen with wallet, items, empty inventory', (
    tester,
  ) async {
    await _boot();

    await tester.pumpWidget(_wrap(const ShopScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Shop'), findsWidgets);
    expect(find.textContaining('Wallet: coins 0 | gems 0'), findsOneWidget);
    expect(find.byType(ShopItemCard), findsNWidgets(3));
    expect(find.text('Health Potion'), findsOneWidget);
    expect(find.text('Iron Sword'), findsOneWidget);
    expect(find.text('Neon Dragon Skin'), findsOneWidget);
    expect(
      find.text('Inventory is empty. Buy something above!'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cannot buy item when insufficient funds', (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const ShopScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    final buyPotion = _button('30 coins').first;
    await tester.tap(buyPotion);
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.textContaining('Not enough coins (need 30, have 0)'),
      findsOneWidget,
    );
    expect(
      find.text('Inventory is empty. Buy something above!'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'successful buy deducts wallet balance and grants inventory item',
    (tester) async {
      await _boot();

      await tester.pumpWidget(_wrap(const ShopScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      final wallet = EconomyWallet.maybe!;
      await wallet.earn(currency: 'coins', amount: 50, transactionId: 'test_1');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Wallet: coins 50 | gems 0'), findsOneWidget);

      final buyPotion = _button('30 coins').first;
      await tester.tap(buyPotion);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Wallet: coins 20 | gems 0'), findsOneWidget);
      expect(
        find.textContaining('Bought Health Potion for 30 coins!'),
        findsOneWidget,
      );
      expect(find.text('• potion x1'), findsOneWidget);
      expect(InventoryService.maybe!.snapshot.value.quantityOf('potion'), 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('buy with gems deducts gems and grants skin', (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const ShopScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    final wallet = EconomyWallet.maybe!;
    await wallet.earn(currency: 'gems', amount: 20, transactionId: 'test_gems');
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Wallet: coins 0 | gems 20'), findsOneWidget);

    final buyDragon = _button('15 gems').first;
    await tester.tap(buyDragon);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Wallet: coins 0 | gems 5'), findsOneWidget);
    expect(
      find.textContaining('Bought Neon Dragon Skin for 15 gems!'),
      findsOneWidget,
    );
    expect(find.text('• skin_dragon x1'), findsOneWidget);
    expect(InventoryService.maybe!.snapshot.value.quantityOf('skin_dragon'), 1);
    expect(tester.takeException(), isNull);
  });
}

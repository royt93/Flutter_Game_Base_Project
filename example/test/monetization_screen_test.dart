import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/purchase_ledger_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit_example/screens/monetization_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder _button(String label) => find.byWidgetPredicate(
      (widget) => widget is CommonButton && widget.label == label,
    );

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

  testWidgets('renders MonetizationScreen with wallet, IAP packs, and ads',
      (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const MonetizationScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Store & Monetization'), findsWidgets);
    expect(find.text('Standard Player'), findsOneWidget);
    expect(find.text('Coins: 0 | Gems: 0'), findsOneWidget);
    expect(find.text('Pouch of Coins (+100 Coins)'), findsOneWidget);
    expect(find.text('Handful of Gems (+20 Gems)'), findsOneWidget);
    expect(find.text('VIP No-Ads Pass'), findsOneWidget);
    expect(_button(r'$0.99'), findsOneWidget);
    expect(_button(r'$1.99'), findsOneWidget);
    expect(_button(r'$2.99'), findsOneWidget);
    expect(_button('Restore Purchases'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('buying consumable pack credits currency and ledger',
      (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const MonetizationScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    final buyCoinsBtn = _button(r'$0.99').first;
    await tester.tap(buyCoinsBtn);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Coins: 100 | Gems: 0'), findsOneWidget);
    expect(
      find.textContaining('Purchased Pouch of Coins! +100 coins.'),
      findsOneWidget,
    );
    expect(PurchaseLedgerService.maybe!.balanceOf('pack_coins_100'), 1);

    final buyGemsBtn = _button(r'$1.99').first;
    await tester.tap(buyGemsBtn);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Coins: 100 | Gems: 20'), findsOneWidget);
    expect(
      find.textContaining('Purchased Handful of Gems! +20 gems.'),
      findsOneWidget,
    );
    expect(PurchaseLedgerService.maybe!.balanceOf('pack_gems_20'), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('buying VIP activates permanent VIP and instant ad skip',
      (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const MonetizationScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    final buyVipBtn = _button(r'$2.99').first;
    await tester.tap(buyVipBtn);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('VIP Member'), findsOneWidget);
    expect(find.text('No-Ads Active (Instant ad skip)'), findsOneWidget);
    expect(find.text('Owned'), findsOneWidget);
    expect(
      find.textContaining('Unlocked VIP No-Ads Pass permanently!'),
      findsOneWidget,
    );
    expect(PurchaseLedgerService.maybe!.owns('pack_vip_no_ads'), isTrue);

    // Watch Ad button changes to VIP Skip button and grants rewards instantly.
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    final vipAdBtn = _button('Claim Free 50 Coins (VIP Skip)').first;
    await tester.ensureVisible(vipAdBtn);
    await tester.tap(vipAdBtn);
    await tester.pump(const Duration(milliseconds: 500));

    expect(EconomyWallet.maybe!.balanceOf('coins'), 50);
    expect(
      find.textContaining('VIP Perk: Ad skipped! Received 50 coins.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('watching rewarded ad grants coins when not VIP', (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const MonetizationScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    final adBtn = _button('Watch Ad for +50 Coins').first;
    await tester.ensureVisible(adBtn);
    await tester.tap(adBtn);
    await tester.pump(const Duration(milliseconds: 500));

    expect(EconomyWallet.maybe!.balanceOf('coins'), 50);
    expect(find.textContaining('Watched ad! Received 50 coins.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restoring purchases succeeds', (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const MonetizationScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    final restoreBtn = _button('Restore Purchases').first;
    await tester.tap(restoreBtn);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.textContaining('Purchases restored successfully.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

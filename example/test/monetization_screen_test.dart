import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/ad_reward_seam.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/purchase_ledger_service.dart';
import 'package:roy_casual_kit/core/purchase_seam.dart';
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

class _ScriptedPurchases implements PurchaseSeam {
  _ScriptedPurchases({this.buySucceeds = true, Set<String>? owned})
    : _owned = owned ?? {};

  final bool buySucceeds;
  final Set<String> _owned;
  int restoreCalls = 0;

  @override
  Future<bool> buy(String productId) async => buySucceeds;

  @override
  bool isOwned(String productId) => _owned.contains(productId);

  @override
  Future<void> restorePurchases() async => restoreCalls++;
}

class _ScriptedAds implements AdRewardSeam {
  _ScriptedAds({required this.isReady, this.rewarded = true});

  @override
  final bool isReady;
  final bool rewarded;
  int shown = 0;

  @override
  Future<bool> showRewardedAd({String? placement}) async {
    shown++;
    return rewarded;
  }
}

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

  Future<void> scrollToAdButton(WidgetTester tester, String label) async {
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    final button = _button(label).first;
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('mua consumable thất bại: không cộng tiền, ledger giữ nguyên', (
    tester,
  ) async {
    await _boot();
    Get.put<PurchaseSeam>(_ScriptedPurchases(buySucceeds: false));

    await tester.pumpWidget(_wrap(const MonetizationScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(_button(r'$0.99').first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.textContaining('Purchase cancelled or failed.'),
      findsOneWidget,
    );
    expect(find.text('Coins: 0 | Gems: 0'), findsOneWidget);
    expect(PurchaseLedgerService.maybe!.balanceOf('pack_coins_100'), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mua VIP thất bại: vẫn là Standard Player, không sở hữu', (
    tester,
  ) async {
    await _boot();
    Get.put<PurchaseSeam>(_ScriptedPurchases(buySucceeds: false));

    await tester.pumpWidget(_wrap(const MonetizationScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(_button(r'$2.99').first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('VIP purchase cancelled.'), findsOneWidget);
    expect(find.text('Standard Player'), findsOneWidget);
    expect(PurchaseLedgerService.maybe!.owns('pack_vip_no_ads'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restore khôi phục VIP đã sở hữu ở store vào ledger', (
    tester,
  ) async {
    await _boot();
    final purchases = _ScriptedPurchases(owned: {'pack_vip_no_ads'});
    Get.put<PurchaseSeam>(purchases);

    await tester.pumpWidget(_wrap(const MonetizationScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Standard Player'), findsOneWidget);
    await tester.tap(_button('Restore Purchases').first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(purchases.restoreCalls, 1);
    expect(PurchaseLedgerService.maybe!.owns('pack_vip_no_ads'), isTrue);
    expect(find.text('VIP Member'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quảng cáo chưa sẵn sàng: không phát, không cộng coins', (
    tester,
  ) async {
    await _boot();
    final ads = _ScriptedAds(isReady: false);
    Get.put<AdRewardSeam>(ads);

    await tester.pumpWidget(_wrap(const MonetizationScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    await scrollToAdButton(tester, 'Watch Ad for +50 Coins');

    expect(ads.shown, 0);
    expect(
      find.textContaining('Ad is not ready yet. Please try again soon.'),
      findsOneWidget,
    );
    expect(EconomyWallet.maybe!.balanceOf('coins'), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('đóng quảng cáo trước khi xong: không thưởng', (tester) async {
    await _boot();
    final ads = _ScriptedAds(isReady: true, rewarded: false);
    Get.put<AdRewardSeam>(ads);

    await tester.pumpWidget(_wrap(const MonetizationScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    await scrollToAdButton(tester, 'Watch Ad for +50 Coins');

    expect(ads.shown, 1);
    expect(
      find.textContaining('Ad closed before completion. No reward earned.'),
      findsOneWidget,
    );
    expect(EconomyWallet.maybe!.balanceOf('coins'), 0);
    expect(tester.takeException(), isNull);
  });
}

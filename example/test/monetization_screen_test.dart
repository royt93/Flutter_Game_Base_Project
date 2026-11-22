import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/purchase_ledger_service.dart';
import 'package:roy_casual_kit/core/purchase_seam.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';
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
  _ScriptedPurchases({
    this.buySucceeds = true,
    this.onBuy,
    this.onRestore,
    Set<String>? owned,
  }) : _owned = owned ?? {};

  final bool buySucceeds;
  final Future<bool> Function(String productId)? onBuy;
  final Future<void> Function()? onRestore;
  final Set<String> _owned;
  int buyCalls = 0;
  int restoreCalls = 0;

  @override
  Future<bool> buy(String productId) {
    buyCalls++;
    return onBuy?.call(productId) ?? Future<bool>.value(buySucceeds);
  }

  @override
  bool isOwned(String productId) => _owned.contains(productId);

  @override
  Future<void> restorePurchases() {
    restoreCalls++;
    return onRestore?.call() ?? Future<void>.value();
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

  testWidgets('renders MonetizationScreen with wallet and IAP packs', (
    tester,
  ) async {
    await _boot();

    await tester.pumpWidget(_wrap(const MonetizationScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Store & Monetization'), findsWidgets);
    expect(find.text('Standard Player'), findsOneWidget);
    expect(find.text('Coins: 0 | Gems: 0'), findsOneWidget);
    expect(find.text('Pouch of Coins (+100 Coins)'), findsOneWidget);
    expect(find.text('Handful of Gems (+20 Gems)'), findsOneWidget);
    expect(find.text('VIP Pass'), findsOneWidget);
    expect(_button(r'$0.99'), findsOneWidget);
    expect(_button(r'$1.99'), findsOneWidget);
    expect(_button(r'$2.99'), findsOneWidget);
    expect(_button('Restore Purchases'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('buying consumable pack credits currency and ledger', (
    tester,
  ) async {
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

  testWidgets('buying VIP activates permanent VIP', (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const MonetizationScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    final buyVipBtn = _button(r'$2.99').first;
    await tester.tap(buyVipBtn);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('VIP Member'), findsOneWidget);
    expect(find.text('VIP active'), findsOneWidget);
    expect(find.text('Owned'), findsOneWidget);
    expect(
      find.textContaining('Unlocked VIP Pass permanently!'),
      findsOneWidget,
    );
    expect(PurchaseLedgerService.maybe!.owns('pack_vip_no_ads'), isTrue);

    expect(tester.takeException(), isNull);
  });

  testWidgets('provider buy exception shows safe error and releases guard', (
    tester,
  ) async {
    await _boot();
    var shouldThrow = true;
    final purchases = _ScriptedPurchases(
      onBuy: (_) async {
        if (shouldThrow) throw StateError('private provider details');
        return true;
      },
    );
    Get.put<PurchaseSeam>(purchases);

    await tester.pumpWidget(_wrap(const MonetizationScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(_button(r'$0.99').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Action failed. Please try again.'), findsOneWidget);
    expect(find.textContaining('private provider details'), findsNothing);
    expect(EconomyWallet.maybe!.balanceOf('coins'), 0);
    expect(PurchaseLedgerService.maybe!.balanceOf('pack_coins_100'), 0);
    expect(tester.takeException(), isNull);

    shouldThrow = false;
    await tester.tap(_button(r'$0.99').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(EconomyWallet.maybe!.balanceOf('coins'), 100);
    expect(PurchaseLedgerService.maybe!.balanceOf('pack_coins_100'), 1);
  });

  testWidgets(
    'concurrent consumable taps are ignored while provider is pending',
    (tester) async {
      await _boot();
      final pending = Completer<bool>();
      final purchases = _ScriptedPurchases(onBuy: (_) => pending.future);
      Get.put<PurchaseSeam>(purchases);

      await tester.pumpWidget(_wrap(const MonetizationScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      final button = _button(r'$0.99').first;
      await tester.tap(button);
      await tester.pump();

      expect(tester.widget<CommonButton>(button).onTap, isNull);
      expect(purchases.buyCalls, 1);
      pending.complete(true);
      await tester.pump(const Duration(milliseconds: 500));

      expect(EconomyWallet.maybe!.balanceOf('coins'), 100);
      expect(PurchaseLedgerService.maybe!.balanceOf('pack_coins_100'), 1);
    },
  );

  testWidgets(
    'concurrent VIP purchase taps are ignored while provider is pending',
    (tester) async {
      await _boot();
      final pending = Completer<bool>();
      final purchases = _ScriptedPurchases(onBuy: (_) => pending.future);
      Get.put<PurchaseSeam>(purchases);

      await tester.pumpWidget(_wrap(const MonetizationScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      final button = _button(r'$2.99').first;
      await tester.tap(button);
      await tester.pump();

      expect(tester.widget<CommonButton>(button).onTap, isNull);
      expect(purchases.buyCalls, 1);
      pending.complete(true);
      await tester.pump(const Duration(milliseconds: 500));
      expect(PurchaseLedgerService.maybe!.owns('pack_vip_no_ads'), isTrue);
      expect(purchases.buyCalls, 1);
    },
  );

  testWidgets('concurrent restore taps are ignored while provider is pending', (
    tester,
  ) async {
    await _boot();
    final pending = Completer<void>();
    final purchases = _ScriptedPurchases(
      owned: {'pack_vip_no_ads'},
      onRestore: () => pending.future,
    );
    Get.put<PurchaseSeam>(purchases);

    await tester.pumpWidget(_wrap(const MonetizationScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    final button = _button('Restore Purchases').first;
    await tester.tap(button);
    await tester.pump();

    expect(tester.widget<CommonButton>(button).onTap, isNull);
    expect(purchases.restoreCalls, 1);
    pending.complete();
    await tester.pump(const Duration(milliseconds: 500));
    expect(PurchaseLedgerService.maybe!.owns('pack_vip_no_ads'), isTrue);
    expect(purchases.restoreCalls, 1);
  });

  testWidgets(
    'restore provider exception shows safe error and releases guard',
    (tester) async {
      await _boot();
      var shouldThrow = true;
      final purchases = _ScriptedPurchases(
        onRestore: () async {
          if (shouldThrow) throw StateError('private restore details');
        },
      );
      Get.put<PurchaseSeam>(purchases);

      await tester.pumpWidget(_wrap(const MonetizationScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(_button('Restore Purchases').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Action failed. Please try again.'), findsOneWidget);
      expect(find.textContaining('private restore details'), findsNothing);
      expect(PurchaseLedgerService.maybe!.owns('pack_vip_no_ads'), isFalse);
      expect(tester.takeException(), isNull);

      shouldThrow = false;
      await tester.tap(_button('Restore Purchases').first);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.textContaining('Purchases restored successfully.'),
        findsOneWidget,
      );
    },
  );

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

  group('BUG-101: wallet earn failure consistency', () {
    testWidgets(
      'mua consumable khi wallet earn fail: không tăng ledger, không báo thành công',
      (tester) async {
        await _boot();
        Get.put<EconomyWallet>(_FailingWallet());

        await tester.pumpWidget(_wrap(const MonetizationScreen()));
        await tester.pump(const Duration(milliseconds: 500));

        final buyCoinsBtn = _button(r'$0.99').first;
        await tester.tap(buyCoinsBtn);
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.textContaining('Wallet could not be updated. Please try again.'),
          findsOneWidget,
        );
        expect(find.text('Coins: 0 | Gems: 0'), findsOneWidget);
        expect(find.textContaining('Purchased Pouch of Coins!'), findsNothing);
        expect(PurchaseLedgerService.maybe!.balanceOf('pack_coins_100'), 0);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _FailingWallet extends EconomyWallet {
  _FailingWallet() : super(storage: StorageService.to);

  @override
  Future<SdkResult<int>> earn({
    required String currency,
    required int amount,
    required String transactionId,
  }) async {
    return const SdkFailure(
      kind: SdkErrorKind.storage,
      message: 'Simulated wallet persist failure',
    );
  }
}

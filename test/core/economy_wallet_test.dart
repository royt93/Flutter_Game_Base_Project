import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/currency_counter.dart';

void main() {
  test(
    'earn/spend are atomic and idempotent under concurrent callbacks',
    () async {
      final wallet = EconomyWallet(storage: StorageService(null));
      await wallet.earn(currency: 'coin', amount: 10, transactionId: 'seed');
      final results = await Future.wait([
        wallet.trySpend(currency: 'coin', amount: 7, transactionId: 'a'),
        wallet.trySpend(currency: 'coin', amount: 7, transactionId: 'b'),
      ]);
      expect(wallet.balanceOf('coin'), 3);
      expect(results.where((r) => r.isSuccess).length, 1);
      await wallet.earn(currency: 'coin', amount: 5, transactionId: 'a');
      expect(wallet.balanceOf('coin'), 3);
    },
  );

  test(
    'rejects invalid/corrupt input without mutation and persists restart',
    () async {
      final storage = StorageService(null);
      await storage.setString('economy_wallet_v1', '{bad');
      final wallet = EconomyWallet(storage: storage)..onInit();
      expect(wallet.balanceOf('coin'), 0);
      expect(
        (await wallet.trySpend(
          currency: 'coin',
          amount: 1,
          transactionId: 'x',
        )).isSuccess,
        isFalse,
      );
      await wallet.earn(currency: 'coin', amount: 4, transactionId: 'ok');
      final restarted = EconomyWallet(storage: storage)..onInit();
      expect(restarted.balanceOf('coin'), 4);
    },
  );

  testWidgets('wallet balance renders through animated CurrencyCounter', (
    tester,
  ) async {
    final wallet = EconomyWallet(storage: StorageService(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Obx(
          () =>
              CurrencyCounter(value: wallet.balanceOf('coin'), compact: false),
        ),
      ),
    );
    await wallet.earn(currency: 'coin', amount: 8, transactionId: 'ui');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CurrencyCounter), findsOneWidget);
  });
}

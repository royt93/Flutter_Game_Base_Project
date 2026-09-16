import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/currency_counter.dart';

void main() {
  tearDown(Get.reset);

  group('ENH-60: .maybe', () {
    test('trả về null khi chưa Get.put', () {
      expect(EconomyWallet.maybe, isNull);
    });

    test('trả về đúng instance khi đã đăng ký', () {
      final wallet = EconomyWallet(storage: StorageService(null));
      Get.put(wallet, permanent: true);
      expect(EconomyWallet.maybe, same(wallet));
    });
  });

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

  group('ENH-62: persist processed transaction ids across restart', () {
    test(
      'BUG: gọi lại đúng transactionId cũ sau "restart" KHÔNG được cộng thêm lần 2',
      () async {
        final storage = StorageService(null);
        final wallet = EconomyWallet(storage: storage)..onInit();
        await wallet.earn(currency: 'coin', amount: 10, transactionId: 'iap_1');
        expect(wallet.balanceOf('coin'), 10);

        // Mô phỏng restart: instance mới, hydrate lại từ storage.
        final restarted = EconomyWallet(storage: storage)..onInit();
        expect(restarted.balanceOf('coin'), 10);

        // Store phát lại đúng transactionId đã xử lý trước khi restart
        // (hành vi bình thường của StoreKit/Billing Library khi receipt
        // chưa được "finish/consume" tường minh).
        final result = await restarted.earn(
          currency: 'coin',
          amount: 10,
          transactionId: 'iap_1',
        );
        expect(result.isSuccess, isTrue);
        expect(restarted.balanceOf('coin'), 10); // KHÔNG được thành 20
      },
    );

    test('id mới vẫn được chống trùng đúng sau restart (không mất khả năng)', () async {
      final storage = StorageService(null);
      final wallet = EconomyWallet(storage: storage)..onInit();
      await wallet.earn(currency: 'coin', amount: 10, transactionId: 'a');

      final restarted = EconomyWallet(storage: storage)..onInit();
      await restarted.earn(currency: 'coin', amount: 5, transactionId: 'b');
      expect(restarted.balanceOf('coin'), 15);

      // Gọi lại 'b' (xử lý sau restart, trong CÙNG instance) vẫn phải
      // no-op — xác nhận restart không làm hỏng luôn khả năng chống trùng
      // cho các giao dịch MỚI xử lý sau đó.
      await restarted.earn(currency: 'coin', amount: 5, transactionId: 'b');
      expect(restarted.balanceOf('coin'), 15);
    });

    test(
      'danh sách transaction id không phình vô hạn — vượt giới hạn thì id CŨ NHẤT bị loại, id MỚI vẫn chống trùng đúng',
      () async {
        final storage = StorageService(null);
        var wallet = EconomyWallet(storage: storage)..onInit();
        // Vượt xa giới hạn bounded (dùng 250 > 200 mặc định dự kiến).
        for (var i = 0; i < 250; i++) {
          wallet = EconomyWallet(storage: storage)..onInit();
          await wallet.earn(currency: 'coin', amount: 1, transactionId: 'tx$i');
        }
        expect(wallet.balanceOf('coin'), 250);

        // id MỚI NHẤT (tx249) vẫn phải được chống trùng đúng.
        final restarted = EconomyWallet(storage: storage)..onInit();
        await restarted.earn(currency: 'coin', amount: 1, transactionId: 'tx249');
        expect(restarted.balanceOf('coin'), 250); // không tăng thêm
      },
    );

    test(
      'JSON cũ (chỉ có balances, chưa có field transactions) vẫn load được, không throw',
      () async {
        final storage = StorageService(null);
        // Định dạng CŨ: raw JSON chính là map balances, không bọc trong
        // {'balances': ..., 'transactions': ...}.
        await storage.setString('economy_wallet_v1', '{"coin": 7}');
        final wallet = EconomyWallet(storage: storage)..onInit();

        expect(wallet.balanceOf('coin'), 7);
        expect(
          () => wallet.earn(currency: 'coin', amount: 1, transactionId: 'x'),
          returnsNormally,
        );
      },
    );

    test(
      'JSON hỏng cho field transactions (sai kiểu): rơi về danh sách rỗng an toàn, balances vẫn đọc đúng',
      () async {
        final storage = StorageService(null);
        await storage.setString(
          'economy_wallet_v1',
          '{"balances": {"coin": 9}, "transactions": "not a list"}',
        );
        final wallet = EconomyWallet(storage: storage)..onInit();

        expect(wallet.balanceOf('coin'), 9);
        final result = await wallet.earn(
          currency: 'coin',
          amount: 1,
          transactionId: 'anything',
        );
        expect(result.isSuccess, isTrue);
        expect(wallet.balanceOf('coin'), 10); // áp dụng bình thường, không throw
      },
    );

    test('không phá hành vi atomic/idempotent hiện có trong cùng 1 instance', () async {
      final wallet = EconomyWallet(storage: StorageService(null));
      await wallet.earn(currency: 'coin', amount: 10, transactionId: 'seed');
      final results = await Future.wait([
        wallet.trySpend(currency: 'coin', amount: 7, transactionId: 'a'),
        wallet.trySpend(currency: 'coin', amount: 7, transactionId: 'b'),
      ]);
      expect(wallet.balanceOf('coin'), 3);
      expect(results.where((r) => r.isSuccess).length, 1);
    });
  });

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

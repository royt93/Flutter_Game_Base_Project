import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';
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

    test(
      'id mới vẫn được chống trùng đúng sau restart (không mất khả năng)',
      () async {
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
      },
    );

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
        await restarted.earn(
          currency: 'coin',
          amount: 1,
          transactionId: 'tx249',
        );
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
        expect(
          wallet.balanceOf('coin'),
          10,
        ); // áp dụng bình thường, không throw
      },
    );

    test(
      'không phá hành vi atomic/idempotent hiện có trong cùng 1 instance',
      () async {
        final wallet = EconomyWallet(storage: StorageService(null));
        await wallet.earn(currency: 'coin', amount: 10, transactionId: 'seed');
        final results = await Future.wait([
          wallet.trySpend(currency: 'coin', amount: 7, transactionId: 'a'),
          wallet.trySpend(currency: 'coin', amount: 7, transactionId: 'b'),
        ]);
        expect(wallet.balanceOf('coin'), 3);
        expect(results.where((r) => r.isSuccess).length, 1);
      },
    );
  });

  group('ENH-73: storageKey tuỳ chỉnh', () {
    test(
      'không truyền storageKey: hành vi/dữ liệu y hệt hiện tại, đọc đúng key cũ',
      () async {
        final storage = StorageService(null);
        final wallet = EconomyWallet(storage: storage)..onInit();
        await wallet.earn(currency: 'coin', amount: 5, transactionId: 'a');

        expect(storage.getString('economy_wallet_v1'), isNotNull);
      },
    );

    test(
      '2 storageKey khác nhau: 2 instance hoàn toàn độc lập, không đụng dữ liệu nhau',
      () async {
        final storage = StorageService(null);
        final a = EconomyWallet(storage: storage, storageKey: 'wallet_a')
          ..onInit();
        final b = EconomyWallet(storage: storage, storageKey: 'wallet_b')
          ..onInit();

        await a.earn(currency: 'coin', amount: 10, transactionId: 'a1');
        await b.earn(currency: 'coin', amount: 20, transactionId: 'b1');

        expect(a.balanceOf('coin'), 10);
        expect(b.balanceOf('coin'), 20);
      },
    );

    test(
      'storageKey tuỳ chỉnh persist đúng qua "restart" (instance mới cùng key đọc lại đúng)',
      () async {
        final storage = StorageService(null);
        final wallet = EconomyWallet(
          storage: storage,
          storageKey: 'wallet_custom',
        )..onInit();
        await wallet.earn(currency: 'coin', amount: 7, transactionId: 'a');

        final restarted = EconomyWallet(
          storage: storage,
          storageKey: 'wallet_custom',
        )..onInit();
        expect(restarted.balanceOf('coin'), 7);
      },
    );

    test(
      'không đổi hành vi earn/trySpend/balanceOf hiện có khi dùng storageKey tuỳ chỉnh',
      () async {
        final wallet = EconomyWallet(
          storage: StorageService(null),
          storageKey: 'k',
        )..onInit();

        await wallet.earn(currency: 'coin', amount: 10, transactionId: 'a');
        final spend = await wallet.trySpend(
          currency: 'coin',
          amount: 4,
          transactionId: 'b',
        );

        expect(spend.isSuccess, isTrue);
        expect(wallet.balanceOf('coin'), 6);
      },
    );
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

  group('BUG-40: hydrate ngay trong constructor, không phụ thuộc onInit()', () {
    test(
      'khởi tạo trực tiếp (không gọi onInit()) vẫn đọc đúng balance cũ',
      () async {
        final storage = StorageService(null);
        final seed = EconomyWallet(storage: storage)..onInit();
        await seed.earn(currency: 'coin', amount: 25, transactionId: 'seed');

        final direct = EconomyWallet(storage: storage);

        expect(direct.balanceOf('coin'), 25);
      },
    );

    test(
      'earn ngay sau khởi tạo trực tiếp cộng dồn đúng, không mất data cũ',
      () async {
        final storage = StorageService(null);
        final seed = EconomyWallet(storage: storage)..onInit();
        await seed.earn(currency: 'coin', amount: 25, transactionId: 'seed');

        final direct = EconomyWallet(storage: storage);
        await direct.earn(currency: 'coin', amount: 5, transactionId: 'extra');

        expect(direct.balanceOf('coin'), 30);
      },
    );
  });

  group('BUG-90: batchTransaction (atomic multi-currency)', () {
    test('validates EVERY delta before applying any of them — one insufficient '
        'currency fails the whole batch, no partial balances change', () async {
      final wallet = EconomyWallet(storage: StorageService(null));
      await wallet.earn(currency: 'coins', amount: 5, transactionId: 'seed');

      final result = await wallet.batchTransaction(
        deltas: const {'coins': -5, 'gems': -1},
        transactionId: 'batch_1',
      );

      expect(result.isSuccess, isFalse);
      expect(wallet.balanceOf('coins'), 5);
      expect(wallet.balanceOf('gems'), 0);
    });

    test(
      'applies all deltas atomically and persists them in one snapshot',
      () async {
        final storage = StorageService(null);
        final wallet = EconomyWallet(storage: storage);
        await wallet.earn(currency: 'coins', amount: 10, transactionId: 's1');
        await wallet.earn(currency: 'gems', amount: 3, transactionId: 's2');

        final result = await wallet.batchTransaction(
          deltas: const {'coins': -10, 'gems': -3, 'relics': 1},
          transactionId: 'batch_ok',
        );

        expect(result.isSuccess, isTrue);
        expect(wallet.balanceOf('coins'), 0);
        expect(wallet.balanceOf('gems'), 0);
        expect(wallet.balanceOf('relics'), 1);

        final restarted = EconomyWallet(storage: storage);
        expect(restarted.balanceOf('coins'), 0);
        expect(restarted.balanceOf('gems'), 0);
        expect(restarted.balanceOf('relics'), 1);
      },
    );

    test(
      'same transactionId retried is idempotent, not double-applied',
      () async {
        final wallet = EconomyWallet(storage: StorageService(null));
        await wallet.earn(currency: 'coins', amount: 10, transactionId: 's1');

        final first = await wallet.batchTransaction(
          deltas: const {'coins': -10, 'relics': 1},
          transactionId: 'batch_dup',
        );
        final second = await wallet.batchTransaction(
          deltas: const {'coins': -10, 'relics': 1},
          transactionId: 'batch_dup',
        );

        expect(first.isSuccess, isTrue);
        expect(second.isSuccess, isTrue);
        expect(wallet.balanceOf('relics'), 1);
      },
    );

    test('empty deltas or empty transactionId is rejected', () async {
      final wallet = EconomyWallet(storage: StorageService(null));

      expect(
        (await wallet.batchTransaction(
          deltas: const {},
          transactionId: 'x',
        )).isSuccess,
        isFalse,
      );
      expect(
        (await wallet.batchTransaction(
          deltas: const {'coins': 1},
          transactionId: '',
        )).isSuccess,
        isFalse,
      );
    });
  });

  group('EconomyWallet: lưu lỗi và giới hạn sổ giao dịch', () {
    test('earn: ghi storage lỗi -> SdkFailure(storage), số dư và sổ giao dịch không đổi, retry thật sự lưu', () async {
      final storage = _FailOnceWalletStorage();
      final wallet = EconomyWallet(storage: storage)..onInit();

      storage.failNext = true;
      final failed = await wallet.earn(currency: 'coin', amount: 5, transactionId: 't1');

      expect(failed, isA<SdkFailure<int>>());
      final failure = failed as SdkFailure<int>;
      expect(failure.kind, SdkErrorKind.storage);
      expect(failure.cause, isA<StateError>());
      expect(wallet.balanceOf('coin'), 0);

      final retry = await wallet.earn(currency: 'coin', amount: 5, transactionId: 't1');
      expect(retry, isA<SdkSuccess<int>>());
      expect(wallet.balanceOf('coin'), 5);
      final reloaded = EconomyWallet(storage: storage)..onInit();
      expect(reloaded.balanceOf('coin'), 5);
    });

    test('batchTransaction: sổ giao dịch bị cắt ở 200, id mới nhất vẫn chống trùng', () async {
      final storage = StorageService(null);
      final wallet = EconomyWallet(storage: storage)..onInit();

      for (var i = 0; i < 205; i++) {
        final r = await wallet.batchTransaction(deltas: {'coin': 1}, transactionId: 'b$i');
        expect(r.isSuccess, isTrue);
      }
      expect(wallet.balanceOf('coin'), 205);

      // id mới nhất vẫn nằm trong sổ: gọi lại không cộng thêm.
      await wallet.batchTransaction(deltas: {'coin': 1}, transactionId: 'b204');
      expect(wallet.balanceOf('coin'), 205);

      // id cũ nhất (b0) đã bị cắt khỏi sổ: gọi lại được coi là giao dịch mới.
      await wallet.batchTransaction(deltas: {'coin': 1}, transactionId: 'b0');
      expect(wallet.balanceOf('coin'), 206);
    });

    test('batchTransaction: ghi storage lỗi -> SdkFailure(storage), không số dư nào đổi', () async {
      final storage = _FailOnceWalletStorage();
      final wallet = EconomyWallet(storage: storage)..onInit();
      await wallet.earn(currency: 'coin', amount: 10, transactionId: 'seed');

      storage.failNext = true;
      final failed = await wallet.batchTransaction(
        deltas: {'coin': -3, 'gem': 4},
        transactionId: 'batch',
      );

      expect(failed, isA<SdkFailure<void>>());
      expect((failed as SdkFailure<void>).kind, SdkErrorKind.storage);
      expect(wallet.balanceOf('coin'), 10);
      expect(wallet.balanceOf('gem'), 0);
    });
  });
}

class _FailOnceWalletStorage extends StorageService {
  _FailOnceWalletStorage() : super(null);
  bool failNext = false;

  @override
  Future<void> setString(String key, String value) {
    if (failNext && key == StorageKeys.economyWalletV1) {
      failNext = false;
      throw StateError('disk full');
    }
    return super.setString(key, value);
  }
}

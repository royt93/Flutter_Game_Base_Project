import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/prestige_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';

void main() {
  group('PrestigeService.canPrestige', () {
    test('dưới ngưỡng -> false', () async {
      final wallet = EconomyWallet(storage: StorageService(null));
      await wallet.earn(currency: 'coins', amount: 500, transactionId: 't1');
      final prestige = PrestigeService(wallet: wallet, prestigeThreshold: 1000);

      expect(prestige.canPrestige(), isFalse);
    });

    test('đúng bằng ngưỡng -> true', () async {
      final wallet = EconomyWallet(storage: StorageService(null));
      await wallet.earn(currency: 'coins', amount: 1000, transactionId: 't1');
      final prestige = PrestigeService(wallet: wallet, prestigeThreshold: 1000);

      expect(prestige.canPrestige(), isTrue);
    });

    test('vượt ngưỡng -> true', () async {
      final wallet = EconomyWallet(storage: StorageService(null));
      await wallet.earn(currency: 'coins', amount: 5000, transactionId: 't1');
      final prestige = PrestigeService(wallet: wallet, prestigeThreshold: 1000);

      expect(prestige.canPrestige(), isTrue);
    });
  });

  group('PrestigeService.currentMultiplier', () {
    test('chưa từng prestige (0 relics) -> multiplier = 1', () {
      final wallet = EconomyWallet(storage: StorageService(null));
      final prestige = PrestigeService(wallet: wallet);

      expect(prestige.currentMultiplier, 1.0);
    });

    test(
      'đúng bằng prestigeMultiplier(relics: wallet.balanceOf(metaCurrency), ...)',
      () async {
        final wallet = EconomyWallet(storage: StorageService(null));
        await wallet.earn(currency: 'relics', amount: 5, transactionId: 't1');
        final prestige = PrestigeService(wallet: wallet, bonusPerRelic: 0.2);

        expect(prestige.currentMultiplier, 2.0); // 1 + 5*0.2
      },
    );
  });

  group('PrestigeService.prestige', () {
    test(
      'dưới ngưỡng -> SdkFailure(validation), KHÔNG đổi gì (không soft-reset, '
      'không cộng relic)',
      () async {
        final wallet = EconomyWallet(storage: StorageService(null));
        await wallet.earn(currency: 'coins', amount: 500, transactionId: 't1');
        final prestige = PrestigeService(wallet: wallet, prestigeThreshold: 1000);

        final result = await prestige.prestige();

        expect(result, isA<SdkFailure<int>>());
        expect(wallet.balanceOf('coins'), 500);
        expect(wallet.balanceOf('relics'), 0);
      },
    );

    test(
      'đủ ngưỡng -> soft-reset đúng coins về 0, cộng đúng relicsPerPrestige, '
      'trả về SdkSuccess với balance relics mới',
      () async {
        final wallet = EconomyWallet(storage: StorageService(null));
        await wallet.earn(currency: 'coins', amount: 1500, transactionId: 't1');
        final prestige = PrestigeService(
          wallet: wallet,
          prestigeThreshold: 1000,
          relicsPerPrestige: 3,
        );

        final result = await prestige.prestige();

        expect(result, isA<SdkSuccess<int>>());
        expect((result as SdkSuccess<int>).value, 3);
        expect(wallet.balanceOf('coins'), 0);
        expect(wallet.balanceOf('relics'), 3);
      },
    );

    test(
      'prestige 2 lần liên tiếp -> relics CỘNG DỒN (không ghi đè), '
      'currentMultiplier tăng theo đúng',
      () async {
        final wallet = EconomyWallet(storage: StorageService(null));
        await wallet.earn(currency: 'coins', amount: 2000, transactionId: 't1');
        final prestige = PrestigeService(
          wallet: wallet,
          prestigeThreshold: 1000,
          bonusPerRelic: 0.1,
        );

        await prestige.prestige();
        expect(prestige.currentMultiplier, 1.1); // 1 relic

        await wallet.earn(currency: 'coins', amount: 2000, transactionId: 't2');
        await prestige.prestige();

        expect(wallet.balanceOf('relics'), 2);
        expect(prestige.currentMultiplier, 1.2);
      },
    );

    test(
      'không mất/nhân đôi dữ liệu: 2 lần gọi prestige() liên tiếp (mỗi lần '
      'tự sinh transactionId riêng) không bao giờ trùng id, không bị coi '
      'là trùng lặp rồi bỏ qua',
      () async {
        final wallet = EconomyWallet(storage: StorageService(null));
        await wallet.earn(currency: 'coins', amount: 1000, transactionId: 't1');
        final prestige = PrestigeService(wallet: wallet, prestigeThreshold: 1000);

        await prestige.prestige();
        await wallet.earn(currency: 'coins', amount: 1000, transactionId: 't2');
        await prestige.prestige();

        // 2 relic thật (không phải 1 do bị coi trùng transactionId).
        expect(wallet.balanceOf('relics'), 2);
      },
    );

    test(
      'softResetCurrencies tuỳ chỉnh: chỉ reset đúng currency được liệt kê, '
      'currency khác giữ nguyên',
      () async {
        final wallet = EconomyWallet(storage: StorageService(null));
        await wallet.earn(currency: 'coins', amount: 1000, transactionId: 't1');
        await wallet.earn(currency: 'gems', amount: 50, transactionId: 't2');
        final prestige = PrestigeService(
          wallet: wallet,
          prestigeThreshold: 1000,
          softResetCurrencies: const {'coins'},
        );

        await prestige.prestige();

        expect(wallet.balanceOf('coins'), 0);
        expect(wallet.balanceOf('gems'), 50, reason: 'gems không nằm trong softResetCurrencies');
      },
    );

    test(
      'coins đã là 0 sẵn (currency khác trong softResetCurrencies) -> '
      'không throw, vẫn cộng relic bình thường',
      () async {
        final wallet = EconomyWallet(storage: StorageService(null));
        await wallet.earn(currency: 'gems', amount: 1000, transactionId: 't1');
        final prestige = PrestigeService(
          wallet: wallet,
          primaryCurrency: 'gems',
          prestigeThreshold: 1000,
          softResetCurrencies: const {'coins'}, // coins vẫn 0 từ đầu.
        );

        final result = await prestige.prestige();

        expect(result, isA<SdkSuccess<int>>());
        expect(wallet.balanceOf('coins'), 0);
      },
    );
  });

  group('PrestigeService: cấu hình sai (assert)', () {
    test('metaCurrency trùng 1 phần tử trong softResetCurrencies -> assert', () {
      final wallet = EconomyWallet(storage: StorageService(null));

      expect(
        () => PrestigeService(
          wallet: wallet,
          metaCurrency: 'relics',
          softResetCurrencies: const {'coins', 'relics'},
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

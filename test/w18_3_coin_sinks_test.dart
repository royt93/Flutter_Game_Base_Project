import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// W18.3 — coin-sink: nâng cấp booster vĩnh viễn (Búa 3×3, +Lượt 15).
/// Test: trừ xu đúng, persist, idempotent, áp đúng hiệu lực, resetProgress sạch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController g;

  Future<void> boot([Map<String, Object>? seed]) async {
    SharedPreferences.setMockInitialValues(seed ?? {});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
    g = Get.put(GameController());
  }

  setUp(() => boot());
  tearDown(Get.reset);

  group('Nâng cấp Búa (3×3)', () {
    test('mua: trừ xu đúng + bật cờ', () {
      g.coins.value = kUpgradeHammerPrice + 100;
      expect(g.hammerUpgraded.value, isFalse);
      expect(g.buyUpgradeHammer(), isTrue);
      expect(g.hammerUpgraded.value, isTrue);
      expect(g.coins.value, 100);
    });

    test('thiếu xu → không mua', () {
      g.coins.value = kUpgradeHammerPrice - 1;
      expect(g.buyUpgradeHammer(), isFalse);
      expect(g.hammerUpgraded.value, isFalse);
      expect(g.coins.value, kUpgradeHammerPrice - 1);
    });

    test('mua 1 lần (idempotent) — không trừ xu lần 2', () {
      g.coins.value = kUpgradeHammerPrice * 3;
      expect(g.buyUpgradeHammer(), isTrue);
      final after = g.coins.value;
      expect(g.buyUpgradeHammer(), isFalse);
      expect(g.coins.value, after);
    });

    test('persist: reload vẫn nâng cấp', () async {
      g.coins.value = kUpgradeHammerPrice;
      g.buyUpgradeHammer();
      await boot({StorageKeys.upgHammer: 1});
      expect(g.hammerUpgraded.value, isTrue);
    });
  });

  group('Nâng cấp +Lượt (10 → 15)', () {
    test('mua: trừ xu + bật cờ', () {
      g.coins.value = kUpgradeMovesPrice;
      expect(g.buyUpgradeMoves(), isTrue);
      expect(g.movesUpgraded.value, isTrue);
      expect(g.coins.value, 0);
    });

    test('useMovesBooster: +10 khi chưa nâng, +15 sau khi nâng', () {
      g.startLevel(1);
      g.boosterMoves.value = 5;
      final base = g.movesLeft.value;
      // chưa nâng → +10
      expect(g.useMovesBooster(), isTrue);
      expect(g.movesLeft.value, base + 10);
      // nâng cấp → +15
      g.coins.value = kUpgradeMovesPrice;
      g.buyUpgradeMoves();
      final base2 = g.movesLeft.value;
      expect(g.useMovesBooster(), isTrue);
      expect(g.movesLeft.value, base2 + kMovesUpgradedBonus);
      expect(kMovesUpgradedBonus, 15);
    });

    test('hết booster → useMovesBooster false (không cộng lượt)', () {
      g.startLevel(1);
      g.boosterMoves.value = 0;
      final base = g.movesLeft.value;
      expect(g.useMovesBooster(), isFalse);
      expect(g.movesLeft.value, base);
    });
  });

  group('Hai nâng cấp cùng lúc (độc lập)', () {
    test('mua cả 2 → xu trừ đúng, 2 cờ đều bật, movesBooster+15', () {
      g.startLevel(1);
      g.coins.value = kUpgradeHammerPrice + kUpgradeMovesPrice + 50;
      expect(g.buyUpgradeHammer(), isTrue);
      expect(g.buyUpgradeMoves(), isTrue);
      expect(g.hammerUpgraded.value, isTrue);
      expect(g.movesUpgraded.value, isTrue);
      expect(g.coins.value, 50);
      // kiểm tra movesBooster áp đúng với cả 2 upgrade cùng tồn tại
      g.boosterMoves.value = 1;
      final base = g.movesLeft.value;
      expect(g.useMovesBooster(), isTrue);
      expect(g.movesLeft.value, base + kMovesUpgradedBonus);
    });

    test('useMovesBooster=0 + movesUpgraded=true → false (không cộng lượt)', () {
      g.startLevel(1);
      g.coins.value = kUpgradeMovesPrice;
      g.buyUpgradeMoves();
      g.boosterMoves.value = 0;
      final base = g.movesLeft.value;
      expect(g.useMovesBooster(), isFalse);
      expect(g.movesLeft.value, base);
    });
  });

  group('spendCoins (helper sink)', () {
    test('trừ đúng, không âm, clamp', () {
      g.coins.value = 100;
      expect(g.spendCoins(40), isTrue);
      expect(g.coins.value, 60);
      expect(g.spendCoins(1000), isFalse, reason: 'không đủ → không trừ');
      expect(g.coins.value, 60);
      expect(g.spendCoins(0), isFalse);
      expect(g.spendCoins(-5), isFalse);
    });
  });

  group('resetProgress xoá nâng cấp', () {
    test('reset → cờ nâng cấp về false + đĩa sạch', () async {
      g.coins.value = kUpgradeHammerPrice + kUpgradeMovesPrice;
      g.buyUpgradeHammer();
      g.buyUpgradeMoves();
      expect(g.hammerUpgraded.value, isTrue);
      expect(g.movesUpgraded.value, isTrue);

      await g.resetProgress();
      expect(g.hammerUpgraded.value, isFalse);
      expect(g.movesUpgraded.value, isFalse);
      expect(StorageService.to.getInt(StorageKeys.upgHammer), 0);
      expect(StorageService.to.getInt(StorageKeys.upgMoves), 0);
    });
  });
}

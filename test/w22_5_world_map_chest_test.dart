import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 22.5 — World Map rương báu: vị trí, thưởng tất định, mở khoá, anti-exploit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController g;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs));
    g = Get.put(GameController());
  });
  tearDown(Get.reset);

  group('chestLevelOf — xử lý cả thế giới không đều', () {
    test('TG1=10, TG8=145, TG10=185', () {
      expect(chestLevelOf(kWorlds[0]), 10); // 1..20
      expect(chestLevelOf(kWorlds[7]), 145); // 141..150
      expect(chestLevelOf(kWorlds[9]), 185); // 171..200
    });
    test('kChestLevels = 1 rương / thế giới', () {
      expect(kChestLevels.length, kWorlds.length);
    });
  });

  group('chestCoinReward — tất định + dải hợp lý', () {
    test('cùng world → cùng thưởng (no Random), ~50..250', () {
      for (final w in kWorlds) {
        final r = chestCoinReward(w.index);
        expect(r, chestCoinReward(w.index));
        expect(r, greaterThanOrEqualTo(50));
        expect(r, lessThanOrEqualTo(250));
      }
    });
  });

  group('mở khoá + nhận (anti-exploit)', () {
    test('chưa hoàn thành 80% → khoá, claim trả 0', () {
      final w = kWorlds[0]; // 1..20
      expect(g.isChestUnlocked(w), isFalse);
      expect(g.claimWorldChest(w), 0);
      expect(g.isChestClaimed(w.index), isFalse);
    });

    test('đạt 80% → mở; claim 1 lần cộng xu, lần 2 trả 0 (idempotent)', () {
      final w = kWorlds[0]; // size 20 → cần 16 màn xong (unlockedLevel>16)
      g.unlockedLevel.value = 17; // màn 1..16 đã xong
      expect(g.isChestUnlocked(w), isTrue);

      final before = g.coins.value;
      final reward = g.claimWorldChest(w);
      expect(reward, greaterThan(0));
      expect(reward, chestCoinReward(w.index));
      expect(g.coins.value, before + reward);
      expect(g.isChestClaimed(w.index), isTrue);

      // claim lại → 0, xu không đổi (chống farm reload)
      final coins2 = g.coins.value;
      expect(g.claimWorldChest(w), 0);
      expect(g.coins.value, coins2);
    });
  });

  test(
    'resetProgress xoá chest claimed → nhận lại được sau khi đủ điều kiện',
    () async {
      final w = kWorlds[0];
      g.unlockedLevel.value = 20;
      g.claimWorldChest(w);
      expect(g.isChestClaimed(w.index), isTrue);

      await g.resetProgress();
      expect(g.isChestClaimed(w.index), isFalse);
    },
  );
}

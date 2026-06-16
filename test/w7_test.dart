import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/temple.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/temple_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController g;
  late TempleController t;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs));
    g = Get.put(GameController());
    t = Get.put(TempleController(g));
  });

  tearDown(Get.reset);

  group('Coin economy (Wave 9 — 1 tiền tệ)', () {
    test('spendCoins trừ đúng; chặn khi thiếu / số không hợp lệ', () {
      g.addCoins(100);
      final before = g.coins.value;
      expect(g.spendCoins(40), isTrue);
      expect(g.coins.value, before - 40);
      expect(g.spendCoins(999999999), isFalse); // thiếu
      expect(g.coins.value, before - 40); // không đổi
      expect(g.spendCoins(0), isFalse); // số không hợp lệ
    });

    test('coins clamp dưới trần int32 (chống overflow)', () {
      g.addCoins(GameController.maxCoins);
      g.addCoins(1000);
      expect(g.coins.value, GameController.maxCoins);
    });

    test('migrate shard cũ → xu ×10, chạy 1 lần', () async {
      SharedPreferences.setMockInitialValues({'shards': 7, 'coins': 100});
      Get.reset();
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs));
      final g2 = Get.put(GameController());
      expect(g2.coins.value, 100 + 70); // 7 shard × 10
      expect(prefs.getInt(StorageKeys.shards), 0); // đã tiêu hết shard cũ
      expect(prefs.getInt(StorageKeys.shardsMigrated), 1);
    });

    test('không migrate lần 2 (đã đánh dấu)', () async {
      SharedPreferences.setMockInitialValues(
          {'shards': 5, 'coins': 50, 'shards_migrated': 1});
      Get.reset();
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs));
      final g2 = Get.put(GameController());
      expect(g2.coins.value, 50); // KHÔNG cộng lại
    });
  });

  group('Temple build (tiêu xu)', () {
    test('khởi tạo tier = 0 cho mọi hạng mục', () {
      for (final n in kTempleNodes) {
        expect(t.tierOf(n), 0);
      }
      expect(t.builtCount, 0);
      expect(t.progress, 0);
    });

    test('build trừ XU, tier++, thưởng xu, persist', () {
      final gate = kTempleNodes.firstWhere((e) => e.id == 'gate');
      final tier0 = gate.tiers[0];
      g.addCoins(tier0.cost); // đủ xu để xây
      final coins0 = g.coins.value;

      expect(t.build(gate), isTrue);
      expect(t.tierOf(gate), 1);
      // xu = coins0 - cost (đã trừ) + rewardCoins (thưởng)
      expect(g.coins.value, coins0 - tier0.cost + tier0.rewardCoins);
      expect(StorageService.to.getInt(StorageKeys.templeTier('gate')), 1);
    });

    test('chặn build khi thiếu xu', () {
      final gate = kTempleNodes.firstWhere((e) => e.id == 'gate');
      g.spendCoins(g.coins.value); // vét sạch xu
      expect(g.coins.value, 0);
      expect(t.canBuild(gate), isFalse);
      expect(t.build(gate), isFalse);
      expect(t.tierOf(gate), 0);
    });

    test('không vượt max tier; isMaxed đúng', () {
      final gate = kTempleNodes.firstWhere((e) => e.id == 'gate');
      g.addCoins(1000000); // dư xu
      for (var i = 0; i < gate.maxTier; i++) {
        expect(t.build(gate), isTrue);
      }
      expect(t.tierOf(gate), gate.maxTier);
      expect(t.isMaxed(gate), isTrue);
      expect(t.nextTier(gate), isNull);
      expect(t.build(gate), isFalse); // đã max → không xây thêm
    });

    test('progress phản ánh tổng tier đã xây', () {
      g.addCoins(1000000);
      final gate = kTempleNodes.firstWhere((e) => e.id == 'gate');
      t.build(gate);
      expect(t.builtCount, 1);
      expect(t.progress, closeTo(1 / t.totalCount, 1e-9));
    });
  });
}

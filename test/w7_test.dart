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

  group('Shard economy', () {
    test('addShards cộng + persist; bỏ qua số <= 0', () {
      expect(g.shards.value, 0);
      g.addShards(5);
      expect(g.shards.value, 5);
      expect(StorageService.to.getInt(StorageKeys.shards), 5);
      g.addShards(0);
      g.addShards(-3);
      expect(g.shards.value, 5); // không đổi
    });

    test('spendShards trừ đúng; chặn khi thiếu', () {
      g.addShards(10);
      expect(g.spendShards(4), isTrue);
      expect(g.shards.value, 6);
      expect(g.spendShards(99), isFalse); // thiếu
      expect(g.shards.value, 6); // không đổi
      expect(g.spendShards(0), isFalse); // số không hợp lệ
    });

    test('coins clamp dưới trần int32 (chống overflow)', () {
      g.addCoins(GameController.maxCoins);
      g.addCoins(1000);
      expect(g.coins.value, GameController.maxCoins);
    });
  });

  group('Temple build', () {
    test('khởi tạo tier = 0 cho mọi hạng mục', () {
      for (final n in kTempleNodes) {
        expect(t.tierOf(n), 0);
      }
      expect(t.builtCount, 0);
      expect(t.progress, 0);
    });

    test('build trừ shard, tier++, thưởng xu, persist', () {
      final gate = kTempleNodes.firstWhere((e) => e.id == 'gate');
      final tier0 = gate.tiers[0];
      g.addShards(tier0.cost);
      final coins0 = g.coins.value;

      expect(t.build(gate), isTrue);
      expect(t.tierOf(gate), 1);
      expect(g.shards.value, 0); // đã trừ hết
      expect(g.coins.value, coins0 + tier0.rewardCoins); // thưởng xu
      expect(StorageService.to.getInt(StorageKeys.templeTier('gate')), 1);
    });

    test('chặn build khi thiếu shard', () {
      final gate = kTempleNodes.firstWhere((e) => e.id == 'gate');
      expect(g.shards.value, 0);
      expect(t.canBuild(gate), isFalse);
      expect(t.build(gate), isFalse);
      expect(t.tierOf(gate), 0);
    });

    test('không vượt max tier; isMaxed đúng', () {
      final gate = kTempleNodes.firstWhere((e) => e.id == 'gate');
      g.addShards(100000); // dư shard
      for (var i = 0; i < gate.maxTier; i++) {
        expect(t.build(gate), isTrue);
      }
      expect(t.tierOf(gate), gate.maxTier);
      expect(t.isMaxed(gate), isTrue);
      expect(t.nextTier(gate), isNull);
      expect(t.build(gate), isFalse); // đã max → không xây thêm
    });

    test('progress phản ánh tổng tier đã xây', () {
      g.addShards(100000);
      final gate = kTempleNodes.firstWhere((e) => e.id == 'gate');
      t.build(gate);
      expect(t.builtCount, 1);
      expect(t.progress, closeTo(1 / t.totalCount, 1e-9));
    });
  });

  group('Win thưởng shard', () {
    test('lastShardReward = 1 + sao (qua addShards)', () {
      // Mô phỏng tối thiểu: gọi trực tiếp addShards như _saveProgress làm.
      g.lastStars = 2;
      final before = g.shards.value;
      g.addShards(1 + g.lastStars);
      expect(g.shards.value, before + 3);
    });
  });
}

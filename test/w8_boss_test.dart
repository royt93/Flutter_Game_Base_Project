import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs));
    c = Get.put(GameController());
  });
  tearDown(Get.reset);

  group('Boss khởi tạo', () {
    test('buildBossLevel + startBoss đặt máu/lượt', () {
      c.startBoss(1);
      expect(c.isBoss.value, isTrue);
      expect(c.isEndless.value, isFalse);
      expect(c.level.objective, ObjectiveType.boss);
      expect(c.movesLeft.value, kBossMoves);
      expect(c.bossHp.value, c.bossMaxHp.value);
      expect(c.bossMaxHp.value, kBossBaseHp);
      expect(c.hasWon, isFalse);
    });

    test('stage cao → máu nhiều hơn', () {
      c.startBoss(3);
      expect(c.bossMaxHp.value, kBossBaseHp + 2 * 700);
    });
  });

  group('Sát thương', () {
    test('addScore trừ máu boss; combo cao gây gấp đôi', () {
      c.startBoss(1);
      final hp0 = c.bossHp.value;
      c.addScore(3, 1); // dmg = 3*12 + 1*8 = 44
      expect(c.bossHp.value, hp0 - 44);

      final hp1 = c.bossHp.value;
      c.addScore(3, GameController.bossWeakCombo); // (3*12 + 4*8)*2 = (36+32)*2=136
      expect(c.bossHp.value, hp1 - 136);
    });

    test('hạ máu về 0 → hasWon', () {
      c.startBoss(1);
      // bơm sát thương lớn nhiều lần
      for (int i = 0; i < 50 && c.bossHp.value > 0; i++) {
        c.addScore(8, 6);
      }
      expect(c.bossHp.value, 0);
      expect(c.hasWon, isTrue);
    });
  });

  group('Phản đòn (retaliation)', () {
    test('mỗi 4 lượt boss rút thêm 1 lượt (stage 1)', () {
      c.startBoss(1);
      final m0 = c.movesLeft.value;
      c.useMove(); // 1
      c.useMove(); // 2
      c.useMove(); // 3
      expect(c.movesLeft.value, m0 - 3);
      c.useMove(); // 4 → +1 phạt
      expect(c.movesLeft.value, m0 - 5);
    });
  });

  group('Kết thúc', () {
    test('thắng boss thưởng xu+shard, KHÔNG đụng win-streak', () {
      c.startBoss(2);
      c.winStreak.value = 4;
      final coins0 = c.coins.value;
      final shards0 = c.shards.value;
      while (c.bossHp.value > 0) {
        c.addScore(8, 6);
      }
      final r = c.checkEnd();
      expect(r, 'win');
      expect(c.winStreak.value, 4); // không đổi
      expect(c.coins.value, greaterThan(coins0));
      expect(c.shards.value, greaterThan(shards0));
      expect(c.lastShardReward, 2 + 2); // 2 + stage
    });

    test('hết lượt mà boss còn máu → lose', () {
      c.startBoss(1);
      c.movesLeft.value = 0;
      expect(c.checkEnd(), 'lose');
      expect(c.lastCoinReward, 0);
    });
  });

  group('Chuyển mode reset boss', () {
    test('startLevel/startEndless tắt cờ boss', () {
      c.startBoss(1);
      expect(c.isBoss.value, isTrue);
      c.startEndless();
      expect(c.isBoss.value, isFalse);
      c.startBoss(1);
      c.startLevel(1);
      expect(c.isBoss.value, isFalse);
      expect(c.level.objective, isNot(ObjectiveType.boss));
    });
  });
}

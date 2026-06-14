import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/battle_pass.dart';
import 'package:neon_jewels/presentation/controllers/battle_pass_controller.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController g;
  late BattlePassController bp;

  Future<void> boot({DateTime? now}) async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs));
    g = Get.put(GameController());
    g.clock = () => now ?? DateTime(2026, 6, 14);
    bp = Get.put(BattlePassController(g));
  }

  setUp(() => boot());
  tearDown(Get.reset);

  group('Daily quests', () {
    test('dailyQuests xác định + 3 cái + không trùng loại', () {
      final a = dailyQuests(100);
      final b = dailyQuests(100);
      expect(a.length, 3);
      expect(a.map((q) => q.type).toList(), b.map((q) => q.type).toList());
      expect(a.map((q) => q.type).toSet().length, 3); // distinct types
    });

    test('recordLevelEnd cộng tiến trình theo loại', () {
      // ép 3 quest cụ thể để kiểm soát
      bp.todayQuests = const [
        QuestTemplate(QuestType.winLevels, 3, 40),
        QuestTemplate(QuestType.earnCoins, 100, 40),
        QuestTemplate(QuestType.reachCombo, 5, 40),
      ];
      bp.questProgress.value = [0, 0, 0];

      bp.recordLevelEnd(win: true, stars: 2, coins: 30, combo: 4);
      expect(bp.questProgress[0], 1); // win +1
      expect(bp.questProgress[1], 30); // coins +30
      expect(bp.questProgress[2], 4); // combo max = 4

      bp.recordLevelEnd(win: false, stars: 0, coins: 0, combo: 6);
      expect(bp.questProgress[0], 1); // thua → không tăng win
      expect(bp.questProgress[2], 6); // combo max lên 6
    });
  });

  group('XP & pass level', () {
    test('hoàn thành quest cộng XP đúng 1 lần', () {
      bp.todayQuests = const [
        QuestTemplate(QuestType.winLevels, 2, 60),
        QuestTemplate(QuestType.playLevels, 99, 30),
        QuestTemplate(QuestType.reachCombo, 99, 30),
      ];
      bp.questProgress.value = [0, 0, 0];

      bp.recordLevelEnd(win: true, stars: 1, coins: 0, combo: 1);
      expect(bp.xp.value, 0); // mới 1/2 win
      bp.recordLevelEnd(win: true, stars: 1, coins: 0, combo: 1);
      expect(bp.xp.value, 60); // đủ 2 win → +60
      bp.recordLevelEnd(win: true, stars: 1, coins: 0, combo: 1);
      expect(bp.xp.value, 60); // không cộng lại
    });

    test('level suy ra từ xp; claim 1 lần + persist', () {
      bp.xp.value = kPassTiers[0].xpNeeded; // đủ cấp 1
      expect(bp.level, 1);
      expect(bp.canClaim(0), isTrue);
      final coins0 = g.coins.value;
      expect(bp.claim(0), isTrue);
      expect(bp.isClaimed(0), isTrue);
      expect(bp.claim(0), isFalse); // không nhận lại
      // tier 0 thưởng coins 50
      expect(g.coins.value, coins0 + kPassTiers[0].amount);
      expect(StorageService.to.getInt(StorageKeys.bpClaimed(0)), 1);
    });

    test('không claim được tier chưa đạt', () {
      expect(bp.level, 0);
      expect(bp.canClaim(0), isFalse);
      expect(bp.claim(0), isFalse);
    });
  });

  group('Sang ngày mới', () {
    test('đổi ngày reset tiến trình quest', () async {
      bp.todayQuests = const [
        QuestTemplate(QuestType.playLevels, 5, 30),
        QuestTemplate(QuestType.playLevels, 5, 30),
        QuestTemplate(QuestType.playLevels, 5, 30),
      ];
      bp.recordLevelEnd(win: true, stars: 1, coins: 0, combo: 1);
      expect(bp.questProgress[0], 1);

      // reboot ở ngày kế → progress reset
      await boot(now: DateTime(2026, 6, 15));
      expect(bp.questProgress.every((p) => p == 0), isTrue);
    });
  });
}

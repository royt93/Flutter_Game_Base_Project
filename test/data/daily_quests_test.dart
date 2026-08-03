import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/daily_quests.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';

void main() {
  test('questsForDay is deterministic and selects three distinct entries', () {
    final first = questsForDay(20000);
    final second = questsForDay(20000);
    expect(first, hasLength(3));
    expect(second, orderedEquals(first));
    expect(first.toSet(), hasLength(3));
  });

  group('daily quest state', () {
    late GameController controller;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs), permanent: true);
      controller = GameController();
      controller.onInit();
      controller.checkDailyQuestRollover(epochDay: 100);
    });
    tearDown(Get.reset);

    test('progress resets on a new day', () {
      controller.dailyQuestProgress.assignAll([1, 2, 3]);
      controller.checkDailyQuestRollover(epochDay: 101);
      expect(controller.dailyQuestProgress, [0, 0, 0]);
      expect(controller.dailyQuestClaimed, isEmpty);
    });

    test('the same quest cannot be claimed twice in one day', () {
      final today = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
      controller.checkDailyQuestRollover(epochDay: today);
      controller.coins.value = 0;
      final quest = controller.dailyQuests.first;
      controller.dailyQuestProgress[0] = quest.target;
      expect(controller.claimDailyQuest(0), isTrue);
      expect(controller.claimDailyQuest(0), isFalse);
      expect(controller.coins.value, quest.coinReward);
    });
  });
}

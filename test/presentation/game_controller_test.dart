import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/levels.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController ctrl;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    ctrl = Get.put(GameController(), permanent: true);
  });

  tearDown(Get.reset);

  final target = kLevels[0].targetScore; // level 1

  group('checkEnd — sao/xu/mở khoá', () {
    test('điểm < target → 0 sao, không mở khoá, không thưởng xu', () {
      ctrl.startLevel(1);
      ctrl.addScore(target - 1);
      ctrl.checkEnd(false);
      expect(ctrl.starsEarned.value, 0);
      expect(ctrl.ended.value, isTrue);
      expect(ctrl.unlockedLevel.value, 1);
      expect(ctrl.coins.value, 0);
    });

    test('đạt target → ≥1 sao, mở khoá màn kế, thưởng xu = sao*20', () {
      ctrl.startLevel(1);
      ctrl.addScore(target);
      ctrl.checkEnd(false);
      expect(ctrl.starsEarned.value, greaterThanOrEqualTo(1));
      expect(ctrl.unlockedLevel.value, 2);
      expect(ctrl.coins.value, ctrl.starsEarned.value * 20);
    });

    test('ngưỡng sao 1/2/3 theo bội số target', () {
      ctrl.startLevel(1);
      ctrl.addScore(target); // đúng target
      ctrl.checkEnd(false);
      expect(ctrl.starsEarned.value, 1);

      ctrl.startLevel(1);
      ctrl.addScore((target * 1.3).ceil());
      ctrl.checkEnd(false);
      expect(ctrl.starsEarned.value, 2);

      ctrl.startLevel(1);
      ctrl.addScore((target * 1.7).ceil());
      ctrl.checkEnd(false);
      expect(ctrl.starsEarned.value, 3);
    });

    test('checkEnd lần 2 không cộng dồn xu (idempotent)', () {
      ctrl.startLevel(1);
      ctrl.addScore(target);
      ctrl.checkEnd(false);
      final coinsAfter = ctrl.coins.value;
      ctrl.checkEnd(false);
      expect(ctrl.coins.value, coinsAfter);
    });

    test('boardCleared=true đặt cờ cleared', () {
      ctrl.startLevel(1);
      ctrl.addScore(target);
      ctrl.checkEnd(true);
      expect(ctrl.cleared.value, isTrue);
    });
  });

  group('mua booster', () {
    test('không đủ xu → false, không đổi số dư/số lượng', () {
      ctrl.startLevel(1);
      final bomb0 = ctrl.bombCount.value;
      expect(ctrl.coins.value, 0);
      expect(ctrl.buyBomb(), isFalse);
      expect(ctrl.bombCount.value, bomb0);
      expect(ctrl.coins.value, 0);
    });

    test('đủ xu → true, trừ giá, tăng số lượng', () {
      ctrl.startLevel(1);
      ctrl.coins.value = 100;
      final bomb0 = ctrl.bombCount.value;
      expect(ctrl.buyBomb(), isTrue);
      expect(ctrl.bombCount.value, bomb0 + 1);
      expect(ctrl.coins.value, 100 - GameController.bombPrice);
    });
  });

  group('resetProgress', () {
    test('xoá sạch xu/mở khoá, booster về mặc định', () async {
      ctrl.startLevel(1);
      ctrl.coins.value = 500;
      ctrl.addScore(target);
      ctrl.checkEnd(false); // mở khoá màn 2, thưởng xu
      expect(ctrl.unlockedLevel.value, 2);

      await ctrl.resetProgress();
      expect(ctrl.coins.value, 0);
      expect(ctrl.unlockedLevel.value, 1);
      expect(ctrl.bombCount.value, 3);
      expect(ctrl.shuffleCount.value, 1);
      expect(ctrl.undoCount.value, 1);
    });
  });

  group('F2 Daily reward', () {
    int todayEpochDay() =>
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;

    test('lần đầu: nhận được, streak=1, cộng đúng xu D1', () {
      expect(ctrl.canClaimDaily, isTrue);
      final reward = ctrl.claimDaily();
      expect(reward, GameController.dailyRewards[0]);
      expect(ctrl.dailyStreak.value, 1);
      expect(ctrl.coins.value, GameController.dailyRewards[0]);
    });

    test('đã nhận hôm nay → không cho nhận lại', () {
      ctrl.claimDaily();
      final coinsAfterFirst = ctrl.coins.value;
      expect(ctrl.canClaimDaily, isFalse);
      final reward = ctrl.claimDaily();
      expect(reward, isNull);
      expect(ctrl.dailyStreak.value, 1);
      expect(ctrl.coins.value, coinsAfterFirst);
    });

    test('liên tiếp hôm qua → streak +1, đúng thưởng theo mốc', () {
      StorageService.to.setInt(StorageKeys.lastClaimDay, todayEpochDay() - 1);
      StorageService.to.setInt(StorageKeys.dailyStreak, 3);
      ctrl.dailyStreak.value = 3;

      final reward = ctrl.claimDaily();
      expect(ctrl.dailyStreak.value, 4);
      expect(reward, GameController.dailyRewards[3]);
    });

    test('cách >1 ngày → reset streak về 1', () {
      StorageService.to.setInt(StorageKeys.lastClaimDay, todayEpochDay() - 5);
      StorageService.to.setInt(StorageKeys.dailyStreak, 4);
      ctrl.dailyStreak.value = 4;

      final reward = ctrl.claimDaily();
      expect(ctrl.dailyStreak.value, 1);
      expect(reward, GameController.dailyRewards[0]);
    });

    test('chống lùi giờ: đồng hồ chỉnh lùi vẫn không cho nhận thêm', () {
      final future = todayEpochDay() + 100;
      StorageService.to.setInt(StorageKeys.maxEpochDaySeen, future);
      StorageService.to.setInt(StorageKeys.lastClaimDay, future);
      StorageService.to.setInt(StorageKeys.dailyStreak, 2);
      ctrl.dailyStreak.value = 2;

      expect(ctrl.canClaimDaily, isFalse);
      final reward = ctrl.claimDaily();
      expect(reward, isNull);
      expect(ctrl.dailyStreak.value, 2);
      expect(ctrl.coins.value, 0);
    });
  });

  group('F8 Time-attack + Zen', () {
    test('startSideMode(timeAttack) không đụng unlockedLevel campaign', () {
      ctrl.startLevel(1);
      ctrl.startSideMode(GameMode.timeAttack);
      expect(ctrl.mode.value, GameMode.timeAttack);
      expect(ctrl.currentLevel.id, kTimeAttackLevel.id);
      expect(ctrl.unlockedLevel.value, 1);
    });

    test('startSideMode(zen) không đụng unlockedLevel campaign', () {
      ctrl.startSideMode(GameMode.zen);
      expect(ctrl.mode.value, GameMode.zen);
      expect(ctrl.currentLevel.id, kZenLevel.id);
      expect(ctrl.unlockedLevel.value, 1);
    });

    test(
      'checkEnd ở Time-attack không mở khoá/thưởng xu/lưu highScore campaign',
      () {
        ctrl.startSideMode(GameMode.timeAttack);
        ctrl.addScore(9999);
        ctrl.checkEnd(false);
        expect(ctrl.ended.value, isTrue);
        expect(ctrl.starsEarned.value, 0);
        expect(ctrl.unlockedLevel.value, 1);
        expect(ctrl.coins.value, 0);
        expect(StorageService.to.getInt(StorageKeys.highScore(1)), 0);
      },
    );

    test('checkEnd ở Zen không mở khoá/thưởng xu', () {
      ctrl.startSideMode(GameMode.zen);
      ctrl.addScore(500);
      ctrl.checkEnd(false);
      expect(ctrl.ended.value, isTrue);
      expect(ctrl.unlockedLevel.value, 1);
      expect(ctrl.coins.value, 0);
    });

    test('Time-attack: chỉ lưu best khi điểm mới cao hơn', () {
      ctrl.startSideMode(GameMode.timeAttack);
      ctrl.addScore(100);
      ctrl.checkEnd(false);
      expect(ctrl.timeAttackBest.value, 100);

      ctrl.startSideMode(GameMode.timeAttack);
      ctrl.addScore(50);
      ctrl.checkEnd(false);
      expect(ctrl.timeAttackBest.value, 100);

      ctrl.startSideMode(GameMode.timeAttack);
      ctrl.addScore(200);
      ctrl.checkEnd(false);
      expect(ctrl.timeAttackBest.value, 200);
    });

    test('resetProgress xoá timeAttackBest', () async {
      ctrl.startSideMode(GameMode.timeAttack);
      ctrl.addScore(300);
      ctrl.checkEnd(false);
      expect(ctrl.timeAttackBest.value, 300);

      await ctrl.resetProgress();
      expect(ctrl.timeAttackBest.value, 0);
    });
  });

  group('F6b objective', () {
    test('score: luôn 0, objectiveMet luôn false dù bàn còn/hết', () {
      ctrl.startLevel(1); // objective mặc định = score
      ctrl.updateObjectiveProgress([
        [0, 1],
        [null, null],
      ]);
      expect(ctrl.objectiveRemaining.value, 0);
      expect(ctrl.objectiveMet, isFalse);
    });

    test('clearColor: đếm đúng số ô còn màu mục tiêu, met khi = 0', () {
      ctrl.startLevel(1);
      ctrl.currentLevelRx.value = PopLevel(
        id: ctrl.currentLevel.id,
        rows: ctrl.currentLevel.rows,
        cols: ctrl.currentLevel.cols,
        colorCount: ctrl.currentLevel.colorCount,
        targetScore: ctrl.currentLevel.targetScore,
        objective: const LevelObjective.clearColor(2),
      );

      ctrl.updateObjectiveProgress([
        [2, 2, 1],
        [0, 2, null],
      ]);
      expect(ctrl.objectiveRemaining.value, 3);
      expect(ctrl.objectiveMet, isFalse);

      ctrl.updateObjectiveProgress([
        [1, 1, 1],
        [0, null, null],
      ]);
      expect(ctrl.objectiveRemaining.value, 0);
      expect(ctrl.objectiveMet, isTrue);
    });

    test('clearObstacle: đếm đúng số ô âm còn lại, met khi = 0', () {
      ctrl.startLevel(1);
      ctrl.currentLevelRx.value = PopLevel(
        id: ctrl.currentLevel.id,
        rows: ctrl.currentLevel.rows,
        cols: ctrl.currentLevel.cols,
        colorCount: ctrl.currentLevel.colorCount,
        targetScore: ctrl.currentLevel.targetScore,
        objective: const LevelObjective.clearObstacle(),
      );

      ctrl.updateObjectiveProgress([
        [-2, 0],
        [-1, 1],
      ]);
      expect(ctrl.objectiveRemaining.value, 2);
      expect(ctrl.objectiveMet, isFalse);

      ctrl.updateObjectiveProgress([
        [0, 0],
        [null, 1],
      ]);
      expect(ctrl.objectiveRemaining.value, 0);
      expect(ctrl.objectiveMet, isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/levels.dart';
import 'package:pop_star_blast/data/mascot_skins.dart';
import 'package:pop_star_blast/logic/gift_tile.dart';
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
      expect(
        ctrl.coins.value,
        ctrl.starsEarned.value * 20 * ctrl.weekendCoinMultiplier,
      );
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

  group('Task #5 — Perfect Clear replay', () {
    test('startPerfectClear chụp best score hiện tại làm target', () {
      ctrl.startLevel(1);
      ctrl.addScore(target);
      ctrl.checkEnd(false);
      final best = StorageService.to.getInt(StorageKeys.highScore(1));

      ctrl.startPerfectClear(1);
      expect(ctrl.perfectClearTarget.value, best);
      expect(ctrl.perfectClearSuccess.value, isFalse);
    });

    test('vượt target → thành công, thưởng bonus coin', () {
      ctrl.startLevel(1);
      ctrl.addScore(target);
      ctrl.checkEnd(false);
      final best = StorageService.to.getInt(StorageKeys.highScore(1));
      final coinsBefore = ctrl.coins.value;

      ctrl.startPerfectClear(1);
      ctrl.addScore(best + 1);
      ctrl.checkEnd(false);

      expect(ctrl.perfectClearSuccess.value, isTrue);
      expect(
        ctrl.coins.value,
        coinsBefore +
            ctrl.starsEarned.value * 20 * ctrl.weekendCoinMultiplier +
            GameController.perfectClearBonusCoins * ctrl.weekendCoinMultiplier,
      );
    });

    test('không vượt target → không thành công, không thưởng bonus', () {
      ctrl.startLevel(1);
      ctrl.addScore(target);
      ctrl.checkEnd(false);
      final best = StorageService.to.getInt(StorageKeys.highScore(1));

      ctrl.startPerfectClear(1);
      ctrl.addScore(best);
      ctrl.checkEnd(false);

      expect(ctrl.perfectClearSuccess.value, isFalse);
    });

    test(
      'startLevel thường (không phải Perfect Clear) reset target về null',
      () {
        ctrl.startLevel(1);
        ctrl.addScore(target);
        ctrl.checkEnd(false);
        ctrl.startPerfectClear(1);
        expect(ctrl.perfectClearTarget.value, isNotNull);

        ctrl.startLevel(1);
        expect(ctrl.perfectClearTarget.value, isNull);
        expect(ctrl.perfectClearSuccess.value, isFalse);
      },
    );
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

    test('xoá sạch counter + mốc thành tựu I22', () async {
      ctrl.startLevel(1);
      ctrl.registerPop(10, groupSize: 500); // đạt mốc gems_500
      expect(ctrl.unlockedAchievementIds, contains('gems_500'));

      await ctrl.resetProgress();
      expect(ctrl.totalGemsPopped.value, 0);
      expect(ctrl.maxComboEver.value, 0);
      expect(ctrl.levelsThreeStarred.value, 0);
      expect(ctrl.boardsFullyCleared.value, 0);
      expect(ctrl.totalBoostersUsed.value, 0);
      expect(ctrl.unlockedAchievementIds, isEmpty);
    });
  });

  group('I22 Achievements — tích hợp GameController', () {
    test(
      'registerPop cộng groupSize vào totalGemsPopped, mở khoá mốc gems_500',
      () {
        ctrl.startLevel(1);
        ctrl.registerPop(10, groupSize: 500);
        expect(ctrl.totalGemsPopped.value, 500);
        expect(ctrl.unlockedAchievementIds, contains('gems_500'));
        expect(ctrl.coins.value, 50 * ctrl.weekendCoinMultiplier);
      },
    );

    test(
      '3 lần registerPop liên tiếp (không resetCombo) đẩy combo lên 3, mở khoá mốc combo_3',
      () {
        ctrl.startLevel(1);
        ctrl.registerPop(10);
        ctrl.registerPop(10);
        ctrl.registerPop(10);
        expect(ctrl.maxComboEver.value, 3);
        expect(ctrl.unlockedAchievementIds, contains('combo_3'));
        expect(ctrl.coins.value, 50 * ctrl.weekendCoinMultiplier);
      },
    );

    test(
      'vượt mốc đã mở khoá thêm lần nữa không cộng thêm xu / không unlock lại',
      () {
        ctrl.startLevel(1);
        ctrl.registerPop(10, groupSize: 500); // mở khoá gems_500, +50 xu
        final coinsAfter = ctrl.coins.value;
        ctrl.registerPop(10, groupSize: 1); // vẫn > threshold nhưng đã unlock
        expect(ctrl.totalGemsPopped.value, 501);
        expect(ctrl.coins.value, coinsAfter);
        expect(ctrl.unlockedAchievementIds.length, 1);
      },
    );

    test('checkEnd(true) tăng boardsFullyCleared và mở khoá mốc clear_5', () {
      for (var i = 0; i < 5; i++) {
        ctrl.startLevel(1);
        ctrl.checkEnd(true);
      }
      expect(ctrl.boardsFullyCleared.value, 5);
      expect(ctrl.unlockedAchievementIds, contains('clear_5'));
    });

    test(
      'checkEnd gọi lại lần 2 (đã ended) không cộng dồn boardsFullyCleared',
      () {
        ctrl.startLevel(1);
        ctrl.checkEnd(true);
        expect(ctrl.boardsFullyCleared.value, 1);
        ctrl.checkEnd(true); // ended.value đã true → early-return
        expect(ctrl.boardsFullyCleared.value, 1);
      },
    );
  });

  group('F2 Daily reward', () {
    int todayEpochDay() =>
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;

    test('lần đầu: nhận được, streak=1, cộng đúng xu D1', () {
      expect(ctrl.canClaimDaily, isTrue);
      final reward = ctrl.claimDaily();
      final expected =
          GameController.dailyRewards[0] * ctrl.weekendCoinMultiplier;
      expect(reward, expected);
      expect(ctrl.dailyStreak.value, 1);
      expect(ctrl.coins.value, expected);
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
      expect(
        reward,
        GameController.dailyRewards[3] * ctrl.weekendCoinMultiplier,
      );
    });

    test('cách >1 ngày → reset streak về 1', () {
      StorageService.to.setInt(StorageKeys.lastClaimDay, todayEpochDay() - 5);
      StorageService.to.setInt(StorageKeys.dailyStreak, 4);
      ctrl.dailyStreak.value = 4;

      final reward = ctrl.claimDaily();
      expect(ctrl.dailyStreak.value, 1);
      expect(
        reward,
        GameController.dailyRewards[0] * ctrl.weekendCoinMultiplier,
      );
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

  group('I7 Vòng quay hằng ngày', () {
    test('todaySpinReward seed theo ngày: gọi nhiều lần cùng ngày ra cùng '
        'kết quả, không đổi state', () {
      final r1 = ctrl.todaySpinReward;
      final r2 = ctrl.todaySpinReward;
      expect(r1.type, r2.type);
      expect(r1.amount, r2.amount);
      expect(ctrl.canClaimSpin, isTrue);
    });

    test('claimSpin cộng đúng thưởng + đánh dấu đã quay, quay lại trong '
        'ngày trả về null', () {
      expect(ctrl.canClaimSpin, isTrue);
      final reward = ctrl.todaySpinReward;
      final coinsBefore = ctrl.coins.value;
      final bombBefore = ctrl.bombCount.value;
      final shuffleBefore = ctrl.shuffleCount.value;
      final undoBefore = ctrl.undoCount.value;

      final claimed = ctrl.claimSpin();
      expect(claimed?.type, reward.type);
      expect(claimed?.amount, reward.amount);

      switch (reward.type) {
        case 'coins':
          expect(
            ctrl.coins.value,
            coinsBefore + reward.amount * ctrl.weekendCoinMultiplier,
          );
        case 'bomb':
          expect(ctrl.bombCount.value, bombBefore + reward.amount);
        case 'shuffle':
          expect(ctrl.shuffleCount.value, shuffleBefore + reward.amount);
        case 'undo':
          expect(ctrl.undoCount.value, undoBefore + reward.amount);
      }

      expect(ctrl.canClaimSpin, isFalse);
      expect(ctrl.claimSpin(), isNull);
    });

    test('lastSpinDay khác hôm nay (giả lập qua ngày mới) → canClaimSpin '
        'lại true', () {
      ctrl.claimSpin();
      expect(ctrl.canClaimSpin, isFalse);

      final yesterday =
          DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000 - 1;
      StorageService.to.setInt(StorageKeys.lastSpinDay, yesterday);
      expect(ctrl.canClaimSpin, isTrue);
    });
  });

  group('I10 Comeback bonus', () {
    test('lần đầu mở app (chưa có lastOpenDay) → không tặng quà, nhưng vẫn '
        'lưu mốc hôm nay', () {
      expect(ctrl.checkComebackBonus(), isNull);
      final today = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
      expect(StorageService.to.getInt(StorageKeys.lastOpenDay, def: -1), today);
    });

    test('vắng đúng 3 ngày → tặng coin + 1 bomb + 1 shuffle, reset mốc', () {
      final today = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
      StorageService.to.setInt(StorageKeys.lastOpenDay, today - 3);
      final coinsBefore = ctrl.coins.value;
      final bombBefore = ctrl.bombCount.value;
      final shuffleBefore = ctrl.shuffleCount.value;

      final reward = ctrl.checkComebackBonus();

      expect(
        reward,
        GameController.comebackBonusCoins * ctrl.weekendCoinMultiplier,
      );
      expect(ctrl.coins.value, coinsBefore + reward!);
      expect(ctrl.bombCount.value, bombBefore + 1);
      expect(ctrl.shuffleCount.value, shuffleBefore + 1);
      expect(StorageService.to.getInt(StorageKeys.lastOpenDay, def: -1), today);
      // Mở lại ngay sau đó trong cùng ngày → không tặng nữa.
      expect(ctrl.checkComebackBonus(), isNull);
    });

    test('vắng dưới 3 ngày → không tặng quà', () {
      final today = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
      StorageService.to.setInt(StorageKeys.lastOpenDay, today - 2);
      expect(ctrl.checkComebackBonus(), isNull);
    });
  });

  group('F13 Daily Challenge', () {
    test('startDailyChallenge sinh bàn từ seed hôm nay, gọi lại cùng ngày ra '
        'cùng bàn', () {
      ctrl.startDailyChallenge();
      final grid1 = ctrl.dailyChallengeGrid;
      ctrl.startDailyChallenge();
      final grid2 = ctrl.dailyChallengeGrid;
      expect(ctrl.mode.value, GameMode.dailyChallenge);
      expect(ctrl.currentLevel.id, kDailyChallengeLevel.id);
      expect(grid1, equals(grid2));
    });

    test('ghi điểm lần đầu trong ngày, chơi lại trong ngày không đè điểm', () {
      ctrl.startDailyChallenge();
      ctrl.score.value = 500;
      expect(ctrl.canRecordDailyChallengeScore, isTrue);
      ctrl.checkEnd(false);
      expect(ctrl.dailyChallengeScoreToday, 500);
      expect(ctrl.canRecordDailyChallengeScore, isFalse);

      ctrl.startDailyChallenge();
      ctrl.score.value = 900;
      ctrl.checkEnd(false);
      expect(ctrl.dailyChallengeScoreToday, 500);
    });

    test('dailyChallengeScoreForLeaderboard = 0 khi chưa chơi hôm nay, không '
        'lộ điểm ngày cũ', () {
      expect(ctrl.canRecordDailyChallengeScore, isTrue);
      expect(ctrl.dailyChallengeScoreForLeaderboard, 0);

      ctrl.startDailyChallenge();
      ctrl.score.value = 500;
      ctrl.checkEnd(false);
      expect(ctrl.dailyChallengeScoreForLeaderboard, 500);
    });

    test('lastDailyChallengeDay khác hôm nay (giả lập qua ngày mới) → ghi '
        'điểm lại được', () {
      ctrl.startDailyChallenge();
      ctrl.score.value = 300;
      ctrl.checkEnd(false);
      expect(ctrl.canRecordDailyChallengeScore, isFalse);

      final yesterday =
          DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000 - 1;
      StorageService.to.setInt(StorageKeys.lastDailyChallengeDay, yesterday);
      expect(ctrl.canRecordDailyChallengeScore, isTrue);
    });
  });

  group('I6 Battle-pass season', () {
    test('thắng campaign cộng điểm mùa = sao * 10', () {
      ctrl.startLevel(1);
      ctrl.addScore(target);
      ctrl.checkEnd(false);
      expect(ctrl.seasonPoints.value, ctrl.starsEarned.value * 10);
    });

    test('claimSeason chỉ nhận được khi đủ điểm, và chỉ 1 lần', () {
      ctrl.seasonPoints.value = GameController.seasonMilestones[0];
      expect(ctrl.canClaimSeason(0), isTrue);
      expect(ctrl.claimSeason(0), isTrue);
      expect(ctrl.isSeasonClaimed(0), isTrue);
      expect(ctrl.canClaimSeason(0), isFalse);
      expect(ctrl.claimSeason(0), isFalse);
    });

    test('claim mốc coins cộng đúng số coin thưởng', () {
      ctrl.seasonPoints.value = GameController.seasonMilestones[0];
      final before = ctrl.coins.value;
      ctrl.claimSeason(0);
      expect(
        ctrl.coins.value,
        before +
            GameController.seasonRewards[0].amount * ctrl.weekendCoinMultiplier,
      );
    });

    test('qua mùa mới → reset điểm mùa + mốc đã nhận', () {
      ctrl.seasonPoints.value = GameController.seasonMilestones[0];
      ctrl.claimSeason(0);
      StorageService.to.setInt(StorageKeys.lastSeasonIndex, -999);
      ctrl.startLevel(1);
      ctrl.addScore(target);
      ctrl.checkEnd(false);
      expect(ctrl.seasonPoints.value, ctrl.starsEarned.value * 10);
      expect(ctrl.isSeasonClaimed(0), isFalse);
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

  group('F9 objective mới', () {
    void setObjective(LevelObjective objective) {
      ctrl.currentLevelRx.value = PopLevel(
        id: ctrl.currentLevel.id,
        rows: ctrl.currentLevel.rows,
        cols: ctrl.currentLevel.cols,
        colorCount: ctrl.currentLevel.colorCount,
        targetScore: ctrl.currentLevel.targetScore,
        objective: objective,
      );
    }

    test(
      'collect: remaining giảm theo số đã thu (initial - current), met khi đủ target',
      () {
        ctrl.startLevel(1);
        setObjective(const LevelObjective.collect(2, 3));

        // Lần gọi đầu chụp initial = 4 ô màu 2 trên bàn → remaining = target (3).
        ctrl.updateObjectiveProgress([
          [2, 2, 1],
          [2, 2, null],
        ]);
        expect(ctrl.objectiveRemaining.value, 3);
        expect(ctrl.objectiveMet, isFalse);

        // Đã thu 2 ô (còn 2 trên bàn) → remaining = 3 - 2 = 1.
        ctrl.updateObjectiveProgress([
          [2, 2, 1],
          [null, null, null],
        ]);
        expect(ctrl.objectiveRemaining.value, 1);
        expect(ctrl.objectiveMet, isFalse);

        // Thu đủ 3 (dù vẫn còn 1 ô màu 2 trên bàn) → met.
        ctrl.updateObjectiveProgress([
          [2, null, 1],
          [null, null, null],
        ]);
        expect(ctrl.objectiveRemaining.value, 0);
        expect(ctrl.objectiveMet, isTrue);
      },
    );

    test('moveLimitBonus: remaining luôn 0, không bao giờ objectiveMet', () {
      ctrl.startLevel(1);
      setObjective(const LevelObjective.moveLimitBonus(10));
      ctrl.updateObjectiveProgress([
        [1, 1],
        [1, 1],
      ]);
      expect(ctrl.objectiveRemaining.value, 0);
      expect(ctrl.objectiveMet, isFalse);
    });

    test('obstacleInMoves: đếm ô âm như clearObstacle, met khi = 0', () {
      ctrl.startLevel(1);
      setObjective(const LevelObjective.obstacleInMoves(2, 10));
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

    test('openGift: đếm số ô quà còn lại, met khi mở hết', () {
      ctrl.startLevel(1);
      setObjective(const LevelObjective.openGift(2));
      ctrl.updateObjectiveProgress([
        [giftTileValue, 0],
        [giftTileValue, 1],
      ]);
      expect(ctrl.objectiveRemaining.value, 2);
      expect(ctrl.objectiveMet, isFalse);

      ctrl.updateObjectiveProgress([
        [null, 0],
        [giftTileValue, 1],
      ]);
      expect(ctrl.objectiveRemaining.value, 1);
      expect(ctrl.objectiveMet, isFalse);

      ctrl.updateObjectiveProgress([
        [null, 0],
        [null, 1],
      ]);
      expect(ctrl.objectiveRemaining.value, 0);
      expect(ctrl.objectiveMet, isTrue);
    });

    test('movesUsed tăng mỗi lần registerPop, reset khi startLevel', () {
      ctrl.startLevel(1);
      expect(ctrl.movesUsed.value, 0);
      ctrl.registerPop(10);
      ctrl.registerPop(10);
      expect(ctrl.movesUsed.value, 2);
      ctrl.startLevel(1);
      expect(ctrl.movesUsed.value, 0);
    });

    test('bonus sao: xong trong giới hạn lượt → +1 sao (tối đa 3)', () {
      ctrl.startLevel(1);
      setObjective(LevelObjective.moveLimitBonus(10));
      ctrl.addScore(target); // đúng target → 1 sao base
      ctrl.movesUsed.value = 5;
      ctrl.checkEnd(false);
      expect(ctrl.starsEarned.value, 2);
    });

    test('bonus sao: vượt giới hạn lượt → không cộng', () {
      ctrl.startLevel(1);
      setObjective(LevelObjective.moveLimitBonus(10));
      ctrl.addScore(target);
      ctrl.movesUsed.value = 11;
      ctrl.checkEnd(false);
      expect(ctrl.starsEarned.value, 1);
    });

    test('bonus sao: 0 sao (thua) không được cộng bonus', () {
      ctrl.startLevel(1);
      setObjective(LevelObjective.moveLimitBonus(10));
      ctrl.addScore(target - 1);
      ctrl.movesUsed.value = 1;
      ctrl.checkEnd(false);
      expect(ctrl.starsEarned.value, 0);
    });

    test('bonus sao: đã 3 sao base thì vẫn giữ 3 (không vượt trần)', () {
      ctrl.startLevel(1);
      setObjective(LevelObjective.moveLimitBonus(10));
      ctrl.addScore((target * 1.7).ceil());
      ctrl.movesUsed.value = 1;
      ctrl.checkEnd(false);
      expect(ctrl.starsEarned.value, 3);
    });
  });

  group('F1 Combo multiplier', () {
    test('registerPop tăng multiplier dần theo chuỗi, cap tại comboMax', () {
      ctrl.startLevel(1);
      ctrl.registerPop(10); // combo 1 → x1.0
      expect(ctrl.comboMultiplier.value, 1.0);
      ctrl.registerPop(10); // combo 2 → x1.5
      expect(ctrl.comboMultiplier.value, 1.5);
      ctrl.registerPop(10); // combo 3 → x2.0
      expect(ctrl.comboMultiplier.value, 2.0);

      for (var i = 0; i < 10; i++) {
        ctrl.registerPop(10);
      }
      expect(ctrl.comboMultiplier.value, GameController.comboMax);
    });

    test('registerPop cộng điểm đã nhân hệ số combo hiện tại', () {
      ctrl.startLevel(1);
      final gained1 = ctrl.registerPop(10);
      expect(gained1, 10); // combo 1 → x1.0
      final gained2 = ctrl.registerPop(10);
      expect(gained2, 15); // combo 2 → x1.5
      expect(ctrl.score.value, 25);
    });

    test('resetCombo đưa combo/multiplier về trạng thái ban đầu', () {
      ctrl.startLevel(1);
      ctrl.registerPop(10);
      ctrl.registerPop(10);
      expect(ctrl.comboMultiplier.value, greaterThan(1.0));

      ctrl.resetCombo();
      expect(ctrl.comboCount.value, 0);
      expect(ctrl.comboMultiplier.value, 1.0);
    });
  });

  group('I39 Combo Milestone FX', () {
    test('triggerComboMilestone tăng tick và lưu đúng giá trị mốc', () {
      ctrl.startLevel(1);
      expect(ctrl.comboMilestoneTick.value, 0);

      ctrl.triggerComboMilestone(5);
      expect(ctrl.comboMilestoneTick.value, 1);
      expect(ctrl.comboMilestoneValue, 5);

      ctrl.triggerComboMilestone(10);
      expect(ctrl.comboMilestoneTick.value, 2);
      expect(ctrl.comboMilestoneValue, 10);
    });

    test('resetCombo không tự trigger FX (chỉ pop_star_game.dart mới gọi '
        'triggerComboMilestone khi combo chạm mốc)', () {
      ctrl.startLevel(1);
      ctrl.registerPop(10);
      ctrl.registerPop(10);
      ctrl.resetCombo();
      expect(ctrl.comboMilestoneTick.value, 0);
    });
  });

  group('I27 Prestige/New Game+', () {
    void winLevel(int id) {
      ctrl.startLevel(id);
      ctrl.addScore(
        prestigeTargetScore(kLevels[id - 1], ctrl.prestigeTier.value),
      );
      ctrl.checkEnd(false);
    }

    test('ban đầu: tier 0, chưa đủ điều kiện prestige', () {
      expect(ctrl.prestigeTier.value, 0);
      expect(ctrl.canPrestige, isFalse);
      expect(ctrl.allLevelsCompletedOnce.value, isFalse);
    });

    test('thắng level giữa chừng (không phải level cuối) không mở khoá '
        'prestige', () {
      winLevel(1);
      expect(ctrl.canPrestige, isFalse);
      expect(ctrl.allLevelsCompletedOnce.value, isFalse);
    });

    test('thua level cuối (0 sao) không mở khoá prestige', () {
      ctrl.startLevel(kLevelCount);
      ctrl.addScore(0);
      ctrl.checkEnd(false);
      expect(ctrl.starsEarned.value, 0);
      expect(ctrl.canPrestige, isFalse);
    });

    test('thắng đúng level cuối (kLevelCount) ≥1 sao → mở khoá prestige', () {
      winLevel(kLevelCount);
      expect(ctrl.starsEarned.value, greaterThanOrEqualTo(1));
      expect(ctrl.canPrestige, isTrue);
      expect(ctrl.allLevelsCompletedOnce.value, isTrue);
      expect(StorageService.to.getBool(StorageKeys.allLevelsCompleted), isTrue);
    });

    test('gọi prestige() khi chưa đủ điều kiện → no-op hoàn toàn', () {
      final coinsBefore = ctrl.coins.value;
      ctrl.prestige();
      expect(ctrl.prestigeTier.value, 0);
      expect(ctrl.coins.value, coinsBefore);
      expect(ctrl.unlockedLevel.value, 1);
    });

    test('prestige() khi đủ điều kiện: tăng tier, reset unlockedLevel về 1, '
        'reset allLevelsCompletedOnce, cộng đúng coin thưởng', () {
      winLevel(kLevelCount); // mở khoá điều kiện
      final coinsBefore = ctrl.coins.value;

      ctrl.prestige();

      expect(ctrl.prestigeTier.value, 1);
      expect(ctrl.unlockedLevel.value, 1);
      expect(ctrl.allLevelsCompletedOnce.value, isFalse);
      expect(ctrl.canPrestige, isFalse);
      expect(
        ctrl.coins.value,
        coinsBefore + GameController.prestigeRewardCoins,
      );
      expect(StorageService.to.getInt(StorageKeys.prestigeTier), 1);
      expect(
        StorageService.to.getBool(StorageKeys.allLevelsCompleted),
        isFalse,
      );
    });

    test('gọi prestige() 2 lần liên tiếp (race/double-tap) → lần 2 no-op vì '
        'canPrestige đã về false sau lần 1', () {
      winLevel(kLevelCount);
      ctrl.prestige();
      final tierAfterFirst = ctrl.prestigeTier.value;
      final coinsAfterFirst = ctrl.coins.value;

      ctrl.prestige(); // chưa thắng lại level cuối ở tier mới

      expect(ctrl.prestigeTier.value, tierAfterFirst);
      expect(ctrl.coins.value, coinsAfterFirst);
    });

    test('sau prestige, target level cuối nặng hơn tier trước — điểm cũ đủ '
        'thắng tier 0 có thể không đủ ở tier 1', () {
      final tier0Target = prestigeTargetScore(kLevels[kLevelCount - 1], 0);
      winLevel(kLevelCount);
      ctrl.prestige();
      expect(ctrl.prestigeTier.value, 1);

      final tier1Target = prestigeTargetScore(kLevels[kLevelCount - 1], 1);
      expect(tier1Target, greaterThan(tier0Target));

      ctrl.startLevel(kLevelCount);
      ctrl.addScore(tier0Target); // đủ target tier 0 nhưng chưa đủ tier 1
      ctrl.checkEnd(false);
      expect(ctrl.starsEarned.value, 0);
      expect(ctrl.canPrestige, isFalse);
    });

    test('tier tích luỹ tuần tự: thắng lại level cuối ở tier 1 → mở khoá '
        'prestige lần 2, tăng lên tier 2', () {
      winLevel(kLevelCount);
      ctrl.prestige();
      expect(ctrl.prestigeTier.value, 1);

      winLevel(kLevelCount); // thắng lại ở tier 1 với target đã nặng hơn
      expect(ctrl.canPrestige, isTrue);

      ctrl.prestige();
      expect(ctrl.prestigeTier.value, 2);
      expect(ctrl.unlockedLevel.value, 1);
    });

    test('resetProgress() đưa prestigeTier/allLevelsCompletedOnce về mặc '
        'định', () async {
      winLevel(kLevelCount);
      ctrl.prestige();
      expect(ctrl.prestigeTier.value, 1);

      await ctrl.resetProgress();

      expect(ctrl.prestigeTier.value, 0);
      expect(ctrl.allLevelsCompletedOnce.value, isFalse);
      expect(ctrl.canPrestige, isFalse);
      expect(StorageService.to.getInt(StorageKeys.prestigeTier), 0);
      expect(
        StorageService.to.getBool(StorageKeys.allLevelsCompleted),
        isFalse,
      );
    });

    test('prestige không đụng high-score/star đã lưu trước đó (không phạt '
        'lịch sử chơi)', () {
      winLevel(1);
      final bestBefore = StorageService.to.getInt(StorageKeys.highScore(1));
      final starBefore = StorageService.to.getInt(StorageKeys.star(1));
      expect(bestBefore, greaterThan(0));

      winLevel(kLevelCount);
      ctrl.prestige();

      expect(StorageService.to.getInt(StorageKeys.highScore(1)), bestBefore);
      expect(StorageService.to.getInt(StorageKeys.star(1)), starBefore);
    });
  });

  group('I30 Mascot Wardrobe', () {
    test('ban đầu: skin classic active, chỉ classic được mở khoá', () {
      expect(ctrl.activeMascotSkinId.value, 'classic');
      expect(ctrl.unlockedMascotSkinIds, {'classic'});
      expect(ctrl.activeMascotSkin.id, 'classic');
    });

    test('buySkin() đủ xu → trừ đúng giá, mở khoá skin, trả về true', () {
      ctrl.coins.value = 300;
      final ok = ctrl.buySkin(kMascotSkins.firstWhere((s) => s.id == 'ruby'));
      expect(ok, isTrue);
      expect(ctrl.coins.value, 0);
      expect(ctrl.unlockedMascotSkinIds, contains('ruby'));
      expect(
        StorageService.to.getString(StorageKeys.unlockedMascotSkins),
        contains('ruby'),
      );
    });

    test('buySkin() thiếu xu → không trừ, không mở khoá, trả về false', () {
      ctrl.coins.value = 100;
      final ruby = kMascotSkins.firstWhere((s) => s.id == 'ruby');
      final ok = ctrl.buySkin(ruby);
      expect(ok, isFalse);
      expect(ctrl.coins.value, 100);
      expect(ctrl.unlockedMascotSkinIds, isNot(contains('ruby')));
    });

    test('buySkin() skin đã mở khoá (double-buy/race) → no-op, không trừ '
        'xu lần 2', () {
      ctrl.coins.value = 1000;
      final ruby = kMascotSkins.firstWhere((s) => s.id == 'ruby');
      expect(ctrl.buySkin(ruby), isTrue);
      final coinsAfterFirstBuy = ctrl.coins.value;
      expect(ctrl.buySkin(ruby), isFalse);
      expect(ctrl.coins.value, coinsAfterFirstBuy);
    });

    test('buySkin() skin mở khoá bằng thành tựu (coinPrice null) → luôn '
        'trả về false dù đủ xu', () {
      ctrl.coins.value = 999999;
      final aurora = kMascotSkins.firstWhere((s) => s.id == 'aurora');
      final ok = ctrl.buySkin(aurora);
      expect(ok, isFalse);
      expect(ctrl.coins.value, 999999);
      expect(ctrl.unlockedMascotSkinIds, isNot(contains('aurora')));
    });

    test('selectMascotSkin() skin đã mở khoá → thành công, đổi active', () {
      ctrl.coins.value = 300;
      ctrl.buySkin(kMascotSkins.firstWhere((s) => s.id == 'ruby'));
      final ok = ctrl.selectMascotSkin('ruby');
      expect(ok, isTrue);
      expect(ctrl.activeMascotSkinId.value, 'ruby');
      expect(ctrl.activeMascotSkin.id, 'ruby');
    });

    test('selectMascotSkin() skin chưa mở khoá → false, active không đổi', () {
      final ok = ctrl.selectMascotSkin('sapphire');
      expect(ok, isFalse);
      expect(ctrl.activeMascotSkinId.value, 'classic');
    });

    test('selectMascotSkin() id giả mạo/không tồn tại → false, không crash, '
        'activeMascotSkin fallback về skin đầu tiên', () {
      final ok = ctrl.selectMascotSkin('id_khong_ton_tai_gia_mao');
      expect(ok, isFalse);
      expect(ctrl.activeMascotSkinId.value, 'classic');
      expect(ctrl.activeMascotSkin.id, 'classic');
    });

    test('đạt combo 25 (mốc combo_25) → tự động mở khoá skin aurora, '
        'không trừ xu mua skin', () {
      ctrl.startLevel(1);
      for (var i = 0; i < 25; i++) {
        ctrl.registerPop(10);
      }
      expect(ctrl.maxComboEver.value, 25);
      expect(ctrl.unlockedAchievementIds, contains('combo_25'));
      expect(ctrl.unlockedMascotSkinIds, contains('aurora'));
      expect(
        StorageService.to.getString(StorageKeys.unlockedMascotSkins),
        contains('aurora'),
      );
    });

    test('dọn xong 400 bàn (mốc clear_400) → tự động mở khoá skin '
        'obsidian', () {
      for (var i = 0; i < 400; i++) {
        ctrl.startLevel(1);
        ctrl.checkEnd(true);
      }
      expect(ctrl.boardsFullyCleared.value, 400);
      expect(ctrl.unlockedAchievementIds, contains('clear_400'));
      expect(ctrl.unlockedMascotSkinIds, contains('obsidian'));
    });

    test('resetProgress() đưa mascot wardrobe về mặc định: chỉ classic, '
        'active = classic', () async {
      ctrl.coins.value = 300;
      ctrl.buySkin(kMascotSkins.firstWhere((s) => s.id == 'ruby'));
      ctrl.selectMascotSkin('ruby');
      expect(ctrl.activeMascotSkinId.value, 'ruby');

      await ctrl.resetProgress();

      expect(ctrl.activeMascotSkinId.value, 'classic');
      expect(ctrl.unlockedMascotSkinIds, {'classic'});
      expect(StorageService.to.getString(StorageKeys.activeMascotSkin), isNull);
      expect(
        StorageService.to.getString(StorageKeys.unlockedMascotSkins),
        isNull,
      );
    });
  });

  group('I48 Login Streak Calendar', () {
    int todayEpochDay() =>
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;

    GameController relaunch() {
      Get.delete<GameController>(force: true);
      return Get.put(GameController(), permanent: true);
    }

    test('lần đầu mở app (chưa từng điểm danh) → streak=1, mask=0', () {
      expect(ctrl.loginStreakCount.value, 1);
      expect(ctrl.loginStreakClaimedMask.value, 0);
      expect(ctrl.dayInCycle(ctrl.loginStreakCount.value), 1);
    });

    test('mở app lại trong cùng ngày → giữ nguyên streak/mask', () {
      final streakBefore = ctrl.loginStreakCount.value;
      final again = relaunch();
      expect(again.loginStreakCount.value, streakBefore);
      expect(again.loginStreakClaimedMask.value, 0);
    });

    test('qua đúng 1 ngày → streak +1, giữ mask nếu chưa qua cycle mới', () {
      StorageService.to.setInt(
        StorageKeys.lastLoginEpochDay,
        todayEpochDay() - 1,
      );
      StorageService.to.setInt(StorageKeys.loginStreakCount, 2);
      StorageService.to.setInt(StorageKeys.loginStreakClaimedMask, 0);

      final next = relaunch();
      expect(next.loginStreakCount.value, 3);
      expect(next.loginStreakClaimedMask.value, 0);
    });

    test('bỏ ≥2 ngày → reset streak về 1, xoá mask thưởng đã nhận', () {
      StorageService.to.setInt(
        StorageKeys.lastLoginEpochDay,
        todayEpochDay() - 5,
      );
      StorageService.to.setInt(StorageKeys.loginStreakCount, 6);
      StorageService.to.setInt(
        StorageKeys.loginStreakClaimedMask,
        (1 << 3) | (1 << 5),
      );

      final next = relaunch();
      expect(next.loginStreakCount.value, 1);
      expect(next.loginStreakClaimedMask.value, 0);
    });

    test('streak liên tục chạm ngày 8 (qua cycle mới) → reset mask, '
        'dayInCycle về 1', () {
      StorageService.to.setInt(
        StorageKeys.lastLoginEpochDay,
        todayEpochDay() - 1,
      );
      StorageService.to.setInt(StorageKeys.loginStreakCount, 7);
      StorageService.to.setInt(
        StorageKeys.loginStreakClaimedMask,
        (1 << 3) | (1 << 5) | (1 << 7),
      );

      final next = relaunch();
      expect(next.loginStreakCount.value, 8);
      expect(next.dayInCycle(next.loginStreakCount.value), 1);
      expect(next.loginStreakClaimedMask.value, 0);
    });

    test('claim đúng ngày 3/5/7 cộng đúng xu, ngày khác không có thưởng', () {
      ctrl.loginStreakCount.value = 2;
      expect(ctrl.claimLoginStreakReward(), isFalse);
      expect(ctrl.coins.value, 0);

      ctrl.loginStreakCount.value = 3;
      expect(ctrl.claimLoginStreakReward(), isTrue);
      expect(
        ctrl.coins.value,
        GameController.loginStreakRewards[3]! * ctrl.weekendCoinMultiplier,
      );
    });

    test('claim 2 lần cùng ngày → lần 2 false, không cộng thêm xu', () {
      ctrl.loginStreakCount.value = 5;
      expect(ctrl.claimLoginStreakReward(), isTrue);
      final coinsAfterFirst = ctrl.coins.value;
      expect(ctrl.claimLoginStreakReward(), isFalse);
      expect(ctrl.coins.value, coinsAfterFirst);
    });

    test('claim ngày 7 cộng đúng số xu mốc lớn nhất', () {
      ctrl.loginStreakCount.value = 7;
      expect(ctrl.claimLoginStreakReward(), isTrue);
      expect(
        ctrl.coins.value,
        GameController.loginStreakRewards[7]! * ctrl.weekendCoinMultiplier,
      );
    });

    test('resetProgress() đưa streak/mask về mặc định', () async {
      StorageService.to.setInt(
        StorageKeys.lastLoginEpochDay,
        todayEpochDay() - 1,
      );
      StorageService.to.setInt(StorageKeys.loginStreakCount, 4);
      final ctrl2 = relaunch();
      expect(ctrl2.loginStreakCount.value, 5);

      await ctrl2.resetProgress();
      expect(ctrl2.loginStreakCount.value, 1);
      expect(ctrl2.loginStreakClaimedMask.value, 0);
      expect(
        StorageService.to.getInt(StorageKeys.lastLoginEpochDay, def: -1),
        todayEpochDay(),
      );
    });
  });

  group('X5 shouldRequestReview — điều kiện thuần', () {
    test('3 sao + chưa hiện lần nào → true', () {
      expect(
        GameController.shouldRequestReview(stars: 3, alreadyShown: false),
        isTrue,
      );
    });

    test('3 sao nhưng đã hiện rồi → false (không hiện lại lần 2)', () {
      expect(
        GameController.shouldRequestReview(stars: 3, alreadyShown: true),
        isFalse,
      );
    });

    test('1 hoặc 2 sao (chưa mốc tích cực nhất) → false', () {
      expect(
        GameController.shouldRequestReview(stars: 1, alreadyShown: false),
        isFalse,
      );
      expect(
        GameController.shouldRequestReview(stars: 2, alreadyShown: false),
        isFalse,
      );
    });

    test('0 sao (thua) → false, không hiện sau khi thua', () {
      expect(
        GameController.shouldRequestReview(stars: 0, alreadyShown: false),
        isFalse,
      );
    });
  });
}

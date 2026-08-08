import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/burst_styles.dart';
import 'package:pop_star_blast/data/clan.dart';
import 'package:pop_star_blast/data/combo_text_styles.dart';
import 'package:pop_star_blast/data/gauntlet_modifiers.dart';
import 'package:pop_star_blast/data/levels.dart';
import 'package:pop_star_blast/data/mascot_skins.dart';
import 'package:pop_star_blast/data/weekly_featured.dart';
import 'package:pop_star_blast/data/weekly_goal.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/logic/challenge_code.dart';
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

  group('I32 Craft Booster', () {
    test('thắng, chưa full-clear, đủ ngưỡng craft point → +1 booster', () {
      ctrl.startLevel(1);
      ctrl.addScore(target);
      ctrl.activeGame = PopStarGame(ctrl)
        ..colorGrid = List.generate(4, (_) => List.generate(4, (_) => 0));
      final before =
          ctrl.bombCount.value + ctrl.shuffleCount.value + ctrl.undoCount.value;
      ctrl.checkEnd(false);
      expect(ctrl.craftRewardType.value, isNotNull);
      expect(
        ctrl.bombCount.value + ctrl.shuffleCount.value + ctrl.undoCount.value,
        before + 1,
      );
    });

    test(
      'thắng, chưa full-clear, chưa đủ ngưỡng craft point → không thưởng',
      () {
        ctrl.startLevel(1);
        ctrl.addScore(target);
        ctrl.activeGame = PopStarGame(ctrl)
          ..colorGrid = List.generate(2, (_) => List.generate(2, (_) => 0));
        final before =
            ctrl.bombCount.value +
            ctrl.shuffleCount.value +
            ctrl.undoCount.value;
        ctrl.checkEnd(false);
        expect(ctrl.craftRewardType.value, isNull);
        expect(
          ctrl.bombCount.value + ctrl.shuffleCount.value + ctrl.undoCount.value,
          before,
        );
      },
    );

    test('full-clear (boardCleared=true) → không cộng trùng craft booster', () {
      ctrl.startLevel(1);
      ctrl.addScore(target);
      ctrl.activeGame = PopStarGame(ctrl)
        ..colorGrid = List.generate(4, (_) => List.generate(4, (_) => 0));
      final before =
          ctrl.bombCount.value + ctrl.shuffleCount.value + ctrl.undoCount.value;
      ctrl.checkEnd(true);
      expect(ctrl.craftRewardType.value, isNull);
      expect(
        ctrl.bombCount.value + ctrl.shuffleCount.value + ctrl.undoCount.value,
        before,
      );
    });

    test('thua (dưới target) → không thưởng craft booster', () {
      ctrl.startLevel(1);
      ctrl.addScore(target - 1);
      ctrl.activeGame = PopStarGame(ctrl)
        ..colorGrid = List.generate(4, (_) => List.generate(4, (_) => 0));
      ctrl.checkEnd(false);
      expect(ctrl.craftRewardType.value, isNull);
    });

    test('startLevel reset craftRewardType về null', () {
      ctrl.startLevel(1);
      ctrl.addScore(target);
      ctrl.activeGame = PopStarGame(ctrl)
        ..colorGrid = List.generate(4, (_) => List.generate(4, (_) => 0));
      ctrl.checkEnd(false);
      expect(ctrl.craftRewardType.value, isNotNull);

      ctrl.startLevel(1);
      expect(ctrl.craftRewardType.value, isNull);
    });
  });

  group('I37 Async Challenge Code', () {
    const challenge = ChallengeCode(levelId: 1, score: 500, senderName: 'Roy');

    test('checkEnd: điểm cao hơn mã thách đấu → challengeWon = true', () {
      ctrl.startChallenge(challenge);
      ctrl.addScore(challenge.score + 1);
      ctrl.activeGame = PopStarGame(ctrl)
        ..colorGrid = List.generate(4, (_) => List.generate(4, (_) => 0));
      ctrl.checkEnd(false);
      expect(ctrl.challengeWon.value, isTrue);
    });

    test('checkEnd: điểm thấp hơn mã thách đấu → challengeWon = false', () {
      ctrl.startChallenge(challenge);
      ctrl.addScore(challenge.score - 1);
      ctrl.activeGame = PopStarGame(ctrl)
        ..colorGrid = List.generate(4, (_) => List.generate(4, (_) => 0));
      ctrl.checkEnd(false);
      expect(ctrl.challengeWon.value, isFalse);
    });

    test('checkEnd: điểm bằng đúng mã thách đấu (hoà) → tính là thua', () {
      ctrl.startChallenge(challenge);
      ctrl.addScore(challenge.score);
      ctrl.activeGame = PopStarGame(ctrl)
        ..colorGrid = List.generate(4, (_) => List.generate(4, (_) => 0));
      ctrl.checkEnd(false);
      expect(ctrl.challengeWon.value, isFalse);
    });

    test('checkEnd: không có thách đấu → challengeWon vẫn null', () {
      ctrl.startLevel(1);
      ctrl.addScore(target);
      ctrl.activeGame = PopStarGame(ctrl)
        ..colorGrid = List.generate(4, (_) => List.generate(4, (_) => 0));
      ctrl.checkEnd(false);
      expect(ctrl.challengeWon.value, isNull);
    });

    test('startLevel reset activeChallenge và challengeWon về null', () {
      ctrl.startChallenge(challenge);
      ctrl.addScore(challenge.score + 1);
      ctrl.activeGame = PopStarGame(ctrl)
        ..colorGrid = List.generate(4, (_) => List.generate(4, (_) => 0));
      ctrl.checkEnd(false);
      expect(ctrl.activeChallenge.value, isNotNull);
      expect(ctrl.challengeWon.value, isNotNull);

      ctrl.startLevel(1);
      expect(ctrl.activeChallenge.value, isNull);
      expect(ctrl.challengeWon.value, isNull);
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

    test(
      'xoá activeAchievementTitleId về rỗng (tránh danh hiệu "ma")',
      () async {
        ctrl.startLevel(1);
        ctrl.registerPop(10, groupSize: 500); // mở khoá gems_500
        await ctrl.setActiveTitle('gems_500');
        expect(ctrl.activeAchievementTitleId.value, 'gems_500');

        await ctrl.resetProgress();
        expect(ctrl.activeAchievementTitleId.value, isEmpty);
      },
    );
  });

  group('I36 Achievement Titles', () {
    test('setActiveTitle với id chưa unlock → không đổi giá trị', () async {
      await ctrl.setActiveTitle('gems_500');
      expect(ctrl.activeAchievementTitleId.value, isEmpty);
      expect(ctrl.activeTitleAchievement, isNull);
    });

    test('setActiveTitle với id đã unlock → set đúng + persist', () async {
      ctrl.startLevel(1);
      ctrl.registerPop(10, groupSize: 500); // mở khoá gems_500
      await ctrl.setActiveTitle('gems_500');
      expect(ctrl.activeAchievementTitleId.value, 'gems_500');
      expect(ctrl.activeTitleAchievement?.id, 'gems_500');
      expect(
        StorageService.to.getString(StorageKeys.activeAchievementTitleId),
        'gems_500',
      );
    });

    test('clearActiveTitle xoá về rỗng + persist', () async {
      ctrl.startLevel(1);
      ctrl.registerPop(10, groupSize: 500);
      await ctrl.setActiveTitle('gems_500');
      await ctrl.clearActiveTitle();
      expect(ctrl.activeAchievementTitleId.value, isEmpty);
      expect(ctrl.activeTitleAchievement, isNull);
      expect(
        StorageService.to.getString(StorageKeys.activeAchievementTitleId),
        isEmpty,
      );
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
        // I77: totalGemsPopped=500 cũng mở khoá burst style "confetti"
        // (threshold 500), đẩy totalCosmeticsOwned 4 -> 5, vượt luôn mốc
        // sticker album đầu tiên — 2 hệ thống cộng xu độc lập cùng lúc.
        expect(
          ctrl.coins.value,
          (50 + GameController.stickerAlbumRewards[0]) *
              ctrl.weekendCoinMultiplier,
        );
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

  group('I33 Daily Modifier Gauntlet', () {
    test('startGauntlet sinh bàn từ seed hôm nay, gọi lại cùng ngày ra '
        'cùng bàn và cùng modifier', () {
      ctrl.startGauntlet();
      final grid1 = ctrl.gauntletGrid;
      final modifier1 = ctrl.activeGauntletModifier;
      ctrl.startGauntlet();
      final grid2 = ctrl.gauntletGrid;
      expect(ctrl.mode.value, GameMode.gauntlet);
      expect(ctrl.currentLevel.id, gauntletLevelFor(modifier1!).id);
      expect(grid1, equals(grid2));
      expect(ctrl.activeGauntletModifier?.id, modifier1.id);
    });

    test('modifier hôm nay khớp modifierForDay(epochDay hiện tại)', () {
      final today = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
      ctrl.startGauntlet();
      expect(ctrl.activeGauntletModifier?.id, modifierForDay(today).id);
    });

    test('ghi điểm lần đầu trong ngày, chơi lại trong ngày không đè điểm', () {
      ctrl.startGauntlet();
      ctrl.score.value = 500;
      expect(ctrl.canRecordGauntletScore, isTrue);
      ctrl.checkEnd(false);
      expect(ctrl.gauntletScoreToday, 500);
      expect(ctrl.canRecordGauntletScore, isFalse);

      ctrl.startGauntlet();
      ctrl.score.value = 900;
      ctrl.checkEnd(false);
      expect(ctrl.gauntletScoreToday, 500);
    });

    test('gauntletScoreForLeaderboard = 0 khi chưa chơi hôm nay, không lộ '
        'điểm ngày cũ', () {
      expect(ctrl.canRecordGauntletScore, isTrue);
      expect(ctrl.gauntletScoreForLeaderboard, 0);

      ctrl.startGauntlet();
      ctrl.score.value = 500;
      ctrl.checkEnd(false);
      expect(ctrl.gauntletScoreForLeaderboard, 500);
    });

    test('lastGauntletDay khác hôm nay (giả lập qua ngày mới) → ghi điểm '
        'lại được', () {
      ctrl.startGauntlet();
      ctrl.score.value = 300;
      ctrl.checkEnd(false);
      expect(ctrl.canRecordGauntletScore, isFalse);

      final yesterday =
          DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000 - 1;
      StorageService.to.setInt(StorageKeys.lastGauntletDay, yesterday);
      expect(ctrl.canRecordGauntletScore, isTrue);
    });

    test('activeComboWindowOverride chỉ khác null khi mode có modifier và '
        'modifier có comboWindowOverride', () {
      ctrl.startLevel(1);
      expect(ctrl.activeComboWindowOverride, isNull);

      ctrl.activeGauntletModifier = kGauntletModifiers.firstWhere(
        (m) => m.id == 'short_combo',
      );
      ctrl.startGauntlet();
      ctrl.activeGauntletModifier = kGauntletModifiers.firstWhere(
        (m) => m.id == 'short_combo',
      );
      expect(ctrl.activeComboWindowOverride, 1.5);

      ctrl.activeGauntletModifier = kGauntletModifiers.firstWhere(
        (m) => m.id == 'no_undo',
      );
      expect(ctrl.activeComboWindowOverride, isNull);
    });

    test('modifier no_undo chặn useUndo(), modifier khác thì không', () {
      ctrl.startGauntlet();
      ctrl.activeGame = PopStarGame(ctrl)
        ..colorGrid = List.generate(4, (_) => List.generate(4, (_) => 0));
      final gridBefore = ctrl.activeGame!.colorGrid
          .map((row) => List<int?>.from(row))
          .toList();

      ctrl.activeGauntletModifier = kGauntletModifiers.firstWhere(
        (m) => m.id == 'no_undo',
      );
      ctrl.useUndo();
      expect(ctrl.activeGame!.colorGrid, equals(gridBefore));

      ctrl.activeGauntletModifier = kGauntletModifiers.firstWhere(
        (m) => m.id == 'four_colors',
      );
      expect(() => ctrl.useUndo(), returnsNormally);
    });
  });

  group('I38 Weekly Featured Level', () {
    test('featuredLevelId chưa mở khoá → fallback về level chắc chắn đã mở '
        '(unlockedLevel = 1 → luôn ra level 1)', () {
      expect(ctrl.unlockedLevel.value, 1);
      expect(ctrl.featuredLevelId, 1);
    });

    test(
      'featuredLevelId đã mở khoá đủ xa → dùng thẳng featuredLevelIdForWeek, '
      'không qua fallback',
      () {
        ctrl.unlockedLevel.value = kLevelCount;
        expect(
          ctrl.featuredLevelId,
          featuredLevelIdForWeek(ctrl.currentWeekIndex),
        );
      },
    );

    test(
      'featuredLevelId deterministic — gọi lại nhiều lần ra cùng kết quả',
      () {
        ctrl.unlockedLevel.value = kLevelCount;
        final id1 = ctrl.featuredLevelId;
        final id2 = ctrl.featuredLevelId;
        expect(id1, id2);
      },
    );

    test('startWeeklyFeatured() set mode weeklyFeatured, chơi lại đúng '
        'featuredLevelId, reset toàn bộ state ván mới', () {
      ctrl.startLevel(1);
      ctrl.addScore(500);
      ctrl.movesUsed.value = 3;
      ctrl.hintCount.value = 0;

      ctrl.startWeeklyFeatured();

      expect(ctrl.mode.value, GameMode.weeklyFeatured);
      expect(ctrl.currentLevel.id, ctrl.featuredLevelId);
      expect(ctrl.score.value, 0);
      expect(ctrl.starsEarned.value, 0);
      expect(ctrl.ended.value, isFalse);
      expect(ctrl.cleared.value, isFalse);
      expect(ctrl.movesUsed.value, 0);
      expect(ctrl.hintCount.value, GameController.hintsPerRun);
    });

    test('featuredLevelScore chỉ tăng khi điểm mới cao hơn, không giảm trong '
        'cùng tuần', () {
      expect(ctrl.featuredLevelScore, 0);

      ctrl.startWeeklyFeatured();
      ctrl.score.value = 800;
      ctrl.checkEnd(false);
      expect(ctrl.featuredLevelScore, 800);

      ctrl.startWeeklyFeatured();
      ctrl.score.value = 300;
      ctrl.checkEnd(false);
      expect(ctrl.featuredLevelScore, 800);

      ctrl.startWeeklyFeatured();
      ctrl.score.value = 1200;
      ctrl.checkEnd(false);
      expect(ctrl.featuredLevelScore, 1200);
    });

    test(
      'featuredLevelScore tự về 0 khi tuần đổi (khác currentWeekIndex đã lưu)',
      () {
        ctrl.startWeeklyFeatured();
        ctrl.score.value = 700;
        ctrl.checkEnd(false);
        expect(ctrl.featuredLevelScore, 700);

        StorageService.to.setInt(
          StorageKeys.lastFeaturedWeekSeen,
          ctrl.currentWeekIndex - 1,
        );
        expect(ctrl.featuredLevelScore, 0);
      },
    );

    test('resetProgress() xoá sạch state Weekly Featured Level', () async {
      ctrl.startWeeklyFeatured();
      ctrl.score.value = 400;
      ctrl.checkEnd(false);
      expect(ctrl.featuredLevelScore, 400);

      await ctrl.resetProgress();
      expect(ctrl.featuredLevelScore, 0);
    });
  });

  group('I80 Remix Levels', () {
    test('kRemixLevels: mọi entry đều tham chiếu levelId hợp lệ trong '
        '1..kLevelCount', () {
      for (final remix in kRemixLevels) {
        expect(remix.levelId, greaterThanOrEqualTo(1));
        expect(remix.levelId, lessThanOrEqualTo(kLevelCount));
      }
    });

    test('startRemixLevel() set mode remixLevel, load đúng level, đúng '
        'modifier, reset toàn bộ state ván mới', () {
      ctrl.startLevel(1);
      ctrl.addScore(500);
      ctrl.movesUsed.value = 3;
      ctrl.hintCount.value = 0;

      final remix = kRemixLevels.first;
      ctrl.startRemixLevel(remix.levelId, remix.modifier);

      expect(ctrl.mode.value, GameMode.remixLevel);
      expect(ctrl.currentLevel.id, remix.levelId);
      expect(ctrl.activeRemixModifier?.id, remix.modifier.id);
      expect(ctrl.score.value, 0);
      expect(ctrl.starsEarned.value, 0);
      expect(ctrl.ended.value, isFalse);
      expect(ctrl.cleared.value, isFalse);
      expect(ctrl.movesUsed.value, 0);
      expect(ctrl.hintCount.value, GameController.hintsPerRun);
    });

    test('activeGameplayModifier trả đúng activeRemixModifier khi mode là '
        'remixLevel, áp cả activeMoveLimit lẫn activeComboWindowOverride', () {
      final noUndoEntry = kRemixLevels.firstWhere(
        (r) => r.modifier.id == 'no_undo',
      );
      ctrl.startRemixLevel(noUndoEntry.levelId, noUndoEntry.modifier);
      expect(ctrl.activeGameplayModifier?.id, 'no_undo');

      final shortComboEntry = kRemixLevels.firstWhere(
        (r) => r.modifier.id == 'short_combo',
      );
      ctrl.startRemixLevel(shortComboEntry.levelId, shortComboEntry.modifier);
      expect(ctrl.activeComboWindowOverride, 1.5);
    });

    test('remixBestFor: chỉ tăng khi điểm mới cao hơn, best riêng theo từng '
        'levelId, không lẫn giữa các entry', () {
      final entryA = kRemixLevels[0];
      final entryB = kRemixLevels[1];
      expect(ctrl.remixBestFor(entryA.levelId), 0);
      expect(ctrl.remixBestFor(entryB.levelId), 0);

      ctrl.startRemixLevel(entryA.levelId, entryA.modifier);
      ctrl.score.value = 800;
      ctrl.checkEnd(false);
      expect(ctrl.remixBestFor(entryA.levelId), 800);
      expect(ctrl.remixBestFor(entryB.levelId), 0);

      ctrl.startRemixLevel(entryA.levelId, entryA.modifier);
      ctrl.score.value = 300;
      ctrl.checkEnd(false);
      expect(ctrl.remixBestFor(entryA.levelId), 800);

      ctrl.startRemixLevel(entryA.levelId, entryA.modifier);
      ctrl.score.value = 1200;
      ctrl.checkEnd(false);
      expect(ctrl.remixBestFor(entryA.levelId), 1200);
    });
  });

  group('I75 Combo Rush', () {
    test('startSideMode(comboRush) set mode, load kComboRushLevel, không '
        'đụng unlockedLevel campaign', () {
      ctrl.startLevel(1);
      ctrl.startSideMode(GameMode.comboRush);
      expect(ctrl.mode.value, GameMode.comboRush);
      expect(ctrl.currentLevel.id, kComboRushLevel.id);
      expect(ctrl.unlockedLevel.value, 1);
    });

    test('checkEnd ở Combo Rush không mở khoá/thưởng xu/lưu highScore '
        'campaign', () {
      ctrl.startSideMode(GameMode.comboRush);
      ctrl.addScore(9999);
      ctrl.checkEnd(false);
      expect(ctrl.ended.value, isTrue);
      expect(ctrl.starsEarned.value, 0);
      expect(ctrl.unlockedLevel.value, 1);
      expect(ctrl.coins.value, 0);
      expect(StorageService.to.getInt(StorageKeys.highScore(1)), 0);
    });

    test('Combo Rush: chỉ lưu best khi điểm mới cao hơn', () {
      ctrl.startSideMode(GameMode.comboRush);
      ctrl.addScore(100);
      ctrl.checkEnd(false);
      expect(ctrl.comboRushBest.value, 100);

      ctrl.startSideMode(GameMode.comboRush);
      ctrl.addScore(50);
      ctrl.checkEnd(false);
      expect(ctrl.comboRushBest.value, 100);

      ctrl.startSideMode(GameMode.comboRush);
      ctrl.addScore(200);
      ctrl.checkEnd(false);
      expect(ctrl.comboRushBest.value, 200);
    });

    test('resetProgress xoá comboRushBest', () async {
      ctrl.startSideMode(GameMode.comboRush);
      ctrl.addScore(300);
      ctrl.checkEnd(false);
      expect(ctrl.comboRushBest.value, 300);

      await ctrl.resetProgress();
      expect(ctrl.comboRushBest.value, 0);
    });
  });

  group('I76b Frost Rush', () {
    test('startSideMode(frostRush) set mode, load kFrostRushLevel, không '
        'đụng unlockedLevel campaign', () {
      ctrl.startLevel(1);
      ctrl.startSideMode(GameMode.frostRush);
      expect(ctrl.mode.value, GameMode.frostRush);
      expect(ctrl.currentLevel.id, kFrostRushLevel.id);
      expect(ctrl.unlockedLevel.value, 1);
    });

    test('checkEnd ở Frost Rush không mở khoá/thưởng xu/lưu highScore '
        'campaign', () {
      ctrl.startSideMode(GameMode.frostRush);
      ctrl.addScore(9999);
      ctrl.checkEnd(false);
      expect(ctrl.ended.value, isTrue);
      expect(ctrl.starsEarned.value, 0);
      expect(ctrl.unlockedLevel.value, 1);
      expect(ctrl.coins.value, 0);
      expect(StorageService.to.getInt(StorageKeys.highScore(1)), 0);
    });

    test('Frost Rush: chỉ lưu best khi điểm mới cao hơn, độc lập với '
        'comboRushBest', () {
      ctrl.startSideMode(GameMode.frostRush);
      ctrl.addScore(100);
      ctrl.checkEnd(false);
      expect(ctrl.frostRushBest.value, 100);
      expect(ctrl.comboRushBest.value, 0);

      ctrl.startSideMode(GameMode.frostRush);
      ctrl.addScore(50);
      ctrl.checkEnd(false);
      expect(ctrl.frostRushBest.value, 100);

      ctrl.startSideMode(GameMode.frostRush);
      ctrl.addScore(200);
      ctrl.checkEnd(false);
      expect(ctrl.frostRushBest.value, 200);
    });

    test('resetProgress xoá frostRushBest', () async {
      ctrl.startSideMode(GameMode.frostRush);
      ctrl.addScore(300);
      ctrl.checkEnd(false);
      expect(ctrl.frostRushBest.value, 300);

      await ctrl.resetProgress();
      expect(ctrl.frostRushBest.value, 0);
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

    test('save cũ trước Round-8 (allLevelsCompleted=true, chưa có '
        'allLevelsCompletedAtCount) → migrate về false khi campaign mở '
        'rộng (bug do codex phát hiện, 240→260)', () {
      StorageService.to.setBool(StorageKeys.allLevelsCompleted, true);
      Get.delete<GameController>(force: true);
      final relaunched = Get.put(GameController(), permanent: true);

      expect(relaunched.allLevelsCompletedOnce.value, isFalse);
      expect(relaunched.canPrestige, isFalse);
      expect(
        StorageService.to.getBool(StorageKeys.allLevelsCompleted),
        isFalse,
      );
    });

    test('save đã hoàn thành đúng kLevelCount hiện tại (có '
        'allLevelsCompletedAtCount khớp) → giữ nguyên canPrestige=true khi '
        'relaunch', () {
      winLevel(kLevelCount);
      expect(ctrl.canPrestige, isTrue);
      Get.delete<GameController>(force: true);
      final relaunched = Get.put(GameController(), permanent: true);

      expect(relaunched.allLevelsCompletedOnce.value, isTrue);
      expect(relaunched.canPrestige, isTrue);
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

  group('I50 Weekly Goal Card', () {
    GameController relaunch() {
      Get.delete<GameController>(force: true);
      return Get.put(GameController(), permanent: true);
    }

    test('mới cài app → tiến độ 0, chưa nhận thưởng', () {
      expect(ctrl.weeklyGoalProgress.value, 0);
      expect(ctrl.weeklyGoalClaimed, isFalse);
    });

    test('registerPop cộng dồn tiến độ theo groupSize, mọi mode', () {
      ctrl.registerPop(10, groupSize: 4);
      expect(ctrl.weeklyGoalProgress.value, 4);
      ctrl.registerPop(20, groupSize: 3);
      expect(ctrl.weeklyGoalProgress.value, 7);
    });

    test('tiến độ không vượt quá target dù cộng dư', () {
      ctrl.addWeeklyGoalProgress(weeklyGoalTarget + 50);
      expect(ctrl.weeklyGoalProgress.value, weeklyGoalTarget);
    });

    test('claim khi chưa đủ tiến độ → false, không cộng xu', () {
      ctrl.addWeeklyGoalProgress(weeklyGoalTarget - 1);
      expect(ctrl.claimWeeklyGoalReward(), isFalse);
      expect(ctrl.coins.value, 0);
    });

    test('đủ tiến độ → claim thành công đúng 1 lần, lần 2 trong cùng tuần '
        'trả về false và không cộng thêm xu', () {
      ctrl.addWeeklyGoalProgress(weeklyGoalTarget);
      expect(ctrl.claimWeeklyGoalReward(), isTrue);
      final coinsAfterFirst = ctrl.coins.value;
      expect(coinsAfterFirst, greaterThan(0));
      expect(ctrl.weeklyGoalClaimed, isTrue);

      expect(ctrl.claimWeeklyGoalReward(), isFalse);
      expect(ctrl.coins.value, coinsAfterFirst);
    });

    test('sang tuần mới → tiến độ reset về 0, cho claim lại', () {
      final lastWeek = ctrl.currentWeekIndex - 1;
      StorageService.to.setInt(StorageKeys.weeklyGoalWeek, lastWeek);
      StorageService.to.setInt(
        StorageKeys.weeklyGoalProgress,
        weeklyGoalTarget,
      );
      StorageService.to.setInt(StorageKeys.weeklyGoalClaimedWeek, lastWeek);

      final next = relaunch();
      expect(next.weeklyGoalProgress.value, 0);
      expect(next.weeklyGoalClaimed, isFalse);

      next.addWeeklyGoalProgress(weeklyGoalTarget);
      expect(next.claimWeeklyGoalReward(), isTrue);
    });

    test(
      'resetProgress() đưa tiến độ/trạng thái nhận thưởng về mặc định',
      () async {
        ctrl.addWeeklyGoalProgress(weeklyGoalTarget);
        ctrl.claimWeeklyGoalReward();

        await ctrl.resetProgress();
        expect(ctrl.weeklyGoalProgress.value, 0);
        expect(ctrl.weeklyGoalClaimed, isFalse);
      },
    );
  });

  group('I66 Clan Lite', () {
    GameController relaunch() {
      Get.delete<GameController>(force: true);
      return Get.put(GameController(), permanent: true);
    }

    test('mới cài app → đóng góp 0, chưa nhận thưởng pool', () {
      expect(ctrl.clanContribWeek.value, 0);
      expect(ctrl.clanContribTotal.value, 0);
      expect(ctrl.clanGoalClaimed, isFalse);
    });

    test('registerPop cộng dồn đóng góp clan theo groupSize, mọi mode', () {
      ctrl.registerPop(10, groupSize: 4);
      expect(ctrl.clanContribWeek.value, 4);
      expect(ctrl.clanContribTotal.value, 4);
      ctrl.registerPop(20, groupSize: 3);
      expect(ctrl.clanContribWeek.value, 7);
      expect(ctrl.clanContribTotal.value, 7);
    });

    test('claim khi pool cả clan chưa đủ target → false, không cộng xu', () {
      final botsSum = clanPoolTotal(ctrl.currentWeekIndex, 0);
      if (botsSum >= clanGoalTarget) {
        // Tuần thật hiện tại (seed theo currentWeekIndex) hoạ hiếm khiến 6 bot
        // tự cộng vượt target dù người chơi đóng góp 0 — addClanContribution
        // chỉ cộng, không trừ được nên không dựng lại nổi trạng thái "chưa
        // đủ" cho tuần này. Bỏ qua thay vì fail giả — không phải bug logic.
        markTestSkipped(
          'Tuần hiện tại bot tự đạt $botsSum ≥ target $clanGoalTarget',
        );
        return;
      }
      final missing = clanGoalTarget - botsSum;
      if (missing > 1) ctrl.addClanContribution(missing - 1);
      expect(ctrl.clanPoolThisWeek, lessThan(clanGoalTarget));
      expect(ctrl.claimClanGoalReward(), isFalse);
      expect(ctrl.coins.value, 0);
    });

    test('đủ pool cả clan → claim thành công đúng 1 lần, lần 2 trong cùng '
        'tuần trả về false và không cộng thêm xu', () {
      final botsSum = clanPoolTotal(ctrl.currentWeekIndex, 0);
      final needed = (clanGoalTarget - botsSum).clamp(0, clanGoalTarget);
      ctrl.addClanContribution(needed);
      expect(ctrl.clanPoolThisWeek, greaterThanOrEqualTo(clanGoalTarget));

      expect(ctrl.claimClanGoalReward(), isTrue);
      final coinsAfterFirst = ctrl.coins.value;
      expect(coinsAfterFirst, greaterThan(0));
      expect(ctrl.clanGoalClaimed, isTrue);

      expect(ctrl.claimClanGoalReward(), isFalse);
      expect(ctrl.coins.value, coinsAfterFirst);
    });

    test('sang tuần mới → đóng góp tuần reset về 0, lifetime giữ nguyên, '
        'cho claim lại', () {
      final lastWeek = ctrl.currentWeekIndex - 1;
      StorageService.to.setInt(StorageKeys.clanGoalWeek, lastWeek);
      StorageService.to.setInt(StorageKeys.clanContribWeek, 500);
      StorageService.to.setInt(StorageKeys.clanContribTotal, 500);
      StorageService.to.setInt(StorageKeys.clanGoalClaimedWeek, lastWeek);

      final next = relaunch();
      expect(next.clanContribWeek.value, 0);
      expect(next.clanContribTotal.value, 500);
      expect(next.clanGoalClaimed, isFalse);

      final botsSum = clanPoolTotal(next.currentWeekIndex, 0);
      final needed = (clanGoalTarget - botsSum).clamp(0, clanGoalTarget);
      next.addClanContribution(needed);
      expect(next.claimClanGoalReward(), isTrue);
    });

    test(
      'resetProgress() đưa đóng góp/trạng thái nhận thưởng về mặc định',
      () async {
        final botsSum = clanPoolTotal(ctrl.currentWeekIndex, 0);
        final needed = (clanGoalTarget - botsSum).clamp(0, clanGoalTarget);
        ctrl.addClanContribution(needed);
        ctrl.claimClanGoalReward();

        await ctrl.resetProgress();
        expect(ctrl.clanContribWeek.value, 0);
        expect(ctrl.clanContribTotal.value, 0);
        expect(ctrl.clanGoalClaimed, isFalse);
      },
    );
  });

  group('I52 Pop Burst Style Picker — validation/anti-cheat', () {
    GameController relaunch() {
      Get.delete<GameController>(force: true);
      return Get.put(GameController(), permanent: true);
    }

    test('mặc định spark khi chưa pop gem nào', () {
      expect(ctrl.activeBurstStyleKind.value, BurstStyleKind.spark);
    });

    test(
      'setActiveBurstStyle chặn style chưa đủ totalGemsPopped để mở khoá',
      () {
        ctrl.totalGemsPopped.value = 100; // < 500 (confetti threshold)
        ctrl.setActiveBurstStyle(BurstStyleKind.confetti);

        expect(ctrl.activeBurstStyleKind.value, BurstStyleKind.spark);
        expect(
          StorageService.to.getString(StorageKeys.activeBurstStyle),
          isNull,
        );
      },
    );

    test('setActiveBurstStyle cho đổi style đã đủ totalGemsPopped', () {
      ctrl.totalGemsPopped.value = 500; // đủ ngưỡng confetti
      ctrl.setActiveBurstStyle(BurstStyleKind.confetti);

      expect(ctrl.activeBurstStyleKind.value, BurstStyleKind.confetti);
      expect(
        StorageService.to.getString(StorageKeys.activeBurstStyle),
        'confetti',
      );
    });

    test('setActiveBurstStyle style spark (threshold 0) luôn cho phép', () {
      ctrl.setActiveBurstStyle(BurstStyleKind.spark);
      expect(ctrl.activeBurstStyleKind.value, BurstStyleKind.spark);
    });

    test('_load() khôi phục đúng style đã mở khoá từ storage', () {
      StorageService.to.setInt(StorageKeys.totalGemsPopped, 2000);
      StorageService.to.setString(StorageKeys.activeBurstStyle, 'ripple');

      final next = relaunch();
      expect(next.activeBurstStyleKind.value, BurstStyleKind.ripple);
    });

    test('_load() fallback về spark khi string trong storage không hợp lệ', () {
      StorageService.to.setInt(StorageKeys.totalGemsPopped, 10000);
      StorageService.to.setString(StorageKeys.activeBurstStyle, 'not_a_style');

      final next = relaunch();
      expect(next.activeBurstStyleKind.value, BurstStyleKind.spark);
    });

    test(
      '_load() fallback về spark khi storage bị sửa tay trỏ style chưa đủ ngưỡng',
      () {
        StorageService.to.setInt(StorageKeys.totalGemsPopped, 100);
        StorageService.to.setString(
          StorageKeys.activeBurstStyle,
          'starburst', // threshold 5000, totalGemsPopped chỉ 100
        );

        final next = relaunch();
        expect(next.activeBurstStyleKind.value, BurstStyleKind.spark);
      },
    );

    test('resetProgress() xoá activeBurstStyle khỏi storage', () async {
      ctrl.totalGemsPopped.value = 500;
      ctrl.setActiveBurstStyle(BurstStyleKind.confetti);
      expect(
        StorageService.to.getString(StorageKeys.activeBurstStyle),
        'confetti',
      );

      await ctrl.resetProgress();
      expect(StorageService.to.getString(StorageKeys.activeBurstStyle), isNull);

      final next = relaunch();
      expect(next.activeBurstStyleKind.value, BurstStyleKind.spark);
    });
  });

  group('I54 Combo Text Style — validation/anti-cheat', () {
    GameController relaunch() {
      Get.delete<GameController>(force: true);
      return Get.put(GameController(), permanent: true);
    }

    test('mặc định neon khi chưa đạt combo nào', () {
      expect(ctrl.activeComboTextStyleKind.value, ComboTextStyleKind.neon);
    });

    test(
      'setActiveComboTextStyle chặn style chưa đủ maxComboEver để mở khoá',
      () {
        ctrl.maxComboEver.value = 5; // < 6 (boldPop threshold)
        ctrl.setActiveComboTextStyle(ComboTextStyleKind.boldPop);

        expect(ctrl.activeComboTextStyleKind.value, ComboTextStyleKind.neon);
        expect(
          StorageService.to.getString(StorageKeys.activeComboTextStyle),
          isNull,
        );
      },
    );

    test('setActiveComboTextStyle cho đổi style đã đủ maxComboEver', () {
      ctrl.maxComboEver.value = 6; // đủ ngưỡng boldPop
      ctrl.setActiveComboTextStyle(ComboTextStyleKind.boldPop);

      expect(ctrl.activeComboTextStyleKind.value, ComboTextStyleKind.boldPop);
      expect(
        StorageService.to.getString(StorageKeys.activeComboTextStyle),
        'boldPop',
      );
    });

    test('setActiveComboTextStyle style neon (threshold 0) luôn cho phép', () {
      ctrl.setActiveComboTextStyle(ComboTextStyleKind.neon);
      expect(ctrl.activeComboTextStyleKind.value, ComboTextStyleKind.neon);
    });

    test('_load() khôi phục đúng style đã mở khoá từ storage', () {
      StorageService.to.setInt(StorageKeys.maxComboEver, 15);
      StorageService.to.setString(StorageKeys.activeComboTextStyle, 'retro');

      final next = relaunch();
      expect(next.activeComboTextStyleKind.value, ComboTextStyleKind.retro);
    });

    test('_load() fallback về neon khi string trong storage không hợp lệ', () {
      StorageService.to.setInt(StorageKeys.maxComboEver, 25);
      StorageService.to.setString(
        StorageKeys.activeComboTextStyle,
        'not_a_style',
      );

      final next = relaunch();
      expect(next.activeComboTextStyleKind.value, ComboTextStyleKind.neon);
    });

    test(
      '_load() fallback về neon khi storage bị sửa tay trỏ style chưa đủ ngưỡng',
      () {
        StorageService.to.setInt(StorageKeys.maxComboEver, 5);
        StorageService.to.setString(
          StorageKeys.activeComboTextStyle,
          'fire', // threshold 25, maxComboEver chỉ 5
        );

        final next = relaunch();
        expect(next.activeComboTextStyleKind.value, ComboTextStyleKind.neon);
      },
    );

    test('resetProgress() xoá activeComboTextStyle khỏi storage', () async {
      ctrl.maxComboEver.value = 6;
      ctrl.setActiveComboTextStyle(ComboTextStyleKind.boldPop);
      expect(
        StorageService.to.getString(StorageKeys.activeComboTextStyle),
        'boldPop',
      );

      await ctrl.resetProgress();
      expect(
        StorageService.to.getString(StorageKeys.activeComboTextStyle),
        isNull,
      );

      final next = relaunch();
      expect(next.activeComboTextStyleKind.value, ComboTextStyleKind.neon);
    });
  });

  group('I51 Board Frame Cosmetics — validation/anti-cheat', () {
    GameController relaunch() {
      Get.delete<GameController>(force: true);
      return Get.put(GameController(), permanent: true);
    }

    test('mặc định classic khi chưa prestige/achievement gì', () {
      expect(ctrl.activeBoardFrameId.value, 'classic');
    });

    test('setActiveBoardFrame chặn khung chưa đủ prestigeTier để mở khoá', () {
      ctrl.prestigeTier.value = 0; // neon_cyan cần tier 1
      ctrl.setActiveBoardFrame('neon_cyan');

      expect(ctrl.activeBoardFrameId.value, 'classic');
      expect(StorageService.to.getString(StorageKeys.activeBoardFrame), isNull);
    });

    test('setActiveBoardFrame cho đổi khung đã đủ prestigeTier', () {
      ctrl.prestigeTier.value = 1;
      ctrl.setActiveBoardFrame('neon_cyan');

      expect(ctrl.activeBoardFrameId.value, 'neon_cyan');
      expect(
        StorageService.to.getString(StorageKeys.activeBoardFrame),
        'neon_cyan',
      );
    });

    test('setActiveBoardFrame chặn khung đạt achievement khi chưa unlock', () {
      ctrl.setActiveBoardFrame('diamond');

      expect(ctrl.activeBoardFrameId.value, 'classic');
      expect(StorageService.to.getString(StorageKeys.activeBoardFrame), isNull);
    });

    test(
      'setActiveBoardFrame cho đổi khung diamond khi đã unlock clear_400',
      () {
        ctrl.unlockedAchievementIds.add('clear_400');
        ctrl.setActiveBoardFrame('diamond');

        expect(ctrl.activeBoardFrameId.value, 'diamond');
        expect(
          StorageService.to.getString(StorageKeys.activeBoardFrame),
          'diamond',
        );
      },
    );

    test('setActiveBoardFrame khung classic (always) luôn cho phép', () {
      ctrl.setActiveBoardFrame('classic');
      expect(ctrl.activeBoardFrameId.value, 'classic');
    });

    test('_load() khôi phục đúng khung đã mở khoá từ storage', () {
      StorageService.to.setInt(StorageKeys.prestigeTier, 3);
      StorageService.to.setString(StorageKeys.activeBoardFrame, 'aurora_gold');

      final next = relaunch();
      expect(next.activeBoardFrameId.value, 'aurora_gold');
    });

    test('_load() fallback về classic khi id trong storage không hợp lệ', () {
      StorageService.to.setInt(StorageKeys.prestigeTier, 3);
      StorageService.to.setString(StorageKeys.activeBoardFrame, 'not_a_frame');

      final next = relaunch();
      expect(next.activeBoardFrameId.value, 'classic');
    });

    test('_load() fallback về classic khi storage bị sửa tay trỏ khung chưa đủ '
        'điều kiện', () {
      StorageService.to.setInt(StorageKeys.prestigeTier, 0);
      StorageService.to.setString(
        StorageKeys.activeBoardFrame,
        'aurora_gold', // cần tier 3, hiện tier 0
      );

      final next = relaunch();
      expect(next.activeBoardFrameId.value, 'classic');
    });

    test('resetProgress() xoá activeBoardFrame khỏi storage', () async {
      ctrl.prestigeTier.value = 1;
      ctrl.setActiveBoardFrame('neon_cyan');
      expect(
        StorageService.to.getString(StorageKeys.activeBoardFrame),
        'neon_cyan',
      );

      await ctrl.resetProgress();
      expect(StorageService.to.getString(StorageKeys.activeBoardFrame), isNull);

      final next = relaunch();
      expect(next.activeBoardFrameId.value, 'classic');
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

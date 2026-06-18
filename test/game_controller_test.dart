import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/logic/gem_data.dart';
import 'package:neon_jewels/core/storage_service.dart';
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

  group('startLevel', () {
    test('khởi tạo đúng cấu hình level', () {
      c.startLevel(1);
      final lv = kLevels[0];
      expect(c.score.value, 0);
      expect(c.movesLeft.value, lv.moves);
      expect(c.targetScore.value, lv.targetScore);
      expect(c.currentLevel.value, 1);
    });
  });

  group('addScore', () {
    test('combo 1 = gems * 10', () {
      c.startLevel(1);
      c.addScore(10, 1);
      expect(c.score.value, 100);
    });

    test('combo 3 nhân hệ số 2.0', () {
      c.startLevel(1);
      c.addScore(10, 3); // 10*10*(1+2*0.5)=200
      expect(c.score.value, 200);
      expect(c.comboCount.value, 3);
    });

    test('điểm cộng dồn qua nhiều lần', () {
      c.startLevel(1);
      c.addScore(3, 1); // 30
      c.addScore(3, 1); // 30
      expect(c.score.value, 60);
    });
  });

  group('useMove', () {
    test('giảm lượt và không xuống dưới 0', () {
      c.startLevel(1);
      final start = c.movesLeft.value;
      c.useMove();
      expect(c.movesLeft.value, start - 1);
      for (int i = 0; i < 100; i++) {
        c.useMove();
      }
      expect(c.movesLeft.value, 0);
    });
  });

  group('checkEnd', () {
    test('thắng khi đạt điểm mục tiêu', () {
      c.startLevel(1);
      c.addScore(1000, 1); // 10000 > target 1500
      expect(c.hasWon, isTrue);
      expect(c.checkEnd(), 'win');
    });

    test('thắng mở khóa level kế tiếp', () async {
      c.startLevel(1);
      c.addScore(1000, 1);
      c.checkEnd();
      await Future.delayed(const Duration(milliseconds: 20));
      expect(c.unlockedLevel.value, 2);
    });

    test('thua khi hết lượt mà chưa đạt điểm', () {
      c.startLevel(1);
      for (int i = 0; i < 100; i++) {
        c.useMove();
      }
      expect(c.isOutOfMoves, isTrue);
      expect(c.checkEnd(), 'lose');
    });

    test('checkEnd chỉ trả kết quả 1 lần / ván', () {
      c.startLevel(1);
      c.addScore(1000, 1);
      expect(c.checkEnd(), 'win');
      expect(c.checkEnd(), isNull); // lần 2 trả null
    });

    test('đang chơi (chưa thắng/thua) trả null', () {
      c.startLevel(1);
      c.addScore(3, 1);
      expect(c.checkEnd(), isNull);
    });

    test('thắng màn thường: lastCoinReward tính ĐỦ bonus (1+sao)×10 ĐỒNG BỘ '
        '(không chờ _saveProgress) — chống race quest earnCoins đếm thiếu', () {
      c.startLevel(1);
      c.addScore(1000, 1);
      expect(c.checkEnd(), 'win');
      // Ngay sau checkEnd (đồng bộ), lastCoinReward phải đã gồm phần (1+sao)×10
      // (trước đây phần này cộng trong _saveProgress sau 1 await → đọc sớm thiếu).
      final expected =
          10 + c.lastStars * 10 + c.lastStreakBonus + (1 + c.lastStars) * 10;
      expect(c.lastCoinReward, expected);
    });
  });

  group('high score', () {
    test('lưu điểm cao mới', () async {
      c.startLevel(1);
      c.addScore(1000, 1);
      c.checkEnd();
      await Future.delayed(const Duration(milliseconds: 20));
      expect(c.highScores[1], c.score.value);
    });
  });

  group('objective: collect', () {
    int collectLevel() =>
        kLevels.indexWhere((l) => l.objective == ObjectiveType.collect) + 1;

    test('registerClear tăng collected khi đúng màu', () {
      final idx = collectLevel();
      c.startLevel(idx);
      final color = c.level.collectColor!;
      c.registerClear(color, false);
      c.registerClear(color, false);
      expect(c.collected.value, 2);
    });

    test('màu khác không tính', () {
      final idx = collectLevel();
      c.startLevel(idx);
      final wrong = GemColor.values.firstWhere((g) => g != c.level.collectColor);
      c.registerClear(wrong, false);
      expect(c.collected.value, 0);
    });

    test('thắng khi thu đủ', () {
      final idx = collectLevel();
      c.startLevel(idx);
      for (int i = 0; i < c.level.collectTarget; i++) {
        c.registerClear(c.level.collectColor!, false);
      }
      expect(c.hasWon, isTrue);
    });
  });

  group('objective: clearJelly', () {
    int jellyLevel() =>
        kLevels.indexWhere((l) => l.objective == ObjectiveType.clearJelly) + 1;

    test('phá đủ jelly thì thắng', () {
      c.startLevel(jellyLevel());
      c.jellyTotal.value = 5; // game thường set; mô phỏng ở test
      for (int i = 0; i < 5; i++) {
        c.registerClear(GemColor.cyan, true);
      }
      expect(c.jellyCleared.value, 5);
      expect(c.hasWon, isTrue);
    });

    test('chưa đủ jelly thì chưa thắng', () {
      c.startLevel(jellyLevel());
      c.jellyTotal.value = 5;
      c.registerClear(GemColor.cyan, true);
      expect(c.hasWon, isFalse);
    });
  });

  group('objectiveProgress', () {
    test('score: tỉ lệ theo điểm', () {
      c.startLevel(1);
      c.score.value = (c.targetScore.value / 2).round();
      expect(c.objectiveProgress, closeTo(0.5, 0.05));
    });
  });

  group('sao & xu', () {
    test('điểm vượt xa → 3 sao', () {
      c.startLevel(1);
      c.score.value = c.targetScore.value * 2;
      expect(c.computeStars(), 3);
    });

    test('vừa đủ điểm → 1 sao', () {
      c.startLevel(1);
      c.score.value = c.targetScore.value;
      expect(c.computeStars(), 1);
    });

    test('thắng thưởng xu + lưu sao tốt nhất', () async {
      final coin0 = c.coins.value;
      c.startLevel(1);
      c.score.value = c.targetScore.value * 2; // 3 sao
      c.checkEnd();
      await Future.delayed(const Duration(milliseconds: 20));
      expect(c.lastStars, 3);
      expect(c.stars[1], 3);
      expect(c.coins.value, greaterThan(coin0));
    });
  });

  group('booster', () {
    test('useHammer giảm số lượng', () {
      c.boosterHammer.value = 2;
      expect(c.useHammer(), isTrue);
      expect(c.boosterHammer.value, 1);
    });

    test('hết búa thì useHammer trả false', () {
      c.boosterHammer.value = 0;
      expect(c.useHammer(), isFalse);
    });

    test('mua búa: trừ xu + tăng số lượng', () {
      c.coins.value = 100;
      final h0 = c.boosterHammer.value;
      expect(c.buyHammer(price: 30), isTrue);
      expect(c.coins.value, 70);
      expect(c.boosterHammer.value, h0 + 1);
    });

    test('thiếu xu không mua được', () {
      c.coins.value = 10;
      expect(c.buyHammer(price: 30), isFalse);
      expect(c.coins.value, 10);
    });

    test('+10 lượt: dùng booster cộng 10 lượt', () {
      c.startLevel(1);
      final m0 = c.movesLeft.value;
      c.boosterMoves.value = 1;
      expect(c.useMovesBooster(), isTrue);
      expect(c.movesLeft.value, m0 + 10);
      expect(c.boosterMoves.value, 0);
    });

    test('hết +10 thì useMovesBooster trả false', () {
      c.boosterMoves.value = 0;
      expect(c.useMovesBooster(), isFalse);
    });

    test('swap/bomb/color: dùng giảm số lượng', () {
      c.boosterSwap.value = 1;
      c.boosterBomb.value = 1;
      c.boosterColor.value = 1;
      expect(c.useSwap(), isTrue);
      expect(c.useBomb(), isTrue);
      expect(c.useColor(), isTrue);
      expect(c.boosterSwap.value, 0);
      expect(c.boosterBomb.value, 0);
      expect(c.boosterColor.value, 0);
      expect(c.useSwap(), isFalse);
    });

    test('mua swap/bomb/color trừ xu', () {
      c.coins.value = 200;
      expect(c.buySwap(price: 40), isTrue);
      expect(c.buyBomb(price: 50), isTrue);
      expect(c.buyColor(price: 80), isTrue);
      expect(c.coins.value, 200 - 40 - 50 - 80);
    });

    test('booster độc quyền: dùng giảm số lượng', () {
      c.boosterJoker.value = 1;
      c.boosterLightning.value = 1;
      c.boosterRoyal.value = 1;
      c.boosterGravity.value = 1;
      expect(c.useJoker(), isTrue);
      expect(c.useLightning(), isTrue);
      expect(c.useRoyal(), isTrue);
      expect(c.useGravity(), isTrue);
      expect(c.useJoker(), isFalse);
      expect(c.useRoyal(), isFalse);
    });

    test('mua booster độc quyền trừ xu', () {
      c.coins.value = 500;
      expect(c.buyJoker(price: 60), isTrue);
      expect(c.buyLightning(price: 60), isTrue);
      expect(c.buyRoyal(price: 120), isTrue);
      expect(c.buyGravity(price: 50), isTrue);
      expect(c.coins.value, 500 - 60 - 60 - 120 - 50);
    });
  });
}

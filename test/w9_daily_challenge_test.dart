import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thử thách hằng ngày (Wave 9): puzzle seed theo NGÀY, thưởng 1 lần/ngày,
/// streak chống farm chỉnh giờ. Test logic thuần + GameController.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Ép thắng bất kể mục tiêu nào của màn daily (mục tiêu xoay theo ngày).
  void forceWin(GameController c) {
    final lv = c.level;
    switch (lv.objective) {
      case ObjectiveType.score:
      case ObjectiveType.timeAttack:
        c.score.value = lv.targetScore;
        break;
      case ObjectiveType.collect:
        c.collected.value = lv.collectTarget;
        break;
      case ObjectiveType.clearJelly:
        c.jellyTotal.value = 4;
        c.jellyCleared.value = 4;
        break;
      case ObjectiveType.dropDown:
        c.dropped.value = lv.dropTarget;
        break;
      case ObjectiveType.clearObstacle:
        c.obstacleTotal.value = 4;
        c.obstacleCleared.value = 4;
        break;
      case ObjectiveType.order:
      case ObjectiveType.endless:
      case ObjectiveType.boss:
      case ObjectiveType.soda:
        break;
    }
  }

  group('buildDailyLevel — tất định theo ngày', () {
    test('cùng epochDay → cấu hình Y HỆT', () {
      final a = buildDailyLevel(20250);
      final b = buildDailyLevel(20250);
      expect(a.objective, b.objective);
      expect(a.moves, b.moves);
      expect(a.targetScore, b.targetScore);
      expect(a.collectTarget, b.collectTarget);
      expect(a.collectColor, b.collectColor);
      expect(a.dropTarget, b.dropTarget);
      expect(a.jelly, b.jelly);
      expect(a.obstacle, b.obstacle);
    });

    test('mục tiêu xoay theo ngày (epochDay % số mục tiêu)', () {
      for (var d = 0; d < kDailyObjectives.length * 3; d++) {
        expect(
          buildDailyLevel(d).objective,
          kDailyObjectives[d % kDailyObjectives.length],
        );
      }
    });

    test('luôn là bàn 8×8, 6 màu, index daily', () {
      for (final d in [0, 1, 2, 3, 4, 99, 12345]) {
        final lv = buildDailyLevel(d);
        expect(lv.rows, 8);
        expect(lv.cols, 8);
        expect(lv.colorCount, 6);
        expect(lv.index, kDailyLevelIndex);
        expect(lv.moves, greaterThan(0));
      }
    });

    test('chế độ clearObstacle chỉ dùng ICE (không khoá swap)', () {
      // tìm 1 ngày có mục tiêu clearObstacle
      final day = kDailyObjectives.indexOf(ObjectiveType.clearObstacle);
      final lv = buildDailyLevel(day);
      expect(lv.objective, ObjectiveType.clearObstacle);
      expect(lv.obstacle, ObstacleType.ice);
    });
  });

  group('GameController — daily mode', () {
    late GameController c;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs));
      c = Get.put(GameController());
    });
    tearDown(Get.reset);

    test('startDaily bật cờ + seed bàn = epoch-day', () {
      c.clock = () => DateTime(2026, 6, 16);
      c.startDaily();
      expect(c.isDaily.value, isTrue);
      expect(c.isEndless.value, isFalse);
      expect(c.isBoss.value, isFalse);
      expect(c.boardSeed, c.todayEpochDay);
      expect(c.level.index, kDailyLevelIndex);
    });

    test('thắng lần đầu/ngày → thưởng xu, streak=1, done', () {
      c.clock = () => DateTime(2026, 6, 16);
      final coins0 = c.coins.value;
      c.startDaily();
      forceWin(c);
      expect(c.checkEnd(), 'win');
      expect(c.lastCoinReward, greaterThan(0));
      expect(c.dailyChStreak.value, 1);
      expect(c.dailyChallengeDoneToday, isTrue);
      expect(c.coins.value, greaterThan(coins0));
    });

    test('chơi lại CÙNG ngày → KHÔNG thưởng lần 2', () {
      c.clock = () => DateTime(2026, 6, 16);
      c.startDaily();
      forceWin(c);
      c.checkEnd(); // lần 1: thưởng
      final coinsAfter1 = c.coins.value;
      // chơi lại trong ngày
      c.startDaily();
      forceWin(c);
      expect(c.checkEnd(), 'win');
      expect(c.lastCoinReward, 0);
      expect(c.coins.value, coinsAfter1); // không tăng thêm
      expect(c.dailyChStreak.value, 1); // streak không nhảy khi chơi lại
    });

    test('ngày liên tiếp → streak +1; cách quãng → reset về 1', () {
      // ngày 1
      c.clock = () => DateTime(2026, 6, 16);
      c.startDaily();
      forceWin(c);
      c.checkEnd();
      expect(c.dailyChStreak.value, 1);
      // ngày 2 (liền) → 2
      c.clock = () => DateTime(2026, 6, 17);
      c.startDaily();
      forceWin(c);
      c.checkEnd();
      expect(c.dailyChStreak.value, 2);
      expect(c.dailyChBestStreak.value, 2);
      // nhảy sang ngày 6 (cách quãng) → reset 1
      c.clock = () => DateTime(2026, 6, 21);
      c.startDaily();
      forceWin(c);
      c.checkEnd();
      expect(c.dailyChStreak.value, 1);
      expect(c.dailyChBestStreak.value, 2); // best giữ nguyên
    });

    test('chỉnh giờ LÙI không nhận lại thưởng (anti-cheat)', () {
      c.clock = () => DateTime(2026, 6, 17);
      c.startDaily();
      forceWin(c);
      c.checkEnd();
      final coinsAfter = c.coins.value;
      // lùi giờ về hôm trước
      c.clock = () => DateTime(2026, 6, 16);
      c.startDaily();
      forceWin(c);
      expect(c.checkEnd(), 'win');
      expect(c.lastCoinReward, 0); // effectiveDay giữ maxDay → đã done
      expect(c.coins.value, coinsAfter);
    });

    test('thua khi hết lượt → lose, không thưởng', () {
      c.clock = () => DateTime(2026, 6, 16);
      c.startDaily();
      c.movesLeft.value = 0;
      expect(c.checkEnd(), 'lose');
      expect(c.lastCoinReward, 0);
      expect(c.dailyChallengeDoneToday, isFalse);
    });

    // Audit gap W22.4A: dailyPlayerScore() (đọc) đã có test riêng
    // (w21_6_leaderboard_screen_test.dart) nhưng chỉ seed storage TAY —
    // KHÔNG đi qua đường ghi thật trong checkEnd(). Test dưới ép thắng nhiều
    // lần thật (forceWin + checkEnd) để khoá tính đơn điệu + rollover ngày.
    group('dailyBestScore — tính đơn điệu qua đường ghi thật (checkEnd)', () {
      String? readBest() =>
          StorageService.to.getString(StorageKeys.dailyBestScore);

      test('điểm cao hơn cùng ngày → ghi đè; điểm thấp hơn → giữ nguyên', () {
        c.clock = () => DateTime(2026, 6, 16);
        final today = c.todayEpochDay;

        c.startDaily();
        forceWin(c);
        c.score.value = 300;
        c.checkEnd();
        expect(readBest(), '$today|300');

        // chơi lại cùng ngày, điểm THẤP hơn → không ghi đè
        c.startDaily();
        forceWin(c);
        c.score.value = 150;
        c.checkEnd();
        expect(readBest(), '$today|300');

        // chơi lại cùng ngày, điểm CAO hơn → ghi đè
        c.startDaily();
        forceWin(c);
        c.score.value = 500;
        c.checkEnd();
        expect(readBest(), '$today|500');
      });

      test('sang ngày mới → reset best (điểm ngày cũ không mang qua)', () {
        c.clock = () => DateTime(2026, 6, 16);
        final day1 = c.todayEpochDay;
        c.startDaily();
        forceWin(c);
        c.score.value = 999;
        c.checkEnd();
        expect(readBest(), '$day1|999');

        // ngày mới, điểm THẤP hơn điểm ngày cũ vẫn được ghi (best ngày mới = 0)
        // Dùng 6/18 (mục tiêu collect, không phải score) để gán score.value
        // tuỳ ý sau forceWin mà không vô tình làm hasWon=false.
        c.clock = () => DateTime(2026, 6, 18);
        final day2 = c.todayEpochDay;
        c.startDaily();
        forceWin(c);
        c.score.value = 10;
        c.checkEnd();
        expect(readBest(), '$day2|10');
      });

      test('thua (chưa đạt mục tiêu) → KHÔNG ghi dailyBestScore', () {
        c.clock = () => DateTime(2026, 6, 16);
        c.startDaily();
        c.movesLeft.value = 0;
        c.score.value = 999;
        expect(c.checkEnd(), 'lose');
        expect(readBest(), isNull);
      });
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/data/levels.dart';
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

  int levelOf(ObjectiveType o) =>
      kLevels.indexWhere((l) => l.objective == o) + 1;

  group('Time Attack', () {
    test('startLevel nạp timeLeft từ timeLimit', () {
      final idx = levelOf(ObjectiveType.timeAttack);
      c.startLevel(idx);
      expect(c.timeLeft.value, kLevels[idx - 1].timeLimit);
      expect(c.timeLeft.value, greaterThan(0));
    });

    test('tickTime giảm không âm', () {
      final idx = levelOf(ObjectiveType.timeAttack);
      c.startLevel(idx);
      final t0 = c.timeLeft.value;
      c.tickTime(5);
      expect(c.timeLeft.value, t0 - 5);
      c.tickTime(10000);
      expect(c.timeLeft.value, 0);
    });

    test('không tính hết lượt; thắng khi đạt điểm', () {
      final idx = levelOf(ObjectiveType.timeAttack);
      c.startLevel(idx);
      c.movesLeft.value = 0;
      expect(c.isOutOfMoves, isFalse); // time attack bỏ qua lượt
      c.score.value = c.targetScore.value;
      expect(c.hasWon, isTrue);
    });

    test('hết giờ chưa đủ điểm → lose', () {
      final idx = levelOf(ObjectiveType.timeAttack);
      c.startLevel(idx);
      c.tickTime(c.timeLeft.value); // về 0
      expect(c.isOutOfTime, isTrue);
      expect(c.checkEnd(), 'lose');
    });

    test('đủ điểm trước khi hết giờ → win', () {
      final idx = levelOf(ObjectiveType.timeAttack);
      c.startLevel(idx);
      c.score.value = c.targetScore.value;
      expect(c.checkEnd(), 'win');
    });

    test('addTime cộng giây (chỉ time attack)', () {
      final idx = levelOf(ObjectiveType.timeAttack);
      c.startLevel(idx);
      final t0 = c.timeLeft.value;
      c.addTime(3);
      expect(c.timeLeft.value, t0 + 3);
    });

    test('addTime bị bỏ qua ở mode khác', () {
      c.startLevel(1); // score mode
      c.timeLeft.value = 0;
      c.addTime(5);
      expect(c.timeLeft.value, 0);
    });
  });

  group('Drop Down', () {
    test('registerDrop tăng, thắng khi đủ', () {
      final idx = levelOf(ObjectiveType.dropDown);
      c.startLevel(idx);
      final target = c.level.dropTarget;
      expect(target, greaterThan(0));
      for (int i = 0; i < target; i++) {
        expect(c.hasWon, isFalse);
        c.registerDrop();
      }
      expect(c.dropped.value, target);
      expect(c.hasWon, isTrue);
    });

    test('progress theo tỉ lệ dropped/target', () {
      final idx = levelOf(ObjectiveType.dropDown);
      c.startLevel(idx);
      c.dropped.value = c.level.dropTarget;
      expect(c.objectiveProgress, 1.0);
    });
  });

  group('Obstacle (clearObstacle)', () {
    test('thắng khi dọn đủ obstacle', () {
      final idx = levelOf(ObjectiveType.clearObstacle);
      c.startLevel(idx);
      c.obstacleTotal.value = 4; // game thường set; mô phỏng
      expect(c.hasWon, isFalse);
      c.registerObstacleClear(2);
      c.registerObstacleClear(2);
      expect(c.obstacleCleared.value, 4);
      expect(c.hasWon, isTrue);
    });

    test('obstacleTotal=0 thì chưa thắng', () {
      final idx = levelOf(ObjectiveType.clearObstacle);
      c.startLevel(idx);
      c.obstacleTotal.value = 0;
      expect(c.hasWon, isFalse);
    });
  });

  group('Daily reward', () {
    test('phần thưởng chu kỳ 7 ngày tăng dần', () {
      expect(c.dailyRewardFor(1), 20);
      expect(c.dailyRewardFor(7), 110);
      expect(c.dailyRewardFor(8), 20); // lặp lại
    });

    test('nhận quà cộng xu + tăng streak; không nhận 2 lần/ngày', () {
      final base = DateTime(2026, 6, 13, 10);
      c.clock = () => base;
      final coin0 = c.coins.value;
      expect(c.canClaimDaily, isTrue);
      final got = c.claimDaily();
      expect(got, 20);
      expect(c.dailyStreak.value, 1);
      expect(c.coins.value, coin0 + 20);
      expect(c.canClaimDaily, isFalse);
      expect(c.claimDaily(), 0); // cùng ngày → 0
    });

    test('ngày liên tiếp tăng streak; gãy thì reset', () {
      var day = DateTime(2026, 6, 13, 10);
      c.clock = () => day;
      c.claimDaily(); // ngày 1
      day = DateTime(2026, 6, 14, 10);
      expect(c.claimDaily(), 35); // streak 2
      expect(c.dailyStreak.value, 2);
      // bỏ 1 ngày (gãy) → reset về 1
      day = DateTime(2026, 6, 16, 10);
      expect(c.claimDaily(), 20);
      expect(c.dailyStreak.value, 1);
    });
  });

  group('Lives', () {
    test('mặc định đầy mạng', () {
      expect(c.lives.value, GameController.maxLives);
      expect(c.hasLife, isTrue);
    });

    test('consumeLife trừ 1, không âm', () {
      final t0 = DateTime(2026, 6, 13, 10);
      c.clock = () => t0;
      expect(c.consumeLife(), isTrue);
      expect(c.lives.value, GameController.maxLives - 1);
      // có mốc hồi sau khi rời max
      expect(c.timeToNextLife.inSeconds, greaterThan(0));
    });

    test('refill hồi mạng theo thời gian trôi qua', () {
      var t = DateTime(2026, 6, 13, 10);
      c.clock = () => t;
      c.consumeLife(); // 5 → 4, mốc = t + 15'
      expect(c.lives.value, GameController.maxLives - 1);
      // tới mốc hồi
      t = t.add(const Duration(minutes: 15));
      c.refillLives();
      expect(c.lives.value, GameController.maxLives);
      expect(c.timeToNextLife, Duration.zero);
    });

    test('hồi nhiều mạng nếu trôi qua nhiều chu kỳ', () {
      var t = DateTime(2026, 6, 13, 10);
      c.clock = () => t;
      c.consumeLife();
      c.consumeLife();
      c.consumeLife(); // 5 → 2
      expect(c.lives.value, 2);
      t = t.add(const Duration(minutes: 31)); // 2 chu kỳ + dư
      c.refillLives();
      expect(c.lives.value, 4);
    });

    test('hết mạng thì consumeLife trả false', () {
      c.lives.value = 0;
      expect(c.consumeLife(), isFalse);
      expect(c.hasLife, isFalse);
    });

    test('mua đầy mạng: trừ xu + đầy mạng', () {
      final t0 = DateTime(2026, 6, 13, 10);
      c.clock = () => t0;
      c.consumeLife();
      c.consumeLife(); // 5 → 3
      c.coins.value = 100;
      expect(c.buyRefillLives(price: 60), isTrue);
      expect(c.lives.value, GameController.maxLives);
      expect(c.coins.value, 40);
      expect(c.timeToNextLife, Duration.zero);
    });

    test('mua mạng: thiếu xu → false', () {
      c.lives.value = 2;
      c.coins.value = 10;
      expect(c.buyRefillLives(price: 60), isFalse);
      expect(c.lives.value, 2);
    });

    test('mua mạng: đã đầy → false', () {
      c.coins.value = 100;
      expect(c.buyRefillLives(price: 60), isFalse);
      expect(c.coins.value, 100);
    });
  });
}

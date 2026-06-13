import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    c = Get.put(GameController());
    // chờ _load() nạp prefs xong
    await Future.delayed(const Duration(milliseconds: 30));
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
}

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
}

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/presentation/controllers/versus_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
  });
  tearDown(Get.reset);

  VersusController put(VersusMode m) =>
      Get.put(VersusController(m), tag: 'tv');

  group('VersusController (engine Flame)', () {
    test('onInit tạo 2 controller versus + 2 game riêng', () {
      final c = put(VersusMode.versus);
      expect(c.g1.isVersus.value, isTrue);
      expect(c.g2.isVersus.value, isTrue);
      expect(c.g1.level.index, lessThan(0)); // _versusCfg (index âm)
      expect(c.score1, 0);
      expect(c.score2, 0);
    });

    test('bàn versus: addScore tăng điểm nhưng KHÔNG đụng xu/bestCombo/checkEnd',
        () {
      final c = put(VersusMode.versus);
      c.g1.addScore(5, 3);
      expect(c.score1, greaterThan(0));
      expect(c.g1.bestCombo.value, 0); // không cập nhật stat lifetime
      c.g1.addCoins(50);
      expect(c.g1.coins.value, 0); // addCoins no-op trong versus
      expect(c.g1.checkEnd(), isNull); // không tự kết thúc
      c.g1.useMove();
      expect(c.g1.movesLeft.value, greaterThan(1000)); // lượt vô hạn, không giảm
    });

    test('finish versus chọn người điểm cao', () {
      final c = put(VersusMode.versus);
      c.running.value = true;
      c.g1.score.value = 120;
      c.g2.score.value = 80;
      c.finish();
      expect(c.outcome.value, VersusOutcome.p1);
      expect(c.finished.value, isTrue);
    });

    test('finish hoà khi bằng điểm', () {
      final c = put(VersusMode.versus);
      c.running.value = true;
      c.g1.score.value = 50;
      c.g2.score.value = 50;
      c.finish();
      expect(c.outcome.value, VersusOutcome.draw);
    });

    test('coop đạt mục tiêu chung (qua tickSecond) → coopWin', () {
      final c = put(VersusMode.coop);
      c.running.value = true;
      c.g1.score.value = VersusController.coopGoal - 10;
      c.g2.score.value = 20;
      c.tickSecond();
      expect(c.outcome.value, VersusOutcome.coopWin);
      expect(c.finished.value, isTrue);
    });

    test('coop thiếu điểm khi hết giờ → coopLose', () {
      final c = put(VersusMode.coop);
      c.running.value = true;
      c.g1.score.value = 100;
      c.timeLeft.value = 1;
      c.tickSecond(); // → 0 → finish
      expect(c.outcome.value, VersusOutcome.coopLose);
    });

    test('tickSecond đếm ngược, hết giờ → finish', () {
      final c = put(VersusMode.versus);
      c.running.value = true;
      c.timeLeft.value = 2;
      c.tickSecond();
      expect(c.timeLeft.value, 1);
      c.tickSecond();
      expect(c.timeLeft.value, 0);
      expect(c.finished.value, isTrue);
    });

    test('2 bàn điểm độc lập', () {
      final c = put(VersusMode.versus);
      c.g1.addScore(5, 2);
      expect(c.score1, greaterThan(0));
      expect(c.score2, 0); // bàn 2 không bị ảnh hưởng
    });
  });
}

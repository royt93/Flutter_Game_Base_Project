import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
// GameController tách thành part/extension (Wave 10): test truy cập addScore/
// addCoins/checkEnd/useMove qua extension → cần import trực tiếp library này.
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
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

    test('combo lớn gửi rác sang đối thủ (versus)', () {
      final c = put(VersusMode.versus);
      c.running.value = true;
      c.game1.onMoveResolved?.call(4); // P1 combo 4 → gửi (4-3+1)=2 rác sang P2
      expect(c.game2.pendingJunk, 2);
      expect(c.game1.pendingJunk, 0);
      c.game2.onMoveResolved?.call(3); // P2 combo 3 → 1 rác sang P1
      expect(c.game1.pendingJunk, 1);
    });

    test('combo nhỏ (< ngưỡng) KHÔNG gửi rác', () {
      final c = put(VersusMode.versus);
      c.running.value = true;
      c.game1.onMoveResolved?.call(2);
      expect(c.game2.pendingJunk, 0);
    });

    test('co-op KHÔNG tấn công nhau (không gửi rác)', () {
      final c = put(VersusMode.coop);
      c.running.value = true;
      c.game1.onMoveResolved?.call(5);
      expect(c.game2.pendingJunk, 0);
    });

    test('rác chỉ gửi khi đang chạy', () {
      final c = put(VersusMode.versus);
      c.running.value = false;
      c.game1.onMoveResolved?.call(5);
      expect(c.game2.pendingJunk, 0);
    });

    test('2 bàn điểm độc lập', () {
      final c = put(VersusMode.versus);
      c.g1.addScore(5, 2);
      expect(c.score1, greaterThan(0));
      expect(c.score2, 0); // bàn 2 không bị ảnh hưởng
    });

    test('2 bàn versus DÙNG CHUNG seed → mirror mở bàn (công bằng)', () {
      final c = put(VersusMode.versus);
      expect(c.game1.boardSeed, isNotNull);
      expect(c.game2.boardSeed, isNotNull);
      // cùng seed → Random(seed) sinh dãy y hệt → fill bàn giống hệt lúc mở
      expect(c.game1.boardSeed, c.game2.boardSeed);
    });

    test('Random(seed) tất định: cùng seed → cùng dãy màu (cơ sở mirror)', () {
      final a = List.generate(50, (_) => 0);
      final r1 = _seqFromSeed(12345, 50);
      final r2 = _seqFromSeed(12345, 50);
      final r3 = _seqFromSeed(999, 50);
      expect(r1, r2); // cùng seed → y hệt
      expect(r1, isNot(equals(r3))); // khác seed → khác
      expect(r1.length, a.length);
    });
  });
}

/// Mô phỏng cách engine bốc màu: Random(seed).nextInt(6) — chứng minh tính
/// tất định làm cơ sở cho "mirror mở bàn" của Versus.
List<int> _seqFromSeed(int seed, int n) {
  final rnd = Random(seed);
  return List.generate(n, (_) => rnd.nextInt(6));
}

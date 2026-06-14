import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
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

  test('startGravity đặt mode + mục tiêu điểm', () {
    c.startGravity();
    expect(c.isGravity.value, isTrue);
    expect(c.isBoss.value, isFalse);
    expect(c.isEndless.value, isFalse);
    expect(c.level.objective, ObjectiveType.score);
    expect(c.movesLeft.value, kGravityMoves);
    expect(c.targetScore.value, kGravityTarget);
    expect(c.gravityDir.value, 0);
  });

  test('consumeGravityFlip lật mỗi N lượt + đổi hướng', () {
    c.startGravity();
    for (int i = 1; i < kGravityFlipEvery; i++) {
      expect(c.consumeGravityFlip(), isFalse, reason: 'lượt $i chưa lật');
    }
    expect(c.consumeGravityFlip(), isTrue); // lượt thứ N → lật
    expect(c.gravityDir.value, 1); // đổi sang lên
    // chu kỳ kế
    for (int i = 1; i < kGravityFlipEvery; i++) {
      expect(c.consumeGravityFlip(), isFalse);
    }
    expect(c.consumeGravityFlip(), isTrue);
    expect(c.gravityDir.value, 0); // lật về xuống
  });

  test('không ở gravity mode → consumeGravityFlip luôn false', () {
    c.startLevel(1);
    expect(c.consumeGravityFlip(), isFalse);
    expect(c.consumeGravityFlip(), isFalse);
  });

  test('thắng theo điểm như mode score', () {
    c.startGravity();
    c.score.value = kGravityTarget;
    expect(c.hasWon, isTrue);
  });

  test('chuyển mode reset cờ gravity', () {
    c.startGravity();
    expect(c.isGravity.value, isTrue);
    c.startBoss(1);
    expect(c.isGravity.value, isFalse);
    c.startGravity();
    c.startEndless();
    expect(c.isGravity.value, isFalse);
  });
}

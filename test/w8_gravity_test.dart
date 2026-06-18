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

  // --- Cô lập side-mode (regression): trước đây checkEnd thiếu nhánh gravity →
  //     gravity rơi vào nhánh màn thường (winStreak++, unlock, _saveProgress). ---
  test('thắng Gravity là CHẾ ĐỘ PHỤ: checkEnd "win", KHÔNG đụng win-streak/'
      'totalWins, vẫn thưởng xu', () {
    c.startGravity();
    final streakBefore = c.winStreak.value;
    final winsBefore = c.totalWins.value;
    c.score.value = kGravityTarget; // đạt mục tiêu điểm
    expect(c.checkEnd(), 'win');
    expect(c.winStreak.value, streakBefore); // không tăng chuỗi thắng màn thường
    expect(c.totalWins.value, winsBefore); // không tính tổng thắng
    // Wave 12: thưởng side-mode = 30+sao*15 (trận đầu/ngày → full, chưa giảm).
    expect(c.lastCoinReward, 30 + c.lastStars * 15);
  });

  test('thua Gravity → "lose", KHÔNG reset win-streak màn thường', () {
    c.startGravity();
    c.winStreak.value = 3; // chuỗi thắng tích luỹ trước đó
    c.movesLeft.value = 0;
    expect(c.checkEnd(), 'lose');
    expect(c.winStreak.value, 3); // side mode không đụng tiến trình
  });

  test('Wave 12 — chống farm: thưởng side-mode giảm dần sau N trận/ngày', () {
    // [kSideModeFullPlays] trận đầu trong ngày → full; sau đó × reduced.
    for (int i = 0; i < GameController.kSideModeFullPlays; i++) {
      expect(c.discountSideModeReward(100), 100, reason: 'trận ${i + 1} full');
    }
    final reduced = (100 * GameController.kSideModeReducedMul).round();
    expect(c.discountSideModeReward(100), reduced); // trận thứ N+1 → giảm
    expect(c.discountSideModeReward(100), reduced); // tiếp tục giảm
  });

  test('isSideMode đúng cho mọi chế độ phụ, false ở màn thường', () {
    c.startLevel(1);
    expect(c.isSideMode, isFalse);
    c.startGravity();
    expect(c.isSideMode, isTrue);
    c.startBoss(1);
    expect(c.isSideMode, isTrue);
    c.startEndless();
    expect(c.isSideMode, isTrue);
    c.startRhythm();
    expect(c.isSideMode, isTrue);
    c.startDaily();
    expect(c.isSideMode, isTrue);
    c.startLevel(2);
    expect(c.isSideMode, isFalse);
  });
}

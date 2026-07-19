import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/boss_rush_controller.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController gameCtrl;
  late BossRushController brCtrl;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    gameCtrl = Get.put(GameController(), permanent: true);
    brCtrl = Get.put(BossRushController());
  });

  tearDown(Get.reset);

  group('BossRushController — chuỗi bàn', () {
    test('startRun() đặt stage=1, mode=bossRush, reset score/combo', () {
      gameCtrl.addScore(999); // giả lập điểm còn sót từ ván trước
      brCtrl.startRun();
      expect(brCtrl.stage.value, 1);
      expect(gameCtrl.mode.value, GameMode.bossRush);
      expect(gameCtrl.score.value, 0);
      expect(gameCtrl.ended.value, isFalse);
    });

    test(
      'advanceStage() tăng stage và cập nhật currentLevelRx, KHÔNG reset score',
      () {
        brCtrl.startRun();
        gameCtrl.addScore(500);
        final level = brCtrl.advanceStage();
        expect(brCtrl.stage.value, 2);
        expect(gameCtrl.currentLevelRx.value, level);
        expect(gameCtrl.score.value, 500); // giữ nguyên, không reset
      },
    );
  });

  group('BossRushController — kết thúc lượt (best streak/coin)', () {
    test('thua ở stage 3 (đã qua 2 bàn) → best streak = 2, coin = 3*50', () {
      brCtrl.startRun();
      brCtrl.advanceStage(); // stage 2
      brCtrl.advanceStage(); // stage 3
      gameCtrl.checkEnd(false); // kẹt/thua ở stage 3 → mới qua 2 bàn
      expect(brCtrl.bossRushBestStreak.value, 2);
      expect(brCtrl.lastStagesCleared, 2);
      expect(brCtrl.lastCoinReward, 150);
      expect(gameCtrl.coins.value, 150);
      expect(StorageService.to.getInt(StorageKeys.bossRushBestStreak), 2);
    });

    test('lượt sau chuỗi ngắn hơn → không đè best streak cũ (cao hơn)', () {
      brCtrl.startRun();
      brCtrl.advanceStage();
      brCtrl.advanceStage();
      brCtrl.advanceStage();
      gameCtrl.checkEnd(false); // 3 bàn đã qua → best = 3
      expect(brCtrl.bossRushBestStreak.value, 3);

      brCtrl.startRun();
      gameCtrl.checkEnd(false); // thua ngay stage 1 → 0 bàn qua
      expect(brCtrl.bossRushBestStreak.value, 3); // không bị hạ xuống 0
      expect(StorageService.to.getInt(StorageKeys.bossRushBestStreak), 3);
    });

    test(
      'checkEnd của mode khác (endless) không ảnh hưởng Boss Rush state',
      () {
        brCtrl.startRun();
        brCtrl.advanceStage();
        gameCtrl.startEndless();
        gameCtrl.checkEnd(false); // kết thúc ván Endless, không phải Boss Rush
        expect(brCtrl.lastStagesCleared, 0); // _endRun chưa từng chạy
        expect(brCtrl.bossRushBestStreak.value, 0);
      },
    );
  });
}

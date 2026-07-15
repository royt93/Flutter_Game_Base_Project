import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/game_screen_controller.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bơm nhiều frame nhỏ để game loop chạy hết effect + TimerComponent animation.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  testWidgets('F3: rainbow xoá hết ô cùng màu, không cộng điểm, trừ 1 lượt', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    final gameCtrl = Get.put(GameController(), permanent: true);
    gameCtrl.startLevel(1);

    await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await _pumpFrames(tester, frames: 20); // A6: chờ hết intro rơi ô

    final gsc = Get.find<GameScreenController>();
    // Bàn cờ caro 2 màu: mọi cột đều xen kẽ 0/1 → xoá màu 0 không làm cột nào
    // rỗng hoàn toàn, chỉ test đúng logic "xoá mọi ô cùng màu".
    gsc.game.colorGrid = List.generate(
      gsc.game.rows,
      (r) => List.generate(gsc.game.cols, (c) => (r + c) % 2),
    );
    // Đồng bộ _blocks (nguồn thật khi collapse resync colorGrid) với grid mới.
    gsc.game.onGameResize(gsc.game.size);

    gameCtrl.rainbowCount.value = 1;
    gameCtrl.useRainbow(0, 0); // ô (0,0) màu (0+0)%2 = 0
    await _pumpFrames(tester);

    expect(gameCtrl.score.value, 0); // booster không cộng điểm
    expect(gameCtrl.rainbowCount.value, 0); // đã trừ 1 lượt
    for (final row in gsc.game.colorGrid) {
      expect(row, isNot(contains(0))); // hết mọi ô màu 0
    }

    Get.reset();
  });

  testWidgets('F3: tap ô obstacle (không màu thật) → không tiêu lượt', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    final gameCtrl = Get.put(GameController(), permanent: true);
    gameCtrl.startLevel(1);

    await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await _pumpFrames(tester, frames: 20);

    final gsc = Get.find<GameScreenController>();
    gsc.game.colorGrid = List.generate(
      gsc.game.rows,
      (r) => List.generate(gsc.game.cols, (c) => -1), // toàn obstacle
    );
    gsc.game.onGameResize(gsc.game.size);

    gameCtrl.rainbowCount.value = 1;
    gameCtrl.useRainbow(0, 0); // ô obstacle → triggerRainbow no-op
    await _pumpFrames(tester);

    expect(gameCtrl.rainbowCount.value, 1); // không trừ lượt

    Get.reset();
  });

  testWidgets('toggleRainbowArm bật/tắt đúng BoosterMode', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    final gameCtrl = Get.put(GameController(), permanent: true);
    gameCtrl.startLevel(1);

    await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    final gsc = Get.find<GameScreenController>();
    expect(gsc.armed.value, BoosterMode.none);
    gsc.toggleRainbowArm();
    expect(gsc.armed.value, BoosterMode.rainbow);
    gsc.toggleRainbowArm();
    expect(gsc.armed.value, BoosterMode.none);

    Get.reset();
  });
}

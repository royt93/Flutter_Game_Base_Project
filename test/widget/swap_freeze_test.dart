import 'package:flame/game.dart';
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
  testWidgets('F10: swap đổi đúng 2 ô, không tự nổ, trừ 1 lượt', (
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
    // Bàn cờ caro 2 màu: mọi cột đều xen kẽ 0/1.
    gsc.game.colorGrid = List.generate(
      gsc.game.rows,
      (r) => List.generate(gsc.game.cols, (c) => (r + c) % 2),
    );
    gsc.game.onGameResize(gsc.game.size);

    gameCtrl.swapCount.value = 1;
    gameCtrl.useSwap(0, 0, 0, 1); // (0,0) màu 0, (0,1) màu 1
    await _pumpFrames(tester);

    expect(gsc.game.colorGrid[0][0], 1); // đã đổi
    expect(gsc.game.colorGrid[0][1], 0); // đã đổi
    expect(gameCtrl.score.value, 0); // không tự nổ, không cộng điểm
    expect(gameCtrl.swapCount.value, 0); // đã trừ 1 lượt

    Get.reset();
  });

  testWidgets('toggleSwapArm bật/tắt đúng BoosterMode', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    final gameCtrl = Get.put(GameController(), permanent: true);
    gameCtrl.startLevel(1);

    await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    final gsc = Get.find<GameScreenController>();
    expect(gsc.armed.value, BoosterMode.none);
    gsc.toggleSwapArm();
    expect(gsc.armed.value, BoosterMode.swap);
    gsc.toggleSwapArm();
    expect(gsc.armed.value, BoosterMode.none);

    Get.reset();
  });

  testWidgets('F10: swap 2 tap qua handleBoardTap đổi đúng ô, trừ 1 lượt', (
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
      (r) => List.generate(gsc.game.cols, (c) => (r + c) % 2),
    );
    gsc.game.onGameResize(gsc.game.size);

    gameCtrl.swapCount.value = 1;
    gsc.toggleSwapArm();
    expect(gsc.armed.value, BoosterMode.swap);

    final cellSize = gsc.game.cellSize;
    final boardLeft = (gsc.game.size.x - gsc.game.cols * cellSize) / 2;
    final boardTop = (gsc.game.size.y - gsc.game.rows * cellSize) / 2;
    Vector2 centerOf(int row, int col) => Vector2(
      boardLeft + col * cellSize + cellSize / 2,
      boardTop + row * cellSize + cellSize / 2,
    );
    final posA = centerOf(0, 0);
    final posB = centerOf(0, 1);
    gsc.handleBoardTap(posA); // chọn ô đầu, chưa tiêu phí
    expect(gameCtrl.swapCount.value, 1);
    expect(gsc.armed.value, BoosterMode.swap); // vẫn arm chờ ô 2
    gsc.handleBoardTap(posB); // chọn ô 2 → thực hiện swap
    await _pumpFrames(tester);

    expect(gsc.game.colorGrid[0][0], 1);
    expect(gsc.game.colorGrid[0][1], 0);
    expect(gameCtrl.swapCount.value, 0);
    expect(gsc.armed.value, BoosterMode.none); // tự tắt arm sau khi dùng

    Get.reset();
  });

  testWidgets('F10: freeze chặn giảm bền lượt đang hiệu lực, hết freeze thì '
      'giảm bền lại bình thường', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    final gameCtrl = Get.put(GameController(), permanent: true);
    gameCtrl.startLevel(1);

    await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await _pumpFrames(tester, frames: 20);

    final gsc = Get.find<GameScreenController>();
    final rows = gsc.game.rows;
    final cols = gsc.game.cols;
    // (0,0) obstacle bền 1; (0,1)+(0,2) nhóm màu 0 liền kề obstacle; còn lại
    // fill màu 3 (không liên quan, tránh trùng nhóm ngoài ý muốn).
    List<List<int?>> gridWithObstacle() => List.generate(
      rows,
      (r) => List.generate(cols, (c) {
        if (r == 0 && c == 0) return -1;
        if (r == 0 && c == 1) return 0;
        if (r == 0 && c == 2) return 0;
        return 3;
      }),
    );

    // Freeze đang hiệu lực → chip bị chặn, obstacle giữ nguyên bền.
    gsc.game.colorGrid = gridWithObstacle();
    gsc.game.onGameResize(gsc.game.size);
    gsc.game.freezeTurnsLeft = 1;
    gsc.game.triggerRainbow(0, 1);
    await _pumpFrames(tester);
    expect(gsc.game.colorGrid[0][0], -1); // obstacle không giảm bền
    expect(gsc.game.freezeTurnsLeft, 0); // đã trừ 1 lượt freeze

    // Freeze đã hết (0 lượt) → chip bình thường, obstacle vỡ.
    gsc.game.colorGrid = gridWithObstacle();
    gsc.game.onGameResize(gsc.game.size);
    gsc.game.triggerRainbow(0, 1);
    await _pumpFrames(tester);
    expect(gsc.game.colorGrid[0][0], isNull); // vỡ vì hết freeze

    Get.reset();
  });
}

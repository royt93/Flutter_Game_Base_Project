import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/levels.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/game_screen_controller.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpFrames(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  testWidgets(
    'F6b: màn clearColor thắng ngay khi hết màu mục tiêu, dù bàn còn ô khác',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs), permanent: true);
      final gameCtrl = Get.put(GameController(), permanent: true);
      gameCtrl.startLevel(1);
      final base = gameCtrl.currentLevel;
      gameCtrl.currentLevelRx.value = PopLevel(
        id: base.id,
        rows: base.rows,
        cols: base.cols,
        colorCount: base.colorCount,
        targetScore: base.targetScore,
        objective: const LevelObjective.clearColor(0),
      );

      await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await _pumpFrames(tester, frames: 20); // A6: chờ hết intro rơi ô

      final gsc = Get.find<GameScreenController>();
      final game = gsc.game;

      // Chỉ 2 ô màu 0 (mục tiêu), còn lại toàn màu 1 — bàn vẫn đầy sau khi
      // dọn xong màu 0 nên chỉ objective mới kết thúc được ván, không phải
      // bàn hết/kẹt.
      game.colorGrid = List.generate(
        game.rows,
        (r) => List.generate(game.cols, (c) {
          if (r == 0 && c == 0) return 0;
          if (r == 0 && c == 1) return 0;
          return 1;
        }),
      );
      game.onGameResize(game.size);

      final cellSize = game.cellSize;
      final boardLeft = (game.size.x - game.cols * cellSize) / 2;
      final boardTop = (game.size.y - game.rows * cellSize) / 2;
      Vector2 centerOf(int row, int col) => Vector2(
        boardLeft + col * cellSize + cellSize / 2,
        boardTop + row * cellSize + cellSize / 2,
      );

      expect(gameCtrl.ended.value, isFalse);
      game.handleTap(centerOf(0, 0));
      await _pumpFrames(tester);

      expect(gameCtrl.objectiveRemaining.value, 0);
      expect(gameCtrl.ended.value, isTrue);
      // Bàn chưa hết — chứng minh thắng do objective, không phải clear-board.
      expect(game.colorGrid[0][2], isNotNull);

      Get.reset();
    },
  );

  testWidgets(
    'F6b: màn campaign clearObstacle (level 5) dựng bàn có sẵn obstacle',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs), permanent: true);
      final gameCtrl = Get.put(GameController(), permanent: true);
      gameCtrl.startLevel(5); // i=4, slot 4 → clearObstacle theo levels.dart

      await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await _pumpFrames(tester, frames: 20); // chờ hết intro rơi ô

      final gsc = Get.find<GameScreenController>();
      final grid = gsc.game.colorGrid;

      expect(gameCtrl.currentLevel.objective.type, ObjectiveType.clearObstacle);
      expect(
        grid.expand((row) => row).where((v) => v != null && v < 0),
        isNotEmpty,
      );

      Get.reset();
    },
  );
}

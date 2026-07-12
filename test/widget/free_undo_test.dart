import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
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
    'I5: lần undo đầu tiên miễn phí, lần 2 trở đi trừ undoCount như cũ',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs), permanent: true);
      final gameCtrl = Get.put(GameController(), permanent: true);
      gameCtrl.startLevel(1);
      gameCtrl.undoCount.value = 0; // không còn booster mua sẵn

      await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await _pumpFrames(tester, frames: 20); // A6: chờ hết intro rơi ô

      final gsc = Get.find<GameScreenController>();
      final game = gsc.game;

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

      game.handleTap(centerOf(0, 0));
      await _pumpFrames(tester);
      expect(game.colorGrid[0][0], isNull); // nhóm màu 0 đã nổ

      // Lần undo đầu tiên: miễn phí dù undoCount = 0.
      gameCtrl.useUndo();
      await _pumpFrames(tester);
      expect(game.colorGrid[0][0], 0); // board đã revert lại
      expect(gameCtrl.undoCount.value, 0); // không bị trừ

      // Nổ lại để tạo snapshot undo mới.
      game.handleTap(centerOf(0, 0));
      await _pumpFrames(tester);
      expect(game.colorGrid[0][0], isNull);

      // Lần undo thứ 2 trong cùng màn: hết vé miễn phí, undoCount = 0 → chặn.
      gameCtrl.useUndo();
      await _pumpFrames(tester);
      expect(game.colorGrid[0][0], isNull); // board KHÔNG revert
      expect(gameCtrl.undoCount.value, 0);

      Get.reset();
    },
  );
}

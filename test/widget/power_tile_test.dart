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
  testWidgets(
    'F5a: nhóm >=5 sinh power tile line-clear, tap lại kích hoạt xoá hàng/cột',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs), permanent: true);
      final gameCtrl = Get.put(GameController(), permanent: true);
      gameCtrl.startLevel(1);

      await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await _pumpFrames(tester, frames: 20); // A6: chờ hết intro rơi ô

      final gsc = Get.find<GameScreenController>();
      final game = gsc.game;
      const targetRow = 0;
      // Cột cuối để màu khác (filler) → nhóm màu 0 chỉ dài cols-1 ô, vẫn còn
      // 1 ô filler sống sót trong hàng để test row-kind activation không rơi
      // về trường hợp trơ 1 ô (score 0).
      final tapCol = (game.cols - 1) ~/ 2;
      game.colorGrid = List.generate(
        game.rows,
        (r) => List.generate(
          game.cols,
          (c) => r == targetRow && c < game.cols - 1 ? 0 : 1,
        ),
      );
      game.onGameResize(game.size);

      final cellSize = game.cellSize;
      final boardLeft = (game.size.x - game.cols * cellSize) / 2;
      final boardTop = (game.size.y - game.rows * cellSize) / 2;
      Vector2 centerOf(int row, int col) => Vector2(
        boardLeft + col * cellSize + cellSize / 2,
        boardTop + row * cellSize + cellSize / 2,
      );

      expect(gameCtrl.score.value, 0);
      game.handleTap(centerOf(targetRow, tapCol));
      await _pumpFrames(tester);

      // Ô vừa tap giữ lại làm power tile; các ô cùng nhóm khác bị xoá; ô
      // filler cuối hàng không liên quan nên vẫn còn.
      expect(game.colorGrid[targetRow][tapCol], isNotNull);
      expect(game.colorGrid[targetRow][game.cols - 1], isNotNull);
      for (var c = 0; c < game.cols - 1; c++) {
        if (c == tapCol) continue;
        expect(game.colorGrid[targetRow][c], isNull);
      }
      final scoreAfterFirstPop = gameCtrl.score.value;
      expect(scoreAfterFirstPop, greaterThan(0));

      // Tap lại đúng ô đó (vị trí không đổi vì cột này không có ô nào bị xoá
      // ở lượt trước) để kích hoạt power tile.
      game.handleTap(centerOf(targetRow, tapCol));
      await _pumpFrames(tester);

      expect(game.colorGrid[targetRow][tapCol], isNull);
      expect(gameCtrl.score.value, greaterThan(scoreAfterFirstPop));

      Get.reset();
    },
  );
}

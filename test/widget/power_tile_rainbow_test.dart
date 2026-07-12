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
    'F5c: nhóm >=9 sinh power tile rainbow, tap lại xoá hết ô cùng màu dù rời rạc',
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

      // Khối màu 0 chiếm trọn hàng 0-1 (12 ô, đủ ngưỡng rainbow) sát mép trên
      // → nhóm bị trừ ô tap không rơi vào khoảng trống của filler bên dưới,
      // gravity không dịch chuyển gì ở lượt tap đầu. Thêm 2 ô màu 0 rời rạc
      // (không liền kề khối) để kiểm chứng rainbow gom cả ô xa, không chỉ
      // đúng vùng nhóm gốc.
      game.colorGrid = List.generate(
        game.rows,
        (r) => List.generate(game.cols, (c) {
          if (r <= 1) return 0;
          if (r == 5 && c == 0) return 0;
          if (r == 6 && c == 5) return 0;
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

      expect(gameCtrl.score.value, 0);
      game.handleTap(centerOf(1, 2));
      await _pumpFrames(tester);

      // Ô tap (1,2) giữ lại làm power tile; phần còn lại của khối bị xoá; 2 ô
      // rời rạc không liên quan tới nhóm nên vẫn còn nguyên chỗ cũ.
      expect(game.colorGrid[1][2], 0);
      expect(game.colorGrid[0][2], isNull);
      expect(game.colorGrid[5][0], 0);
      expect(game.colorGrid[6][5], 0);
      final scoreAfterFirstPop = gameCtrl.score.value;
      expect(scoreAfterFirstPop, greaterThan(0));

      // Tap lại đúng ô đó để kích hoạt rainbow: xoá mọi ô màu 0 trên bàn, kể
      // cả 2 ô rời rạc xa vị trí tap.
      game.handleTap(centerOf(1, 2));
      await _pumpFrames(tester);

      expect(gameCtrl.score.value, greaterThan(scoreAfterFirstPop));
      final flatGrid = game.colorGrid.expand((row) => row);
      expect(flatGrid.contains(0), isFalse);
      // Bàn không bị xoá sạch toàn bộ — filler màu 1 vẫn còn (rainbow chỉ
      // xoá đúng 1 màu, không phải cả bàn).
      expect(flatGrid.any((v) => v == 1), isTrue);

      Get.reset();
    },
  );
}

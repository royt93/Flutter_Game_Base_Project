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
    'F5d: vùng nổ vướng power tile khác → kích hoạt cộng hưởng, xoá luôn '
    'vùng nổ tile đó dù nằm ngoài bán kính gốc',
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

      // Nhóm L màu 0 (7 ô, hàng 0-1) → tap (1,1) sinh power tile bomb.
      // Nhóm màu 2 (9 ô, hàng 2-4 cột 2-5, tránh cột 1 để không đá bomb rơi
      // khi collapse) → tap (2,3) sinh power tile rainbow, nằm trong bán
      // kính 5x5 của bomb (hàng 0-3, cột 0-3).
      // 1 ô màu 2 tách biệt tại (6,5), ngoài bán kính bomb — chỉ rainbow mới
      // quét trúng, chứng minh cộng hưởng thật sự lan ra ngoài vùng bomb.
      game.colorGrid = List.generate(
        game.rows,
        (r) => List.generate(game.cols, (c) {
          if (r == 0 && c <= 3) return 0;
          if (r == 1 && c <= 2) return 0;
          if (r == 2 && c >= 2) return 2;
          if (r == 3 && c >= 2) return 2;
          if (r == 4 && c == 2) return 2;
          if (r == 6 && c == 5) return 2;
          return 1;
        }),
      );
      game.onGameResize(game.size);
      await _pumpFrames(tester, frames: 5);

      final cellSize = game.cellSize;
      final boardLeft = (game.size.x - game.cols * cellSize) / 2;
      final boardTop = (game.size.y - game.rows * cellSize) / 2;
      Vector2 centerOf(int row, int col) => Vector2(
        boardLeft + col * cellSize + cellSize / 2,
        boardTop + row * cellSize + cellSize / 2,
      );

      game.handleTap(centerOf(1, 1));
      await _pumpFrames(tester);
      game.handleTap(centerOf(2, 3));
      await _pumpFrames(tester);

      // Sau khi rơi/gộp cột, rainbow (giữ nguyên màu 2 tại ô vừa tap) có thể
      // bị gravity đẩy lệch hàng trong cùng cột — dò đúng ô còn power tile.
      var rainbowRow = -1;
      for (var r = 0; r < game.rows; r++) {
        if (game.colorGrid[r][3] == 2) rainbowRow = r;
      }
      expect(rainbowRow, greaterThanOrEqualTo(0));
      expect(game.colorGrid[6][5], 2); // ô cộng hưởng ở xa, chưa bị đụng tới

      final scoreBeforeBomb = gameCtrl.score.value;

      game.handleTap(centerOf(1, 1)); // kích hoạt bomb → cộng hưởng rainbow
      await _pumpFrames(tester);

      expect(gameCtrl.score.value, greaterThan(scoreBeforeBomb));
      // Sau collapse, ô trống dồn lên đầu cột nên vị trí (6,5) không còn giữ
      // nguyên chỗ — kiểm tra toàn bàn không còn ô màu 2 nào chứng minh ô
      // cộng hưởng ở xa (ngoài bán kính 5x5 gốc của bomb) đã bị xoá theo.
      final remainingColor2 = game.colorGrid
          .expand((row) => row)
          .where((v) => v == 2);
      expect(remainingColor2, isEmpty);
      // Vẫn còn ô sống sót khác — cộng hưởng không xoá sạch cả bàn.
      expect(
        game.colorGrid.expand((row) => row).where((v) => v != null),
        isNotEmpty,
      );

      Get.reset();
    },
  );
}

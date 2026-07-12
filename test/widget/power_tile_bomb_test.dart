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
  testWidgets('F5b: nhóm >=7 sinh power tile bomb, tap lại xoá vùng 5x5', (
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
    final game = gsc.game;

    // Hình chữ L màu 0 (7 ô, đủ ngưỡng bomb) nằm sát mép trên-trái; toàn bộ
    // ô còn lại là filler màu 1. Nhóm chỉ chiếm hàng 0-1 nên khi trừ nhóm
    // (trừ ô tap) không có ô nào bị xoá rơi vào khoảng trống bên dưới ô còn
    // sống hay bên dưới filler → gravity không dịch chuyển gì cả, toạ độ
    // dự đoán được chính xác cho cả 2 lượt tap.
    game.colorGrid = List.generate(
      game.rows,
      (r) => List.generate(game.cols, (c) {
        if (r == 0 && c <= 3) return 0;
        if (r == 1 && c <= 2) return 0;
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
    game.handleTap(centerOf(1, 1));
    await _pumpFrames(tester);

    // Ô tap (1,1) giữ lại làm power tile; 6 ô còn lại trong nhóm L bị xoá;
    // filler ngoài nhóm (vd (1,3)) không liên quan nên vẫn còn.
    expect(game.colorGrid[1][1], isNotNull);
    expect(game.colorGrid[0][0], isNull);
    expect(game.colorGrid[0][3], isNull);
    expect(game.colorGrid[1][0], isNull);
    expect(game.colorGrid[1][3], isNotNull);
    final scoreAfterFirstPop = gameCtrl.score.value;
    expect(scoreAfterFirstPop, greaterThan(0));

    // Tap lại đúng ô đó (không đổi vị trí, xem lý giải ở trên) để kích hoạt
    // bomb: xoá vùng 5x5 quanh (1,1) — bị kẹp mép trên-trái nên thực tế chỉ
    // còn hàng 0-3, cột 0-3 (10 ô có màu trong vùng này).
    game.handleTap(centerOf(1, 1));
    await _pumpFrames(tester);

    expect(gameCtrl.score.value, greaterThan(scoreAfterFirstPop));

    // Trong vùng 5x5: mọi ô đều bị xoá sạch.
    expect(game.colorGrid[1][1], isNull);
    expect(game.colorGrid[2][2], isNull);
    expect(game.colorGrid[3][3], isNull);
    // Ngoài vùng 5x5 (cột 4-5, hoặc hàng >=4): filler còn nguyên, không bị
    // ăn theo — chứng minh bomb chỉ xoá đúng vùng, không xoá cả bàn.
    expect(game.colorGrid[0][4], isNotNull);
    expect(game.colorGrid[4][0], isNotNull);
    expect(game.colorGrid[7][5], isNotNull);

    Get.reset();
  });
}

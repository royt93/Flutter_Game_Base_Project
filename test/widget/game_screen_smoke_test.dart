import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/worlds.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/game_screen_controller.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:pop_star_blast/presentation/widgets/neon_bg.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bơm nhiều frame nhỏ để game loop chạy hết effect + TimerComponent animation.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  testWidgets('dựng level, tap nhóm cùng màu thì điểm tăng', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    final gameCtrl = Get.put(GameController(), permanent: true);
    gameCtrl.startLevel(1);

    await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await _pumpFrames(tester, frames: 20); // A6: chờ hết intro rơi ô

    final gsc = Get.find<GameScreenController>();
    // Ép bàn về toàn 1 màu để chắc chắn có nhóm nổ được, tránh phụ thuộc RNG.
    gsc.game.colorGrid = List.generate(
      gsc.game.rows,
      (_) => List.generate(gsc.game.cols, (_) => 0),
    );

    expect(gameCtrl.score.value, 0);
    await tester.tapAt(tester.getCenter(find.byType(GameWidget<PopStarGame>)));
    await _pumpFrames(tester);

    expect(gameCtrl.score.value, greaterThan(0));

    Get.reset();
  });

  testWidgets('clear sạch bàn 1 màu = thắng, cộng xu + mở khoá màn sau', (
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
    // Cả bàn cùng màu → nhóm khổng lồ (>=5) sinh power tile (F5a) tại ô vừa
    // tap; phần còn lại nổ hết → gravity+collapse dồn ô sống sót về
    // (rows-1, 0). Tap lại đúng ô đó để kích hoạt, dọn sạch nốt → thắng.
    game.colorGrid = List.generate(
      game.rows,
      (_) => List.generate(game.cols, (_) => 0),
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
    await _pumpFrames(tester); // chạy hết animation pop + rơi

    game.handleTap(centerOf(game.rows - 1, 0));
    await _pumpFrames(tester); // kích hoạt power tile, dọn sạch bàn

    expect(gameCtrl.ended.value, isTrue);
    expect(gameCtrl.cleared.value, isTrue);
    expect(gameCtrl.starsEarned.value, greaterThan(0));
    expect(gameCtrl.coins.value, greaterThan(0));
    expect(gameCtrl.unlockedLevel.value, 2);
    expect(gsc.ui.value, GameUi.win);

    Get.reset();
  });

  testWidgets('I14: NeonBg nhận đúng accent theo world của level đang chơi', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    final gameCtrl = Get.put(GameController(), permanent: true);
    gameCtrl.startLevel(25); // world 2 (id 21..40) — khác world 1 mặc định

    await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    final bg = tester.widget<NeonBg>(find.byType(NeonBg));
    expect(bg.accent, worldForLevel(25).color);

    Get.reset();
  });
}

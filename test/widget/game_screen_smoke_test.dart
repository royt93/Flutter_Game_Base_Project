import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/game_screen_controller.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('dựng level, tap nhóm cùng màu thì điểm tăng', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    final gameCtrl = Get.put(GameController(), permanent: true);
    gameCtrl.startLevel(1);

    await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    final gsc = Get.find<GameScreenController>();
    // Ép bàn về toàn 1 màu để chắc chắn có nhóm nổ được, tránh phụ thuộc RNG.
    gsc.game.colorGrid = List.generate(
      gsc.game.rows,
      (_) => List.generate(gsc.game.cols, (_) => 0),
    );

    expect(gameCtrl.score.value, 0);
    await tester.tapAt(tester.getCenter(find.byType(GameWidget<PopStarGame>)));
    await tester.pump(const Duration(milliseconds: 400));

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

    final gsc = Get.find<GameScreenController>();
    // Cả bàn cùng màu → 1 tap nổ hết → clearBoardBonus → thắng chắc chắn.
    gsc.game.colorGrid = List.generate(
      gsc.game.rows,
      (_) => List.generate(gsc.game.cols, (_) => 0),
    );

    await tester.tapAt(tester.getCenter(find.byType(GameWidget<PopStarGame>)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(gameCtrl.ended.value, isTrue);
    expect(gameCtrl.cleared.value, isTrue);
    expect(gameCtrl.starsEarned.value, greaterThan(0));
    expect(gameCtrl.coins.value, greaterThan(0));
    expect(gameCtrl.unlockedLevel.value, 2);

    // Xả timer 350ms của overlay thắng trước khi kết thúc test.
    await tester.pump(const Duration(milliseconds: 400));
    expect(gsc.ui.value, GameUi.win);

    Get.reset();
  });
}

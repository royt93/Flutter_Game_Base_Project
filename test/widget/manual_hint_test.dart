import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/game_screen_controller.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<GameScreenController> pumpGame(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    Get.put(GameController(), permanent: true).startLevel(1);

    await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    return Get.find<GameScreenController>();
  }

  testWidgets(
    'I31: useHint hiện ngay nhóm lớn nhất (không đợi idle), trừ hintCount, '
    'tự tắt sau ~1.5s',
    (tester) async {
      final gsc = await pumpGame(tester);
      final game = gsc.game;

      var counter = 1;
      game.colorGrid = List.generate(
        game.rows,
        (r) => List.generate(game.cols, (c) => counter++),
      );
      game.colorGrid[0][0] = 0;
      game.colorGrid[0][1] = 0;
      game.colorGrid[1][0] = 0;
      game.clearHint();

      final startCount = gsc.gameCtrl.hintCount.value;
      expect(game.hintGroup, isEmpty);

      // Hiện ngay, không cần chờ 6s idle threshold của I4.
      gsc.useHint();
      await tester.pump();
      expect(
        game.hintGroup,
        equals({const Point(0, 0), const Point(0, 1), const Point(1, 0)}),
      );
      expect(gsc.gameCtrl.hintCount.value, startCount - 1);

      // Chưa hết 1.5s → vẫn còn hiển thị.
      await tester.pump(const Duration(milliseconds: 900));
      expect(game.hintGroup, isNotEmpty);

      // Qua mốc 1.5s → tự tắt mà không cần tap.
      await tester.pump(const Duration(milliseconds: 900));
      expect(game.hintGroup, isEmpty);

      Get.reset();
    },
  );

  testWidgets('I31: useHint KHÔNG trừ lượt khi bàn không còn nhóm nào ≥2', (
    tester,
  ) async {
    final gsc = await pumpGame(tester);
    final game = gsc.game;

    // Mọi ô 1 màu riêng biệt — bàn kẹt, không có nhóm ≥2 nào.
    var counter = 1;
    game.colorGrid = List.generate(
      game.rows,
      (r) => List.generate(game.cols, (c) => counter++),
    );
    game.clearHint();

    final startCount = gsc.gameCtrl.hintCount.value;
    gsc.useHint();
    await tester.pump();

    expect(game.hintGroup, isEmpty);
    expect(gsc.gameCtrl.hintCount.value, startCount);

    Get.reset();
  });

  testWidgets(
    'I31: bấm Hint khi gợi ý đang hiện sẵn KHÔNG trừ thêm lượt (double-spend)',
    (tester) async {
      final gsc = await pumpGame(tester);
      final game = gsc.game;

      var counter = 1;
      game.colorGrid = List.generate(
        game.rows,
        (r) => List.generate(game.cols, (c) => counter++),
      );
      game.colorGrid[0][0] = 0;
      game.colorGrid[0][1] = 0;
      game.colorGrid[1][0] = 0;
      game.clearHint();

      final startCount = gsc.gameCtrl.hintCount.value;

      gsc.useHint();
      await tester.pump();
      expect(gsc.gameCtrl.hintCount.value, startCount - 1);
      expect(game.hintGroup, isNotEmpty);

      // Bấm lại khi gợi ý (idle hoặc thủ công) vẫn đang hiện sẵn — không
      // được trừ thêm lượt, và không rút ngắn thời gian hiện sẵn có.
      gsc.useHint();
      await tester.pump();
      expect(gsc.gameCtrl.hintCount.value, startCount - 1);

      Get.reset();
    },
  );

  testWidgets('I31: hintCount reset về hintsPerRun khi bắt đầu màn mới', (
    tester,
  ) async {
    final gsc = await pumpGame(tester);
    gsc.gameCtrl.hintCount.value = 0;
    expect(gsc.gameCtrl.hintCount.value, 0);

    gsc.gameCtrl.startLevel(2);
    expect(gsc.gameCtrl.hintCount.value, GameController.hintsPerRun);

    Get.reset();
  });
}

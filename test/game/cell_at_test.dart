import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/levels.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// I71: `cellAt()` là hot path chưa từng có test nào bao phủ trước batch
/// này. Dựng 1 `PopStarGame` thật qua `GameWidget` để có `cellSize`/
/// `_boardLeft`/`_boardTop` thật (không tự tính tay, tránh lệch công thức
/// với `_layout()`), rồi gọi thẳng `cellAt()` để xác nhận:
/// - tolerance OFF (mặc định) không đổi hành vi hiện tại (regression chính).
/// - tolerance ON chỉ nới mép NGOÀI bàn cờ, không snap sang ô lân cận khi
///   tap đã nằm trong bàn.
Future<PopStarGame> _buildGame(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Get.put(StorageService(prefs), permanent: true);
  final gameCtrl = Get.put(GameController(), permanent: true);
  gameCtrl.currentLevelRx.value = kLevels[0];
  final game = PopStarGame(gameCtrl, seed: 1, isReplay: true);

  await tester.pumpWidget(GetMaterialApp(home: GameWidget(game: game)));
  await tester.pump(const Duration(milliseconds: 100));
  return game;
}

void main() {
  tearDown(Get.reset);

  testWidgets('tolerance OFF: tap ngoài bàn (dù rất gần biên) trả về null', (
    tester,
  ) async {
    final game = await _buildGame(tester);
    expect(StorageService.to.getBool(StorageKeys.largerTapTargets), isFalse);

    final boardLeft = (game.size.x - game.cols * game.cellSize) / 2;
    final boardTop = (game.size.y - game.rows * game.cellSize) / 2;

    // 1px ngoài mép trái/trên — không tolerance nên phải null.
    expect(game.cellAt(Vector2(boardLeft - 1, boardTop + 1)), isNull);
    expect(game.cellAt(Vector2(boardLeft + 1, boardTop - 1)), isNull);
  });

  testWidgets('tolerance OFF: tap trong bàn vẫn resolve đúng ô như trước', (
    tester,
  ) async {
    final game = await _buildGame(tester);
    final boardLeft = (game.size.x - game.cols * game.cellSize) / 2;
    final boardTop = (game.size.y - game.rows * game.cellSize) / 2;

    final cell = game.cellAt(
      Vector2(boardLeft + game.cellSize / 2, boardTop + game.cellSize / 2),
    );
    expect(cell, Point(0, 0));
  });

  testWidgets(
    'tolerance ON: tap ngay ngoài mép (trong khoảng 12px) resolve về ô biên',
    (tester) async {
      final game = await _buildGame(tester);
      await StorageService.to.setBool(StorageKeys.largerTapTargets, true);

      final boardLeft = (game.size.x - game.cols * game.cellSize) / 2;
      final boardTop = (game.size.y - game.rows * game.cellSize) / 2;
      final boardRight = boardLeft + game.cols * game.cellSize;
      final boardBottom = boardTop + game.rows * game.cellSize;

      // 5px ngoài mép trái/trên -> vẫn trong tolerance 12px -> ô (0,0).
      expect(game.cellAt(Vector2(boardLeft - 5, boardTop - 5)), Point(0, 0));
      // 5px ngoài mép phải/dưới -> ô biên cuối cùng.
      expect(
        game.cellAt(Vector2(boardRight + 5, boardBottom + 5)),
        Point(game.rows - 1, game.cols - 1),
      );
    },
  );

  testWidgets('tolerance ON: tap vượt quá 12px vẫn trả về null', (
    tester,
  ) async {
    final game = await _buildGame(tester);
    await StorageService.to.setBool(StorageKeys.largerTapTargets, true);

    final boardLeft = (game.size.x - game.cols * game.cellSize) / 2;
    final boardTop = (game.size.y - game.rows * game.cellSize) / 2;

    expect(game.cellAt(Vector2(boardLeft - 13, boardTop + 1)), isNull);
  });

  testWidgets('tolerance ON: tap đã nằm trong bàn không snap sang ô lân cận', (
    tester,
  ) async {
    final game = await _buildGame(tester);
    await StorageService.to.setBool(StorageKeys.largerTapTargets, true);

    final boardLeft = (game.size.x - game.cols * game.cellSize) / 2;
    final boardTop = (game.size.y - game.rows * game.cellSize) / 2;

    // Tap gần mép phải của ô (0,0) nhưng vẫn trong ô đó -> vẫn (0,0),
    // không bị kéo sang ô (0,1) dù tolerance đang bật.
    final cell = game.cellAt(
      Vector2(boardLeft + game.cellSize - 1, boardTop + 1),
    );
    expect(cell, Point(0, 0));
  });
}

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
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

/// Dựng level 1, ép cả bàn cùng 1 màu (sinh power tile khi tap), rồi tap 2
/// lần để dọn sạch bàn và thắng — đồng bộ pattern với `game_screen_smoke_test.dart`.
Future<GameScreenController> _playToWin(
  WidgetTester tester, {
  required bool recordReplay,
}) async {
  SharedPreferences.setMockInitialValues({
    StorageKeys.recordReplay: recordReplay,
  });
  final prefs = await SharedPreferences.getInstance();
  Get.put(StorageService(prefs), permanent: true);
  final gameCtrl = Get.put(GameController(), permanent: true);
  gameCtrl.startLevel(1);

  await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
  await tester.pump(const Duration(milliseconds: 100));
  await _pumpFrames(tester, frames: 20); // chờ hết intro rơi ô

  final gsc = Get.find<GameScreenController>();
  final game = gsc.game;
  game.colorGrid = List.generate(
    game.rows,
    (_) => List.generate(game.cols, (_) => 0),
  );

  await tester.tapAt(tester.getCenter(find.byType(GameWidget<PopStarGame>)));
  await _pumpFrames(tester); // pop nhóm khổng lồ → sinh power tile

  final cellSize = game.cellSize;
  final boardLeft = (game.size.x - game.cols * cellSize) / 2;
  final boardTop = (game.size.y - game.rows * cellSize) / 2;
  Vector2 centerOf(int row, int col) => Vector2(
    boardLeft + col * cellSize + cellSize / 2,
    boardTop + row * cellSize + cellSize / 2,
  );
  game.handleTap(centerOf(game.rows - 1, 0));
  await _pumpFrames(tester); // kích hoạt power tile, dọn sạch bàn, thắng

  expect(gsc.ui.value, GameUi.win);
  return gsc;
}

void main() {
  testWidgets(
    'I28: recordReplay tắt (mặc định) → nút share_replay ẩn ở overlay thắng',
    (tester) async {
      final gsc = await _playToWin(tester, recordReplay: false);

      expect(gsc.canShareReplay, isFalse);
      expect(find.byIcon(Icons.movie_creation_rounded), findsNothing);
      // Nút share ảnh bàn chơi (F15) vẫn phải hiện bình thường, không bị ảnh
      // hưởng bởi việc ẩn nút replay.
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);

      Get.reset();
    },
  );

  testWidgets(
    'I28: recordReplay bật + có tap ghi được → nút share_replay hiện ở '
    'overlay thắng',
    (tester) async {
      final gsc = await _playToWin(tester, recordReplay: true);

      expect(gsc.canShareReplay, isTrue);
      expect(find.byIcon(Icons.movie_creation_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);

      Get.reset();
    },
  );
}

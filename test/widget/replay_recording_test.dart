import 'package:flame/game.dart';
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

/// Dựng harness campaign level 1 với cờ [StorageKeys.recordReplay] tuỳ chọn,
/// đồng bộ pattern với `power_tile_test.dart`. Trả về [GameScreenController]
/// đã pump xong (đợi hết intro rơi ô).
Future<GameScreenController> _pumpGame(
  WidgetTester tester, {
  bool recordReplay = true,
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
  await _pumpFrames(tester, frames: 20);

  return Get.find<GameScreenController>();
}

/// Chỉ hàng 0 (trừ ô cuối) là nhóm màu 0 liền kề (đủ ≥2 ô để nổ được), các
/// hàng còn lại filler màu 1 — tránh 1 nhóm khổng lồ nổ sạch cả bàn cùng lúc
/// (đồng bộ pattern với `power_tile_test.dart`) + mở khoá mọi ô, để mọi hành
/// động (bomb/rainbow/swap/shuffle) đều chắc chắn tác động được ô thật.
Vector2 Function(int, int) _forceUniformGrid(PopStarGame game) {
  const targetRow = 0;
  game.colorGrid = List.generate(
    game.rows,
    (r) => List<int?>.generate(
      game.cols,
      (c) => r == targetRow && c < game.cols - 1 ? 0 : 1,
    ),
  );
  game.lockGrid = List.generate(game.rows, (_) => List.filled(game.cols, 0));
  game.onGameResize(game.size);
  final cellSize = game.cellSize;
  final boardLeft = (game.size.x - game.cols * cellSize) / 2;
  final boardTop = (game.size.y - game.rows * cellSize) / 2;
  return (row, col) => Vector2(
    boardLeft + col * cellSize + cellSize / 2,
    boardTop + row * cellSize + cellSize / 2,
  );
}

void main() {
  testWidgets(
    'I28: tap thường được ghi vào recordedTaps, recordingValid vẫn true',
    (tester) async {
      final gsc = await _pumpGame(tester);
      final game = gsc.game;
      expect(game.recordingEnabled, isTrue);
      expect(game.recordingValid, isTrue);
      expect(game.recordedTaps, isEmpty);

      final centerOf = _forceUniformGrid(game);
      game.handleTap(centerOf(0, 0));
      await _pumpFrames(tester);

      expect(game.recordedTaps, isNotEmpty);
      expect(game.recordedTaps.first, (0, 0));
      expect(game.recordingValid, isTrue);

      Get.reset();
    },
  );

  testWidgets(
    'I28: recordReplay tắt (mặc định) → recordingEnabled false, không ghi tap',
    (tester) async {
      final gsc = await _pumpGame(tester, recordReplay: false);
      final game = gsc.game;
      expect(game.recordingEnabled, isFalse);

      final centerOf = _forceUniformGrid(game);
      game.handleTap(centerOf(0, 0));
      await _pumpFrames(tester);

      expect(game.recordedTaps, isEmpty);
      expect(gsc.canShareReplay, isFalse);

      Get.reset();
    },
  );

  testWidgets('I28: triggerBomb làm recordingValid → false', (tester) async {
    final gsc = await _pumpGame(tester);
    final game = gsc.game;
    _forceUniformGrid(game);

    expect(game.recordingValid, isTrue);
    expect(game.triggerBomb(0, 0), isTrue);
    expect(game.recordingValid, isFalse);

    Get.reset();
  });

  testWidgets('I28: triggerRainbow làm recordingValid → false', (tester) async {
    final gsc = await _pumpGame(tester);
    final game = gsc.game;
    _forceUniformGrid(game);

    expect(game.recordingValid, isTrue);
    expect(game.triggerRainbow(0, 0), isTrue);
    expect(game.recordingValid, isFalse);

    Get.reset();
  });

  testWidgets('I28: triggerSwap làm recordingValid → false', (tester) async {
    final gsc = await _pumpGame(tester);
    final game = gsc.game;
    _forceUniformGrid(game);

    expect(game.recordingValid, isTrue);
    expect(game.triggerSwap(0, 0, 0, 1), isTrue);
    expect(game.recordingValid, isFalse);

    Get.reset();
  });

  testWidgets('I28: shuffleBoard làm recordingValid → false', (tester) async {
    final gsc = await _pumpGame(tester);
    final game = gsc.game;
    _forceUniformGrid(game);

    expect(game.recordingValid, isTrue);
    expect(game.shuffleBoard(), isTrue);
    expect(game.recordingValid, isFalse);
    await _pumpFrames(tester); // để rebuild animation chạy xong, tránh leak.

    Get.reset();
  });

  testWidgets('I28: applyFreeze làm recordingValid → false', (tester) async {
    final gsc = await _pumpGame(tester);
    final game = gsc.game;
    _forceUniformGrid(game);

    expect(game.recordingValid, isTrue);
    game.applyFreeze(3);
    expect(game.recordingValid, isFalse);
    expect(game.freezeTurnsLeft, 3);

    Get.reset();
  });

  testWidgets('I28: undo làm recordingValid → false (kể cả gọi lại true)', (
    tester,
  ) async {
    final gsc = await _pumpGame(tester);
    final game = gsc.game;
    _forceUniformGrid(game);

    // triggerSwap tạo snapshot undo (_saveUndo) và không set _animating,
    // nên undo() gọi ngay sau đó không bị chặn bởi guard "đang animate".
    expect(game.triggerSwap(0, 0, 0, 1), isTrue);
    // Cô lập assertion cho chính undo(), không lẫn hiệu ứng của triggerSwap.
    game.recordingValid = true;

    expect(game.undo(), isTrue);
    expect(game.recordingValid, isFalse);

    Get.reset();
  });

  testWidgets(
    'I28: canShareReplay chỉ true khi có tap ghi được và recordingValid',
    (tester) async {
      final gsc = await _pumpGame(tester);
      final game = gsc.game;
      expect(gsc.canShareReplay, isFalse); // chưa tap gì.

      final centerOf = _forceUniformGrid(game);
      game.handleTap(centerOf(0, 0));
      await _pumpFrames(tester);
      expect(gsc.canShareReplay, isTrue);

      // Dùng booster (giả mạo "chia sẻ ván gian lận") → phải chặn share.
      expect(game.triggerBomb(0, 1), isTrue);
      expect(gsc.canShareReplay, isFalse);

      Get.reset();
    },
  );
}

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/logic/boss_tile.dart' show bossTileIdBase;
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/game_screen_controller.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpFrames(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

/// Dựng 1 [GameScreen] chạy thật (không mock game engine) rồi trả về
/// [PopStarGame] để test ghi đè trực tiếp `colorGrid`/`bossHp` — cùng pattern
/// đã dùng ở `free_undo_test.dart`.
Future<PopStarGame> _bootGame(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Get.put(StorageService(prefs), permanent: true);
  final gameCtrl = Get.put(GameController(), permanent: true);
  gameCtrl.startLevel(1);

  await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
  await tester.pump(const Duration(milliseconds: 100));
  await _pumpFrames(tester, frames: 20); // A6: chờ hết intro rơi ô

  final gsc = Get.find<GameScreenController>();
  return gsc.game;
}

void main() {
  // Đảm bảo dọn GetX dù test fail giữa chừng (expect ném exception thì các
  // dòng Get.reset() cuối mỗi test không chạy tới) — nếu không, state cũ
  // (GameController permanent, PopStarGame cũ) rò rỉ sang test kế tiếp.
  tearDown(Get.reset);

  testWidgets(
    'I29: nổ nhóm liền kề chip 1 HP boss tile, chưa vỡ khi HP còn > 0',
    (tester) async {
      final game = await _bootGame(tester);

      // Khối boss 1x2 tại (0,0)-(0,1); nhóm màu 0 tại (0,2)-(0,3) liền kề
      // cạnh (0,1). Phần còn lại màu 1 để không tạo thêm nhóm nổ ngẫu nhiên.
      game.colorGrid = List.generate(
        game.rows,
        (r) => List.generate(game.cols, (c) {
          if (r == 0 && c == 0) return bossTileIdBase;
          if (r == 0 && c == 1) return bossTileIdBase;
          if (r == 0 && c == 2) return 0;
          if (r == 0 && c == 3) return 0;
          return 1;
        }),
      );
      game.bossHp
        ..clear()
        ..[bossTileIdBase] = 3;
      game.onGameResize(game.size);

      final cellSize = game.cellSize;
      final boardLeft = (game.size.x - game.cols * cellSize) / 2;
      final boardTop = (game.size.y - game.rows * cellSize) / 2;
      Vector2 centerOf(int row, int col) => Vector2(
        boardLeft + col * cellSize + cellSize / 2,
        boardTop + row * cellSize + cellSize / 2,
      );

      game.handleTap(centerOf(0, 3));
      await _pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(game.colorGrid[0][2], isNull); // nhóm màu 0 đã nổ
      expect(game.bossHp[bossTileIdBase], 2); // chip đúng 1 HP, chưa vỡ
      expect(game.colorGrid[0][0], bossTileIdBase); // boss vẫn còn nguyên khối
      expect(game.colorGrid[0][1], bossTileIdBase);

      Get.reset();
    },
  );

  testWidgets(
    'I29: HP về 0 → toàn bộ cell boss vỡ (thành null), xoá khỏi bossHp',
    (tester) async {
      final game = await _bootGame(tester);

      game.colorGrid = List.generate(
        game.rows,
        (r) => List.generate(game.cols, (c) {
          if (r == 0 && c == 0) return bossTileIdBase;
          if (r == 0 && c == 1) return bossTileIdBase;
          if (r == 0 && c == 2) return 0;
          if (r == 0 && c == 3) return 0;
          return 1;
        }),
      );
      game.bossHp
        ..clear()
        ..[bossTileIdBase] = 1; // 1 chip là vỡ ngay
      game.onGameResize(game.size);

      final cellSize = game.cellSize;
      final boardLeft = (game.size.x - game.cols * cellSize) / 2;
      final boardTop = (game.size.y - game.rows * cellSize) / 2;
      Vector2 centerOf(int row, int col) => Vector2(
        boardLeft + col * cellSize + cellSize / 2,
        boardTop + row * cellSize + cellSize / 2,
      );

      game.handleTap(centerOf(0, 3));
      await _pumpFrames(tester, frames: 40); // đủ cho pop + fall + collapse

      expect(tester.takeException(), isNull);
      expect(game.bossHp.containsKey(bossTileIdBase), isFalse);
      expect(
        game.colorGrid.expand((row) => row).contains(bossTileIdBase),
        isFalse,
      );

      Get.reset();
    },
  );

  testWidgets(
    'I29: nhóm chạm boss tile ở 2 cell khác nhau vẫn chỉ trừ đúng 1 HP/lần',
    (tester) async {
      final game = await _bootGame(tester);

      // Khối boss 2x2 tại (0,0)/(0,1)/(1,0)/(1,1). Nhóm màu 0 hình chữ L tại
      // (0,2)-(1,2)-(1,3) chạm boss ở CẢ 2 cạnh: (0,2)-(0,1) và (1,2)-(1,1).
      game.colorGrid = List.generate(
        game.rows,
        (r) => List.generate(game.cols, (c) {
          if (r < 2 && c < 2) return bossTileIdBase;
          if (r == 0 && c == 2) return 0;
          if (r == 1 && c == 2) return 0;
          if (r == 1 && c == 3) return 0;
          return 1;
        }),
      );
      game.bossHp
        ..clear()
        ..[bossTileIdBase] = 5;
      game.onGameResize(game.size);

      final cellSize = game.cellSize;
      final boardLeft = (game.size.x - game.cols * cellSize) / 2;
      final boardTop = (game.size.y - game.rows * cellSize) / 2;
      Vector2 centerOf(int row, int col) => Vector2(
        boardLeft + col * cellSize + cellSize / 2,
        boardTop + row * cellSize + cellSize / 2,
      );

      game.handleTap(centerOf(0, 2));
      await _pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(game.bossHp[bossTileIdBase], 4); // đúng 1 HP dù chạm 2 cạnh

      Get.reset();
    },
  );

  testWidgets(
    'I29: bàn kẹt hoàn toàn (chỉ còn boss tile) — decay giảm HP dần, KHÔNG '
    'kết thúc màn ngay (regression: chống softlock)',
    (tester) async {
      final game = await _bootGame(tester);

      // Toàn bộ bàn là 1 khối boss duy nhất → stuck ngay (không nhóm màu nào
      // để nổ, không power tile) nhưng vẫn còn HP > 0.
      game.colorGrid = List.generate(
        game.rows,
        (r) => List.generate(game.cols, (c) => bossTileIdBase),
      );
      game.bossHp
        ..clear()
        ..[bossTileIdBase] = 2;
      game.onGameResize(game.size);

      final gameCtrl = Get.find<GameController>();
      expect(gameCtrl.ended.value, isFalse);

      // shuffleBoard() gọi _checkEnd() đồng bộ ngay khi trả về — bug cũ sẽ
      // kết thúc màn "kẹt" ngay tại đây; bản đã fix phải decay thay vào đó.
      game.shuffleBoard();
      expect(tester.takeException(), isNull);
      expect(gameCtrl.ended.value, isFalse); // KHÔNG kết thúc màn ngay
      expect(game.bossHp[bossTileIdBase], 1); // đã decay đúng 1 HP

      // 1 chu kỳ pop+fall (_popDur 0.16s + _fallDur 0.26s ≈ 11 frame @40ms)
      // sau lệnh decay đầu để _checkEnd() tự gọi lại lần decay thứ 2 (HP 1→0,
      // vỡ hẳn) — pump 16 frame: đủ qua mốc vỡ (~11) nhưng CHƯA đủ để chu kỳ
      // clear/collapse của lần vỡ đó tự hoàn tất (cần ~11 frame kế tiếp,
      // hoàn tất ở mốc ~22) — tránh cuốn luôn qua bước _checkEnd() thứ 3.
      await _pumpFrames(tester, frames: 16);
      expect(gameCtrl.ended.value, isFalse); // vẫn chưa kết thúc
      expect(game.bossHp.containsKey(bossTileIdBase), isFalse); // đã vỡ hẳn

      // Bàn giờ trống hoàn toàn → chu kỳ clear/collapse của lần vỡ hoàn tất,
      // _checkEnd() thứ 3 mới thật sự kết thúc màn.
      await _pumpFrames(tester, frames: 20);
      expect(gameCtrl.ended.value, isTrue);

      Get.reset();
    },
  );

  testWidgets(
    'I29: undo() khôi phục đúng bossHp về snapshot trước lần chip gần nhất',
    (tester) async {
      final game = await _bootGame(tester);

      game.colorGrid = List.generate(
        game.rows,
        (r) => List.generate(game.cols, (c) {
          if (r == 0 && c == 0) return bossTileIdBase;
          if (r == 0 && c == 1) return bossTileIdBase;
          if (r == 0 && c == 2) return 0;
          if (r == 0 && c == 3) return 0;
          return 1;
        }),
      );
      game.bossHp
        ..clear()
        ..[bossTileIdBase] = 5;
      game.onGameResize(game.size);

      final cellSize = game.cellSize;
      final boardLeft = (game.size.x - game.cols * cellSize) / 2;
      final boardTop = (game.size.y - game.rows * cellSize) / 2;
      Vector2 centerOf(int row, int col) => Vector2(
        boardLeft + col * cellSize + cellSize / 2,
        boardTop + row * cellSize + cellSize / 2,
      );

      game.handleTap(centerOf(0, 3));
      await _pumpFrames(tester);
      expect(game.bossHp[bossTileIdBase], 4);

      final undone = game.undo();
      await _pumpFrames(tester);

      expect(undone, isTrue);
      expect(game.bossHp[bossTileIdBase], 5); // HP về đúng lúc snapshot
      expect(game.colorGrid[0][2], 0); // nhóm màu 0 cũng được khôi phục

      Get.reset();
    },
  );

  testWidgets(
    'I29 edge case: không có boss tile trên bàn — pop bình thường, không lỗi',
    (tester) async {
      final game = await _bootGame(tester);

      game.colorGrid = List.generate(
        game.rows,
        (r) => List.generate(game.cols, (c) {
          if (r == 0 && c == 0) return 0;
          if (r == 0 && c == 1) return 0;
          return 1;
        }),
      );
      // bossHp không set gì — mặc định rỗng (không boss tile nào ở màn này).
      game.onGameResize(game.size);

      final cellSize = game.cellSize;
      final boardLeft = (game.size.x - game.cols * cellSize) / 2;
      final boardTop = (game.size.y - game.rows * cellSize) / 2;
      Vector2 centerOf(int row, int col) => Vector2(
        boardLeft + col * cellSize + cellSize / 2,
        boardTop + row * cellSize + cellSize / 2,
      );

      game.handleTap(centerOf(0, 0));
      await _pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(game.colorGrid[0][0], isNull);
      expect(game.bossHp, isEmpty);

      Get.reset();
    },
  );

  testWidgets(
    'I29 edge case: id lạ (stale/giả mạo) trong bossHp không có cell nào trên '
    'bàn — không ảnh hưởng pop bình thường, không lỗi, entry lạ vẫn giữ '
    'nguyên (không tự bị chip nhầm)',
    (tester) async {
      final game = await _bootGame(tester);

      const fakeId = bossTileIdBase - 999; // id không tồn tại cell nào
      game.colorGrid = List.generate(
        game.rows,
        (r) => List.generate(game.cols, (c) {
          if (r == 0 && c == 0) return 0;
          if (r == 0 && c == 1) return 0;
          return 1;
        }),
      );
      game.bossHp
        ..clear()
        ..[fakeId] = 3; // race-condition/dữ liệu hỏng: id không có trên grid
      game.onGameResize(game.size);

      final cellSize = game.cellSize;
      final boardLeft = (game.size.x - game.cols * cellSize) / 2;
      final boardTop = (game.size.y - game.rows * cellSize) / 2;
      Vector2 centerOf(int row, int col) => Vector2(
        boardLeft + col * cellSize + cellSize / 2,
        boardTop + row * cellSize + cellSize / 2,
      );

      game.handleTap(centerOf(0, 0));
      await _pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(game.colorGrid[0][0], isNull); // pop vẫn hoạt động bình thường
      expect(game.bossHp[fakeId], 3); // entry lạ không bị đụng tới

      Get.reset();
    },
  );
}

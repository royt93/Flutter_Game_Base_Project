import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/levels.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// E4: các booster (bomb/shuffle/undo/rainbow/swap/freeze) chưa từng có test
/// riêng trước batch này. Dựng 1 `PopStarGame` thật qua `GameWidget` — theo
/// đúng pattern `cell_at_test.dart` — rồi gọi thẳng các trigger method để xác
/// nhận vài case tối thiểu, không cố enumerate mọi board layout.
Future<PopStarGame> _buildGame(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Get.put(StorageService(prefs), permanent: true);
  final gameCtrl = Get.put(GameController(), permanent: true);
  gameCtrl.currentLevelRx.value = kLevels[0];
  final game = PopStarGame(gameCtrl, seed: 1, isReplay: true);
  await tester.pumpWidget(GetMaterialApp(home: GameWidget(game: game)));
  await tester.pump(const Duration(milliseconds: 100));
  // A6: chờ hết animation intro-rơi-ô, nếu không booster trigger đầu tiên sẽ
  // bị `_animating` chặn và trả về false (theo đúng pattern swap_freeze_test).
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  return game;
}

void main() {
  setUp(Get.reset);

  group('triggerBomb', () {
    testWidgets('ô hợp lệ có tile xung quanh -> nổ, trả về true', (
      tester,
    ) async {
      final game = await _buildGame(tester);
      // Bàn mới luôn kín tile ở level 1 -> mọi ô hợp lệ đều có ít nhất chính
      // nó trong vùng 3x3.
      expect(game.triggerBomb(0, 0), isTrue);
    });

    testWidgets('toạ độ ngoài biên hẳn (không có ô nào trong vùng 3x3) '
        '-> không nổ, trả về false', (tester) async {
      final game = await _buildGame(tester);
      final farRow = game.rows + 10;
      final farCol = game.cols + 10;
      expect(game.triggerBomb(farRow, farCol), isFalse);
    });
  });

  group('shuffleBoard', () {
    testWidgets('giữ nguyên tổng số tile mỗi màu (không tạo/mất tile)', (
      tester,
    ) async {
      final game = await _buildGame(tester);
      final before = <int, int>{};
      for (final row in game.colorGrid) {
        for (final v in row) {
          if (v != null && v >= 0) before[v] = (before[v] ?? 0) + 1;
        }
      }

      expect(game.shuffleBoard(), isTrue);

      final after = <int, int>{};
      for (final row in game.colorGrid) {
        for (final v in row) {
          if (v != null && v >= 0) after[v] = (after[v] ?? 0) + 1;
        }
      }
      expect(after, before);
    });
  });

  group('undo', () {
    testWidgets('chưa có snapshot nào -> no-op an toàn, trả về false', (
      tester,
    ) async {
      final game = await _buildGame(tester);
      expect(game.undo(), isFalse);
    });

    testWidgets('sau 1 thao tác đổi bàn -> khôi phục đúng colorGrid gốc', (
      tester,
    ) async {
      final game = await _buildGame(tester);
      final before = game.colorGrid.map((r) => List<int?>.from(r)).toList();

      expect(game.shuffleBoard(), isTrue);
      // Chờ hết animation shuffle (_fallDur = 0.26s) — undo() tự chặn
      // (trả về false) khi đang animate.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(game.undo(), isTrue);

      expect(game.colorGrid, before);
    });
  });

  group('triggerRainbow', () {
    testWidgets('ô hợp lệ có màu thật -> xoá cả màu đó, trả về true', (
      tester,
    ) async {
      final game = await _buildGame(tester);
      expect(game.triggerRainbow(0, 0), isTrue);
    });
  });

  group('triggerSwap', () {
    testWidgets('2 ô hợp lệ khác màu -> đổi màu cho nhau, trả về true', (
      tester,
    ) async {
      final game = await _buildGame(tester);
      // Tìm 2 ô khác màu bất kỳ trên bàn mới (level 1 luôn có >=4 màu).
      final r1 = 0, c1 = 0;
      final firstColor = game.colorGrid[r1][c1];
      int? r2, c2;
      outer:
      for (var r = 0; r < game.rows; r++) {
        for (var c = 0; c < game.cols; c++) {
          if (game.colorGrid[r][c] != firstColor) {
            r2 = r;
            c2 = c;
            break outer;
          }
        }
      }
      expect(r2, isNotNull, reason: 'bàn mới phải có ít nhất 2 màu khác nhau');

      final color1 = game.colorGrid[r1][c1];
      final color2 = game.colorGrid[r2!][c2!];

      expect(game.triggerSwap(r1, c1, r2, c2), isTrue);

      expect(game.colorGrid[r1][c1], color2);
      expect(game.colorGrid[r2][c2], color1);
    });
  });

  group('applyFreeze', () {
    testWidgets('gán đúng số lượt freeze còn lại', (tester) async {
      final game = await _buildGame(tester);
      expect(game.freezeTurnsLeft, 0);
      game.applyFreeze(3);
      expect(game.freezeTurnsLeft, 3);
    });
  });
}

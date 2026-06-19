import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/game/neon_jewel_game.dart';
import 'package:neon_jewels/logic/settle.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 15 Phase 4 — 2 chế độ phụ: Sinh tồn (Survival) + Mê cung (Labyrinth).
/// Chứng minh: start đặt cờ + side-mode, checkEnd đúng, ISOLATION (không đụng
/// mạng/win-streak/level-unlock), engine mount được.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameController g;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
    g = Get.put(GameController());
  });
  tearDown(Get.reset);

  group('Wave 15 — Survival (đơn vị)', () {
    test('startSurvival: cờ + side-mode + không giới hạn lượt + không target thắng',
        () {
      // Wave 17.1: Triều dâng — objective score (không timeAttack), lượt khổng lồ.
      g.startSurvival();
      expect(g.isSurvival.value, isTrue);
      expect(g.isSideMode, isTrue);
      expect(g.movesLeft.value, greaterThan(1000)); // không giới hạn lượt (theo triều)
      expect(g.level.objective, ObjectiveType.score);
      expect(g.tideOverflow.value, isFalse); // chưa ngập
      expect(g.tideLevel.value, 0.0);
      expect(g.hasWon, isFalse); // target khổng lồ
    });

    test('NƯỚC CHẠM ĐỈNH → kết thúc, thưởng theo điểm, kỷ lục, ISOLATION', () {
      final wsBefore = g.winStreak.value;
      final unlockBefore = g.unlockedLevel.value;
      final livesBefore = g.lives.value;
      g.startSurvival();
      g.score.value = 4000;
      g.tideOverflow.value = true; // engine báo nước chạm đỉnh
      final r = g.checkEnd();
      expect(r, 'lose'); // không "win" — chỉ panel kết thúc
      expect(g.survivalHigh.value, 4000);
      expect(g.lastCoinReward, greaterThan(0)); // thưởng theo điểm
      // ISOLATION: không đụng win-streak / unlock / mạng.
      expect(g.winStreak.value, wsBefore);
      expect(g.unlockedLevel.value, unlockBefore);
      expect(g.lives.value, livesBefore);
    });

    test('chưa ngập → chưa kết thúc (null)', () {
      g.startSurvival();
      expect(g.tideOverflow.value, isFalse);
      expect(g.checkEnd(), isNull);
    });

    test('chuyển sang mode khác tắt cờ Survival', () {
      g.startSurvival();
      g.startLevel(1);
      expect(g.isSurvival.value, isFalse);
    });
  });

  group('Wave 15 — Labyrinth (đơn vị)', () {
    test('startLabyrinth: cờ + side-mode + dropDown + có layout mê cung', () {
      g.startLabyrinth();
      expect(g.isLabyrinth.value, isTrue);
      expect(g.isSideMode, isTrue);
      expect(g.level.objective, ObjectiveType.dropDown);
      expect(g.level.dropTarget, kLabyrinthTarget);
      expect(g.level.layout, isNotNull); // mê cung tường
    });

    test('đưa đủ tinh thể → win + thưởng; ISOLATION', () {
      final wsBefore = g.winStreak.value;
      final unlockBefore = g.unlockedLevel.value;
      g.startLabyrinth();
      g.dropped.value = kLabyrinthTarget; // đủ tinh thể
      final r = g.checkEnd();
      expect(r, 'win');
      expect(g.lastCoinReward, greaterThan(0));
      expect(g.winStreak.value, wsBefore); // không đụng win-streak
      expect(g.unlockedLevel.value, unlockBefore); // không unlock
    });

    test('hết lượt chưa đủ → lose', () {
      g.startLabyrinth();
      g.dropped.value = 0;
      g.movesLeft.value = 0;
      expect(g.checkEnd(), 'lose');
    });

    // WINNABILITY (chống tái lỗi maze bất khả thắng — audit Wave 15): mô phỏng
    // ĐÚNG luật engine (rơi thẳng + trượt chéo của settleBoardFlow) trong điều
    // kiện tốt nhất (người chơi dọn mọi gem dưới tinh thể). Mọi cột ĐẶT ĐƯỢC
    // (hàng 0 không tường) → tinh thể PHẢI tới hàng đáy.
    test('MÊ CUNG khả thi: tinh thể từ mọi cột đặt được tới đáy', () {
      final map = kLabyrinthMap;
      final rows = map.length, cols = map[0].length;
      bool wall(int r, int c) =>
          r >= 0 && r < rows && c >= 0 && c < cols && map[r][c] == '#';
      // descent best-case: trả về true nếu tinh thể từ cột c0 tới hàng đáy.
      bool reachesBottom(int c0) {
        var r = 0, c = c0, steps = 0;
        while (r < rows - 1 && steps++ < 500) {
          if (!wall(r + 1, c)) {
            r++;
            continue; // rơi thẳng (ô dưới đã dọn)
          }
          // trượt chéo: bên cạnh là tường + ô-đích là ô chơi (settle.dart luật).
          var moved = false;
          for (final dc in const [-1, 1]) {
            final nc = c + dc;
            if (nc >= 0 && nc < cols && wall(r, nc) && !wall(r + 1, nc)) {
              r++;
              c = nc;
              moved = true;
              break;
            }
          }
          if (!moved) return false; // KẸT → maze lỗi
        }
        return r == rows - 1;
      }

      for (int c = 0; c < cols; c++) {
        if (wall(0, c)) continue; // ô tường → không đặt tinh thể
        expect(reachesBottom(c), isTrue,
            reason: 'tinh thể cột $c KHÔNG tới đáy (maze bất khả thắng)');
      }
    });
  });

  group('Wave 15 — Labyrinth (engine mount)', () {
    test('bàn mê cung: ô tường trống, ô chơi có gem, tinh thể được đặt', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        g.startLabyrinth();
        final game = NeonJewelGame(
          controller: g,
          rows: 8,
          cols: 8,
          colorCount: 6,
          onGameEnd: (_) {},
          muteSfx: true,
          boardSeed: 3,
        );
        game.onGameResize(Vector2(560, 800));
        await game.onLoad();
        final layout = g.level.layout!;
        var walls = 0, ingredients = 0;
        for (int r = 0; r < 8; r++) {
          for (int c = 0; c < 8; c++) {
            if (layout[r][c] == CellKind.wall) {
              walls++;
              expect(game.grid[r][c], isNull); // tường trống
            } else {
              expect(game.grid[r][c], isNotNull); // ô chơi đầy
              if (game.grid[r][c]!.isIngredient) ingredients++;
            }
          }
        }
        expect(walls, greaterThan(0)); // có tường mê cung
        expect(ingredients, greaterThan(0)); // tinh thể được đặt ở hàng đầu
      });
    });
  });
}

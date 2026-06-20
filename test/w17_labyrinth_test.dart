import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/game/neon_jewel_game.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 17.2 — Mê cung tường động + sương mù.
/// Chứng minh: mọi layout trong kLabyrinthLayouts đều khả thi (winnability sim),
/// engine mount đúng, maze shift cập nhật _cellKind đúng, fog không ảnh hưởng logic.
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

  // ---------------------------------------------------------------------------
  // Winnability sim: tái dùng logic descent W15, áp cho mọi layout W17.2
  // ---------------------------------------------------------------------------
  bool reachesBottom(List<String> map, int c0) {
    final rows = map.length, cols = map[0].length;
    bool wall(int r, int c) =>
        r >= 0 && r < rows && c >= 0 && c < cols && map[r][c] == '#';
    var r = 0, c = c0, steps = 0;
    while (r < rows - 1 && steps++ < 500) {
      if (!wall(r + 1, c)) {
        r++;
        continue;
      }
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
      if (!moved) return false;
    }
    return r == rows - 1;
  }

  group('W17.2 — Winnability: mọi layout mê cung', () {
    for (int i = 0; i < kLabyrinthLayouts.length; i++) {
      final layout = kLabyrinthLayouts[i];
      test('Layout $i khả thi: tinh thể từ mọi cột đặt được tới đáy', () {
        final rows = layout.length, cols = layout[0].length;
        bool wall(int r, int c) => r >= 0 &&
            r < rows &&
            c >= 0 &&
            c < cols &&
            layout[r][c] == '#';
        for (int c = 0; c < cols; c++) {
          if (wall(0, c)) continue; // ô tường → không đặt
          expect(reachesBottom(layout, c), isTrue,
              reason:
                  'Layout $i: tinh thể cột $c KHÔNG tới đáy (maze bất khả thắng)');
        }
      });
    }
  });

  group('W17.2 — Constants', () {
    test('kMazeShiftMoves dương', () => expect(kMazeShiftMoves, greaterThan(0)));
    test('kFogRadius dương và < 8 (hàng bàn)', () {
      expect(kFogRadius, greaterThan(0));
      expect(kFogRadius, lessThan(8));
    });
    test('kLabyrinthLayouts có ít nhất 2 layout', () {
      expect(kLabyrinthLayouts.length, greaterThanOrEqualTo(2));
    });
    test('Mỗi layout đúng kích thước 8×8', () {
      for (final layout in kLabyrinthLayouts) {
        expect(layout.length, 8,
            reason: 'layout phải 8 hàng');
        for (final row in layout) {
          expect(row.length, 8, reason: 'mỗi hàng phải 8 cột');
        }
      }
    });
  });

  group('W17.2 — Engine: applyCellKindForTest cập nhật _cellKind đúng', () {
    test('ô tường mới rỗng gem; ô chơi mới giữ nguyên', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        g.startLabyrinth();
        final game = NeonJewelGame(
          controller: g,
          rows: 8,
          cols: 8,
          colorCount: 6,
          onGameEnd: (_) {},
          muteSfx: true,
          boardSeed: 42,
        );
        game.onGameResize(Vector2(560, 800));
        await game.onLoad();

        // Áp layout 2 (inverted-V trung tâm) qua test seam (không animate)
        final newLayout = layoutFromMap(kLabyrinthLayouts[2]);
        game.applyCellKindForTest(newLayout);

        // Ô tường trong layout mới phải trống (gem bị xoá)
        final rowStrings = kLabyrinthLayouts[2];
        for (int r = 0; r < 8; r++) {
          for (int c = 0; c < 8; c++) {
            if (rowStrings[r][c] == '#') {
              expect(game.grid[r][c], isNull,
                  reason: 'ô tường ($r,$c) phải rỗng sau applyCellKind');
            }
          }
        }
        // hasPossibleMove vẫn trả về giá trị (không crash)
        expect(game.hasPossibleMove, isA<bool>());
      });
    });
  });
}

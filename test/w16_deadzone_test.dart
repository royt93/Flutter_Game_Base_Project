import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/game/neon_jewel_game.dart';
import 'package:neon_jewels/logic/settle.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 16 Phase 2 — Dead-zone (jelly góc) + Bottleneck (waist tường).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
  });
  tearDown(Get.reset);

  group('Wave 16 — dead-zone (jelly góc)', () {
    test('JellyPattern.corner = 4 góc 2×2 = 16 ô, ĐÚNG ở góc', () {
      var n = 0;
      for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
          if (patternHas(JellyPattern.corner, r, c, 8, 8)) {
            n++;
            // mọi ô corner phải nằm ở 1 góc (r và c đều ở rìa 2 ô).
            expect((r < 2 || r >= 6) && (c < 2 || c >= 6), isTrue);
          }
        }
      }
      expect(n, 16);
    });

    test('màn dead-zone {111,129} = clearJelly + pattern corner', () {
      for (final idx in kDeadZoneLevels) {
        final lv = kLevels[idx - 1];
        expect(lv.objective, ObjectiveType.clearJelly, reason: 'màn $idx');
        expect(lv.jelly, JellyPattern.corner, reason: 'màn $idx');
      }
    });
  });

  group('Wave 16 — bottleneck (waist tường) winnability', () {
    // mount engine màn bottleneck → board fill ĐẦY ô chơi (refill qua source dưới
    // tường, không pocket kẹt) + tường trống + CÓ nước đi (winnable) — nhiều seed.
    Future<void> checkFill(int levelIndex, int seed) async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final g = Get.put(GameController());
        g.currentLevel.value = levelIndex;
        final layout = g.level.layout;
        expect(layout, isNotNull, reason: 'màn $levelIndex phải có bottleneck');
        final game = NeonJewelGame(
          controller: g,
          rows: 8,
          cols: 8,
          colorCount: 6,
          onGameEnd: (_) {},
          muteSfx: true,
          boardSeed: seed,
        );
        game.onGameResize(Vector2(560, 800));
        await game.onLoad();
        for (int r = 0; r < 8; r++) {
          for (int c = 0; c < 8; c++) {
            if (layout![r][c] == CellKind.wall) {
              expect(game.grid[r][c], isNull,
                  reason: 'L$levelIndex seed$seed tường ($r,$c) trống');
            } else {
              expect(game.grid[r][c], isNotNull,
                  reason:
                      'L$levelIndex seed$seed ô chơi ($r,$c) phải đầy (không kẹt)');
            }
          }
        }
        // winnable: onLoad shuffle khi bí (single-shot _doShuffle) → phải có nước đi.
        expect(game.hasPossibleMove, isTrue,
            reason: 'L$levelIndex seed$seed phải có nước đi (winnable)');
        Get.delete<GameController>();
      });
    }

    // nhiều seed → không phụ thuộc 1 bố cục ngẫu nhiên may mắn.
    for (final seed in [3, 11, 27, 42]) {
      test('màn 109 bottleneck: fill đầy + có nước đi (seed $seed)', () async {
        await checkFill(109, seed);
      });
      test('màn 121 bottleneck: fill đầy + có nước đi (seed $seed)', () async {
        await checkFill(121, seed);
      });
      test('màn 133 bottleneck: fill đầy + có nước đi (seed $seed)', () async {
        await checkFill(133, seed);
      });
    }
  });
}

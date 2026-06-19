import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/game/neon_jewel_game.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 15 Phase 3 — Gem nhốt (cage): màn weave đúng + engine seed lồng THƯA
/// (không ô nào kề ô nhốt khác) + obstacleTotal = số lớp.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
  });
  tearDown(Get.reset);

  group('Wave 15 — cage (levels)', () {
    test('màn kCageLevels = clearObstacle + cage + pattern center', () {
      for (final idx in kCageLevels) {
        final lv = kLevels[idx - 1];
        expect(lv.objective, ObjectiveType.clearObstacle, reason: 'màn $idx');
        expect(lv.obstacle, ObstacleType.cage, reason: 'màn $idx');
        expect(lv.obstaclePattern, JellyPattern.center, reason: 'màn $idx');
      }
    });

    test('cage không trùng licorice/jam', () {
      expect(kCageLevels.intersection(kLicoriceLevels), isEmpty);
      expect(kCageLevels.intersection(kJamLevels), isEmpty);
    });
  });

  group('Wave 15 — cage (engine seed)', () {
    test('lồng THƯA (không 2 ô nhốt kề nhau) + obstacleTotal = số lớp', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final cageLevel = kCageLevels.first;
        final g = Get.put(GameController());
        g.currentLevel.value = cageLevel;
        final game = NeonJewelGame(
          controller: g,
          rows: 8,
          cols: 8,
          colorCount: 6,
          onGameEnd: (_) {},
          muteSfx: true,
          boardSeed: 7,
        );
        game.onGameResize(Vector2(560, 800));
        await game.onLoad();

        var cages = 0, total = 0;
        for (int r = 0; r < 8; r++) {
          for (int c = 0; c < 8; c++) {
            final lay = game.obstacle[r][c];
            if (lay > 0) {
              cages++;
              total += lay;
              expect(lay, kCageLayers, reason: 'ô nhốt ($r,$c) phải 2 lớp');
              // gem nhốt vẫn TỒN TẠI (matchable, không phải ô trống/tường)
              expect(game.grid[r][c], isNotNull);
              // THƯA: không ô nhốt nào kề ngang/dọc
              for (final nb in const [
                [-1, 0],
                [1, 0],
                [0, -1],
                [0, 1]
              ]) {
                final nr = r + nb[0], nc = c + nb[1];
                if (nr < 0 || nr >= 8 || nc < 0 || nc >= 8) continue;
                expect(game.obstacle[nr][nc], 0,
                    reason: 'ô nhốt ($r,$c) kề ($nr,$nc) — phải thưa');
              }
            }
          }
        }
        expect(cages, greaterThan(0));
        expect(g.obstacleTotal.value, total);
        expect(total, cages * kCageLayers);
      });
    });
  });
}

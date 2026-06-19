import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/game/neon_jewel_game.dart';
import 'package:neon_jewels/logic/settle.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 15 Phase 0 — chứng minh engine MOUNT được bàn CÓ BỐ CỤC (tường/lỗ):
/// ô tường KHÔNG chứa gem, ô chơi đều có gem, vẫn tìm được nước đi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
  });
  tearDown(Get.reset);

  // Bố cục "hình thoi" 8×8: 4 góc là tường (#).
  final diamond = layoutFromMap([
    '##....##',
    '#......#',
    '........',
    '........',
    '........',
    '........',
    '#......#',
    '##....##',
  ]);

  NeonJewelGame buildGame(List<List<CellKind>>? layout) {
    final g = Get.put(GameController());
    g.currentLevel.value = 1; // màn score thường (objective không liên quan layout)
    return NeonJewelGame(
      controller: g,
      rows: 8,
      cols: 8,
      colorCount: 6,
      onGameEnd: (_) {},
      muteSfx: true,
      boardSeed: 42,
      layoutOverride: layout,
    );
  }

  test('ô tường KHÔNG chứa gem; ô chơi đều có gem', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final game = buildGame(diamond);
      game.onGameResize(Vector2(560, 800));
      await game.onLoad();

      var walls = 0, plays = 0;
      for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
          if (diamond[r][c] == CellKind.wall) {
            walls++;
            expect(game.grid[r][c], isNull, reason: 'ô tường ($r,$c) phải trống');
          } else {
            plays++;
            expect(game.grid[r][c], isNotNull,
                reason: 'ô chơi ($r,$c) phải có gem');
          }
        }
      }
      expect(walls, 8); // 4 góc × 2 ô
      expect(plays, 56);
    });
  });

  test('bàn không layout (null) vẫn fill đầy như cũ (không hồi quy)', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final game = buildGame(null);
      game.onGameResize(Vector2(560, 800));
      await game.onLoad();
      var filled = 0;
      for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
          if (game.grid[r][c] != null) filled++;
        }
      }
      expect(filled, 64); // bàn đặc đầy đủ
    });
  });
}

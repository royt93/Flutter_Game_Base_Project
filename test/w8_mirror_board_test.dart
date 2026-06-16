import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/game/neon_jewel_game.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chứng minh DỨT KHOÁT: 2 bàn versus cùng `boardSeed` → grid mở đầu Y HỆT
/// (mirror, công bằng). Mount thật engine rồi so sánh từng ô.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
  });
  tearDown(Get.reset);

  NeonJewelGame build(int seed, String tag) {
    final g = Get.put(GameController(versus: true), tag: tag);
    final cfg = buildVersusLevel();
    return NeonJewelGame(
      controller: g,
      rows: cfg.rows,
      cols: cfg.cols,
      colorCount: cfg.colorCount,
      onGameEnd: (_) {},
      muteSfx: true,
      boardSeed: seed,
    );
  }

  Future<List<List<int>>> loadGrid(NeonJewelGame game) async {
    game.onGameResize(Vector2(560, 560));
    await game.onLoad();
    return List.generate(
      game.rows,
      (r) => List.generate(game.cols, (c) => game.grid[r][c]!.color.index),
    );
  }

  test('cùng seed → 2 grid mở đầu y hệt', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final a = await loadGrid(build(777, 'a'));
      final b = await loadGrid(build(777, 'b'));
      expect(b, equals(a));
    });
  });

  test('khác seed → 2 grid khác nhau', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final a = await loadGrid(build(111, 'a'));
      final b = await loadGrid(build(222, 'b'));
      expect(b, isNot(equals(a)));
    });
  });
}

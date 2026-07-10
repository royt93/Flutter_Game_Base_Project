import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/puzzles.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/puzzle_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 28.1 — Puzzle Hard Variant: mở ở Cấu đố 8 khi đạt 3 sao, giảm lượt
/// theo kHardVariantMovesMul (tái dùng hằng số của W25.1). KHÔNG persist.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameController g;
  late PuzzleController pc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
    g = Get.put(GameController());
    pc = Get.put(PuzzleController(g));
  });
  tearDown(Get.reset);

  group('W28.1 — hardVariantUnlocked', () {
    test('chưa đủ 3 sao ở Cấu đố 8 → khoá', () {
      expect(pc.hardVariantUnlocked, isFalse);
    });

    test('đạt 3 sao ở Cấu đố 8 → mở', () {
      pc.stars[kPuzzles.length] = 3;
      expect(pc.hardVariantUnlocked, isTrue);
    });

    test('2 sao ở Cấu đố 8 → vẫn khoá', () {
      pc.stars[kPuzzles.length] = 2;
      expect(pc.hardVariantUnlocked, isFalse);
    });
  });

  group('W28.1 — startPuzzle(hard:)', () {
    final def = kPuzzles.last;

    test('hard=false → lượt bình thường', () {
      g.startPuzzle(def);
      expect(g.movesLeft.value, def.maxMoves);
    });

    test('hard=true → lượt giảm theo kHardVariantMovesMul (-15%)', () {
      g.startPuzzle(def, hard: true);
      expect(g.movesLeft.value, (def.maxMoves * 0.85).ceil());
      expect(g.movesLeft.value, lessThan(def.maxMoves));
    });
  });
}

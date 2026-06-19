import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/game/neon_jewel_game.dart';
import 'package:neon_jewels/logic/gem_data.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 16 Phase 3 — DDA / Pity System (trợ giúp động khi thua liên tiếp).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameController g;
  late StorageService store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    store = Get.put(StorageService(await SharedPreferences.getInstance()));
    g = Get.put(GameController());
  });
  tearDown(Get.reset);

  // màn score (index 7 = (7-1)%6=0 → score).
  group('Wave 16 — Pity (đơn vị)', () {
    test('THUA màn thường → pity fail màn đó +1; THẮNG → reset 0', () {
      g.startLevel(7);
      g.movesLeft.value = 0; // hết lượt → lose
      expect(g.checkEnd(), 'lose');
      expect(store.getInt(StorageKeys.pityFails(7)), 1);

      // thua lần 2
      g.startLevel(7);
      expect(g.pity.value, 1); // đọc fail lần trước
      g.movesLeft.value = 0;
      expect(g.checkEnd(), 'lose');
      expect(store.getInt(StorageKeys.pityFails(7)), 2);

      // thắng → reset
      g.startLevel(7);
      g.score.value = g.targetScore.value; // đạt mục tiêu
      g.movesLeft.value = 5;
      expect(g.checkEnd(), 'win');
      expect(store.getInt(StorageKeys.pityFails(7)), 0);
    });

    test('pityFails CLAMP ở kPityMovesFails (chống farm cố-thua quá ngưỡng)', () {
      // thua nhiều hơn ngưỡng → storage không phình quá kPityMovesFails.
      for (var i = 0; i < GameController.kPityMovesFails + 3; i++) {
        g.startLevel(7);
        g.movesLeft.value = 0;
        expect(g.checkEnd(), 'lose');
      }
      expect(store.getInt(StorageKeys.pityFails(7)),
          GameController.kPityMovesFails);
    });

    test('thua ≥kPityMovesFails → +lượt khởi đầu ẩn', () {
      store.setInt(StorageKeys.pityFails(10), GameController.kPityMovesFails);
      g.startLevel(10);
      expect(g.pity.value, GameController.kPityMovesFails);
      expect(g.movesLeft.value, kLevels[9].moves + GameController.kPityMovesBonus);
    });

    test('side-mode KHÔNG dính pity (pity=0)', () {
      store.setInt(StorageKeys.pityFails(1), 5); // rác
      g.startSurvival();
      expect(g.pity.value, 0); // side-mode không đọc pity theo màn
      expect(g.isSideMode, isTrue);
    });

    test('REGRESSION: chơi màn thường thua nhiều → vào side-mode KHÔNG rò pity', () {
      // tái hiện leak cũ: startLevel set pity từ storage, _enterMode trước đây KHÔNG
      // reset → vào Survival vẫn giữ pity cao → _luckyRate/_refillColor bị bơm sai.
      store.setInt(StorageKeys.pityFails(7), GameController.kPityMovesFails);
      g.startLevel(7);
      expect(g.pity.value, GameController.kPityMovesFails); // màn thường có pity
      g.startSurvival();
      expect(g.pity.value, 0, reason: 'vào side-mode phải reset pity (không rò)');
      g.startEndless();
      expect(g.pity.value, 0, reason: 'mọi side-mode khác cũng phải reset');
    });
  });

  group('Wave 16 — Pity (engine seed special)', () {
    Future<int> specialsAtLoad(int pityFails) async {
      var count = 0;
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        store.setInt(StorageKeys.pityFails(7), pityFails);
        g.startLevel(7);
        final game = NeonJewelGame(
          controller: g,
          rows: 8,
          cols: 8,
          colorCount: 6,
          onGameEnd: (_) {},
          muteSfx: true,
          boardSeed: 5,
        );
        game.onGameResize(Vector2(560, 800));
        await game.onLoad();
        for (int r = 0; r < 8; r++) {
          for (int c = 0; c < 8; c++) {
            if (game.grid[r][c]?.type != GemType.normal &&
                game.grid[r][c] != null) {
              count++;
            }
          }
        }
      });
      return count;
    }

    test('pity < kPitySpecialFails → 0 special lúc mở màn', () async {
      expect(await specialsAtLoad(0), 0);
    });
    test('pity ≥ kPitySpecialFails → có ≥1 special (giúp ẩn)', () async {
      expect(await specialsAtLoad(GameController.kPitySpecialFails),
          greaterThanOrEqualTo(1));
    });
  });
}

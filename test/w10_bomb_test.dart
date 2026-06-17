import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/game/neon_jewel_game.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
    c = Get.put(GameController());
  });
  tearDown(Get.reset);

  int countBombs(NeonJewelGame g) {
    var n = 0;
    for (final row in g.bomb) {
      for (final v in row) {
        if (v > 0) n++;
      }
    }
    return n;
  }

  group('Wave 10 — Bom đếm ngược: cấu hình màn', () {
    test('kBombLevels đều là score + cộng thêm lượt', () {
      for (final idx in kBombLevels) {
        final lv = kLevels[idx - 1];
        expect(lv.objective, ObjectiveType.score, reason: 'level $idx');
      }
      expect(kBombCount, greaterThan(0));
      expect(kBombCountdown, greaterThan(3)); // đủ rộng để công bằng
    });

    test('kBombLevels không trùng order/spread', () {
      expect(kBombLevels.intersection(kOrderLevels), isEmpty);
      expect(kBombLevels.intersection(kSpreadLevels), isEmpty);
    });
  });

  group('Wave 10 — Bom: controller (thua khi nổ + reset)', () {
    test('bombExploded=true → checkEnd trả lose + reset win-streak', () {
      c.startLevel(kBombLevels.first);
      c.winStreak.value = 3;
      c.bombExploded.value = true;
      expect(c.checkEnd(), 'lose');
      expect(c.winStreak.value, 0);
      expect(c.lastStars, 0);
    });

    test('startLevel reset cờ bom + đếm', () {
      c.bombExploded.value = true;
      c.bombsLeft.value = 5;
      c.bombMinTimer.value = 2;
      c.startLevel(1);
      expect(c.bombExploded.value, isFalse);
      expect(c.bombsLeft.value, 0);
      expect(c.bombMinTimer.value, 0);
    });

    test('thắng được ƯU TIÊN dù bom cũng vừa nổ cùng lượt', () {
      final idx = kBombLevels.first;
      c.startLevel(idx);
      c.score.value = c.targetScore.value; // đạt mục tiêu
      c.bombExploded.value = true; // nhưng bom cũng nổ
      expect(c.checkEnd(), 'win'); // hasWon kiểm trước → thắng
    });
  });

  group('Wave 10 — Bom: engine seed (mount thật)', () {
    test('màn bomb → seed đúng kBombCount quả, HUD đồng bộ', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        c.startLevel(kBombLevels.first);
        final lv = c.level;
        final g = NeonJewelGame(
          controller: c,
          rows: lv.rows,
          cols: lv.cols,
          colorCount: lv.colorCount,
          onGameEnd: (_) {},
          muteSfx: true,
        );
        g.onGameResize(Vector2(560, 560));
        await g.onLoad();
        expect(countBombs(g), kBombCount);
        expect(c.bombsLeft.value, kBombCount);
        expect(c.bombMinTimer.value, kBombCountdown);
      });
    });

    test('màn thường (không bomb) → không có bom nào', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        c.startLevel(1); // level 1 không thuộc kBombLevels
        final lv = c.level;
        final g = NeonJewelGame(
          controller: c,
          rows: lv.rows,
          cols: lv.cols,
          colorCount: lv.colorCount,
          onGameEnd: (_) {},
          muteSfx: true,
        );
        g.onGameResize(Vector2(560, 560));
        await g.onLoad();
        expect(countBombs(g), 0);
        expect(c.bombsLeft.value, 0);
      });
    });
  });
}

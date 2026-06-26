import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 23.2 — mini-boss: cờ isMiniBoss + thưởng "đã hạ" 1 lần (anti-farm) + reset.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController g;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs));
    g = Get.put(GameController());
  });
  tearDown(Get.reset);

  group('isMiniBoss flag', () {
    test('boss thường (không miniBossWorld) → isMiniBoss false', () {
      g.startBoss(1);
      expect(g.isMiniBoss, isFalse);
      expect(g.miniBossWorld, 0);
    });
    test('startBoss với miniBossWorld → isMiniBoss true', () {
      g.startBoss(1, hpScale: 0.5, miniBossWorld: 2);
      expect(g.isMiniBoss, isTrue);
      expect(g.miniBossWorld, 2);
    });
    test('vào mode khác (startLevel) → reset isMiniBoss', () {
      g.startBoss(1, hpScale: 0.5, miniBossWorld: 2);
      g.startLevel(1);
      expect(g.isMiniBoss, isFalse);
    });
  });

  group('grantMiniBossClear — thưởng 1 lần (anti-farm)', () {
    test('lần đầu → bonus>0 + cộng xu + cleared; lần 2 → 0, xu không đổi', () {
      const w = 2;
      expect(g.isMiniBossCleared(w), isFalse);
      final before = g.coins.value;
      final bonus = g.grantMiniBossClear(w);
      expect(bonus, greaterThan(0));
      expect(g.coins.value, before + bonus);
      expect(g.isMiniBossCleared(w), isTrue);

      final coins2 = g.coins.value;
      expect(g.grantMiniBossClear(w), 0); // đã hạ → không thưởng lại
      expect(g.coins.value, coins2);
    });

    test('world<=0 (boss thường) → 0, không cleared', () {
      final before = g.coins.value;
      expect(g.grantMiniBossClear(0), 0);
      expect(g.coins.value, before);
    });
  });

  test('resetProgress xoá miniBossCleared → hạ lại được thưởng lại', () async {
    const w = 4;
    g.grantMiniBossClear(w);
    expect(g.isMiniBossCleared(w), isTrue);
    await g.resetProgress();
    expect(g.isMiniBossCleared(w), isFalse);
  });
}

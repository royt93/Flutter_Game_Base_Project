import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/logic/boss_attack.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 25.1 — chiều sâu boss: 2 loại (profile đòn khác) + vùng meteor (pure).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bossAttackPatternFor theo LOẠI boss (pure)', () {
    test('pulse: 0→block · 1→shuffle · 2→meteor', () {
      expect(bossAttackPatternFor(0, BossType.pulse), BossAttack.block);
      expect(bossAttackPatternFor(1, BossType.pulse), BossAttack.shuffle);
      expect(bossAttackPatternFor(2, BossType.pulse), BossAttack.meteor);
    });
    test('voidType: 0→shuffle · 1→shuffle · 2→meteor (meteor chỉ phase 2)', () {
      expect(bossAttackPatternFor(0, BossType.voidType), BossAttack.shuffle);
      expect(bossAttackPatternFor(1, BossType.voidType), BossAttack.shuffle);
      expect(bossAttackPatternFor(2, BossType.voidType), BossAttack.meteor);
    });
    test('default là pulse (giữ tương thích W23)', () {
      expect(bossAttackPatternFor(0), BossAttack.block);
      expect(bossAttackPatternFor(2), BossAttack.meteor);
    });
  });

  group('pickMeteorRegion (pure)', () {
    test('bàn đặc: vùng ⊆ ô target, 1..9 ô, mọi ô đều target', () {
      final rnd = Random(1);
      for (var i = 0; i < 30; i++) {
        final region = pickMeteorRegion(6, 6, (r, c) => true, rnd);
        expect(region.length, inInclusiveRange(1, 9));
        for (final (r, c) in region) {
          expect(r, inInclusiveRange(0, 5));
          expect(c, inInclusiveRange(0, 5));
        }
      }
    });

    test('không chọn ô wall: hàng 0 = wall → vùng không chạm hàng 0', () {
      final rnd = Random(7);
      for (var i = 0; i < 30; i++) {
        final region = pickMeteorRegion(5, 5, (r, c) => r != 0, rnd);
        expect(region, isNotEmpty);
        for (final (r, _) in region) {
          expect(r, greaterThanOrEqualTo(1));
        }
      }
    });

    test('không có ô hợp lệ → rỗng', () {
      expect(pickMeteorRegion(4, 4, (r, c) => false, Random(0)), isEmpty);
    });

    test('duy nhất 1 ô target → vùng = đúng ô đó', () {
      final region = pickMeteorRegion(
        5,
        5,
        (r, c) => r == 2 && c == 2,
        Random(0),
      );
      expect(region, [(2, 2)]);
    });
  });

  group('GameController.bossType theo stage', () {
    late GameController g;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs));
      g = Get.put(GameController());
    });
    tearDown(Get.reset);

    test('stage lẻ → pulse; đòn/tên theo pulse', () {
      g.startBoss(1);
      expect(g.bossType.value, BossType.pulse);
      expect(g.bossAttackPattern, BossAttack.block); // HP đầy → phase 0
      expect(g.bossTypeNameKey, 'boss_type_pulse');
    });

    test('stage chẵn → voidType; phase 0/1 = shuffle, phase 2 = meteor', () {
      g.startBoss(2);
      expect(g.bossType.value, BossType.voidType);
      expect(g.bossAttackPattern, BossAttack.shuffle); // void phase 0
      expect(g.bossTypeNameKey, 'boss_type_void');
      // phase 1 (≈50% HP) vẫn shuffle (meteor CHỈ phase 2 — không spike sớm)
      g.bossHp.value = (g.bossMaxHp.value * 0.5).round();
      expect(g.bossAttackPattern, BossAttack.shuffle);
      // phase 2 (≈20% HP) → meteor
      g.bossHp.value = (g.bossMaxHp.value * 0.2).round();
      expect(g.bossAttackPattern, BossAttack.meteor);
    });
  });
}

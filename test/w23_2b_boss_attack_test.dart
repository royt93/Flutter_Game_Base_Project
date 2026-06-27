import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/logic/boss_attack.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 23.2B — selector kiểu đòn boss theo phase (logic thuần + getter).
/// (Hiệu ứng engine shuffle/meteor wire khi verify device — xem w23-2 plan.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bossAttackPatternFor (pure)', () {
    test('leo thang: 0→block, 1→shuffle, 2→meteor', () {
      expect(bossAttackPatternFor(0), BossAttack.block);
      expect(bossAttackPatternFor(1), BossAttack.shuffle);
      expect(bossAttackPatternFor(2), BossAttack.meteor);
    });
    test('phase ngoài dải cao → vẫn meteor', () {
      expect(bossAttackPatternFor(5), BossAttack.meteor);
    });
  });

  group('GameController.bossAttackPattern theo HP', () {
    late GameController g;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs));
      g = Get.put(GameController());
    });
    tearDown(Get.reset);

    test('HP đầy → block; HP ~50% → shuffle; HP thấp → meteor', () {
      g.startBoss(1);
      expect(g.bossPhase, 0);
      expect(g.bossAttackPattern, BossAttack.block);
      // ~50% HP → phase 1 → shuffle
      g.bossHp.value = (g.bossMaxHp.value * 0.5).round();
      expect(g.bossPhase, 1);
      expect(g.bossAttackPattern, BossAttack.shuffle);
      // <=32% → phase 2 → meteor
      g.bossHp.value = (g.bossMaxHp.value * 0.2).round();
      expect(g.bossPhase, 2);
      expect(g.bossAttackPattern, BossAttack.meteor);
    });

    test('biên ngưỡng 65% (≤ → phase 1; vừa trên → phase 0)', () {
      g.startBoss(1);
      final max = g.bossMaxHp.value;
      // đúng ngưỡng 65% → phase 1 (so sánh <=)
      g.bossHp.value = (max * GameController.kBossPhase2Threshold).round();
      expect(g.bossPhase, 1);
      // vừa trên 65% → vẫn phase 0
      g.bossHp.value = (max * GameController.kBossPhase2Threshold).round() + 1;
      expect(g.bossPhase, 0);
    });

    test('biên ngưỡng 32% (≤ → phase 2; vừa trên → phase 1)', () {
      g.startBoss(1);
      final max = g.bossMaxHp.value;
      // đúng ngưỡng 32% → phase 2
      g.bossHp.value = (max * GameController.kBossPhase3Threshold).round();
      expect(g.bossPhase, 2);
      // vừa trên 32% → phase 1
      g.bossHp.value = (max * GameController.kBossPhase3Threshold).round() + 1;
      expect(g.bossPhase, 1);
    });

    test('HP 0 → phase 2 (boss gục, vẫn meteor)', () {
      g.startBoss(1);
      g.bossHp.value = 0;
      expect(g.bossPhase, 2);
      expect(g.bossAttackPattern, BossAttack.meteor);
    });

    test('guard maxHp==0 (ngoài boss) → phase 0, không chia cho 0', () {
      // không gọi startBoss → bossMaxHp mặc định 0
      expect(g.bossMaxHp.value, 0);
      expect(g.bossPhase, 0);
      expect(g.bossAttackPattern, BossAttack.block);
    });

    test('bossAttackLabelKey ánh xạ đúng theo phase', () {
      g.startBoss(1);
      expect(g.bossAttackLabelKey, 'boss_atk_block');
      g.bossHp.value = (g.bossMaxHp.value * 0.5).round();
      expect(g.bossAttackLabelKey, 'boss_atk_shuffle');
      g.bossHp.value = (g.bossMaxHp.value * 0.2).round();
      expect(g.bossAttackLabelKey, 'boss_atk_meteor');
    });

    test('mini-boss hpScale<1 → maxHp THẤP hơn boss thường cùng stage', () {
      g.startBoss(3);
      final normalHp = g.bossMaxHp.value;
      g.startBoss(3, hpScale: 0.5, miniBossWorld: 4);
      expect(g.bossMaxHp.value, lessThan(normalHp));
      expect(g.bossHp.value, g.bossMaxHp.value); // khởi tạo đầy máu
    });
  });
}

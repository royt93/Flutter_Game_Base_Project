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
  });
}

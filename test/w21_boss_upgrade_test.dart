import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late GameController g;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
    g = Get.put(GameController());
  });

  tearDown(() => Get.reset());

  // ─── bossPhase getter ─────────────────────────────────────────────────────

  group('Boss — bossPhase getter', () {
    setUp(() => g.startBoss(1));

    test('HP 100% → phase 0', () {
      g.bossHp.value = g.bossMaxHp.value;
      expect(g.bossPhase, 0);
    });

    test('HP 66% → phase 0 (trên ngưỡng P2)', () {
      g.bossHp.value = (g.bossMaxHp.value * 0.66).round();
      expect(g.bossPhase, 0);
    });

    test('HP 64% → phase 1 (dưới kBossPhase2Threshold=0.65)', () {
      g.bossHp.value = (g.bossMaxHp.value * 0.64).round();
      expect(g.bossPhase, 1);
    });

    test('HP 33% → phase 1 (trên kBossPhase3Threshold=0.32)', () {
      g.bossHp.value = (g.bossMaxHp.value * 0.33).round();
      expect(g.bossPhase, 1);
    });

    test('HP 31% → phase 2 (dưới kBossPhase3Threshold)', () {
      g.bossHp.value = (g.bossMaxHp.value * 0.31).round();
      expect(g.bossPhase, 2);
    });

    test('HP 0 → phase 2', () {
      g.bossHp.value = 0;
      expect(g.bossPhase, 2);
    });

    test('bossMaxHp = 0 → phase 0 (guard chia 0)', () {
      g.bossMaxHp.value = 0;
      expect(g.bossPhase, 0);
    });
  });

  // ─── kBossAttackInterval per phase ───────────────────────────────────────

  group('Boss — attack interval theo phase', () {
    setUp(() => g.startBoss(1));

    test('constants đúng thứ tự [4,3,2]', () {
      expect(GameController.kBossAttackInterval[0], 4);
      expect(GameController.kBossAttackInterval[1], 3);
      expect(GameController.kBossAttackInterval[2], 2);
    });

    test('constants damage đúng thứ tự [1,2,3]', () {
      expect(GameController.kBossAttackDamage[0], 1);
      expect(GameController.kBossAttackDamage[1], 2);
      expect(GameController.kBossAttackDamage[2], 3);
    });

    test('Phase 0: phản đòn sau 4 lượt, trừ 1 move', () {
      g.bossHp.value = g.bossMaxHp.value; // phase 0
      final before = g.movesLeft.value;
      // 3 lượt chưa trigger
      g.useMove();
      g.useMove();
      g.useMove();
      expect(g.movesLeft.value, before - 3);
      // lượt 4 → trigger retaliation (trừ thêm 1)
      g.useMove();
      expect(g.movesLeft.value, before - 4 - 1); // 4 normal + 1 boss
    });

    test('Phase 1: phản đòn sau 3 lượt, trừ 2 moves', () {
      g.bossHp.value = (g.bossMaxHp.value * 0.50).round(); // phase 1
      final before = g.movesLeft.value;
      g.useMove();
      g.useMove();
      // lượt 3 → trigger (trừ thêm 2)
      g.useMove();
      expect(g.movesLeft.value, before - 3 - 2);
    });

    test('Phase 2: phản đòn sau 2 lượt, trừ 3 moves', () {
      g.bossHp.value = (g.bossMaxHp.value * 0.20).round(); // phase 2
      final before = g.movesLeft.value;
      g.useMove();
      // lượt 2 → trigger (trừ thêm 3)
      g.useMove();
      expect(g.movesLeft.value, before - 2 - 3);
    });

    test('bossAttackSignal tăng khi boss phản đòn', () {
      g.bossHp.value = g.bossMaxHp.value; // phase 0
      final before = g.bossAttackSignal.value;
      // 4 lượt → trigger
      for (var i = 0; i < 4; i++) {
        g.useMove();
      }
      expect(g.bossAttackSignal.value, before + 1);
    });

    test('movesLeft không xuống âm', () {
      g.bossHp.value = (g.bossMaxHp.value * 0.20).round(); // phase 2
      g.movesLeft.value = 1;
      g.useMove(); // lượt 1
      g.useMove(); // lượt 2 → trigger damage 3, nhưng movesLeft clamp 0
      expect(g.movesLeft.value, 0);
    });
  });

  // ─── isolation ────────────────────────────────────────────────────────────

  group('Boss — isolation', () {
    test('isSideMode = true (không tốn mạng)', () {
      g.startBoss(1);
      expect(g.isSideMode, isTrue);
    });

    test('campaign mode: useMove không trigger boss retaliation', () {
      g.startLevel(1);
      final before = g.movesLeft.value;
      // 10 lượt liên tục — không trigger boss attack
      for (var i = 0; i < 10; i++) {
        if (g.movesLeft.value > 0) g.useMove();
      }
      // chỉ trừ đúng số lượt đã dùng, không có bonus boss damage
      expect(g.movesLeft.value, greaterThanOrEqualTo(before - 10));
    });
  });
}

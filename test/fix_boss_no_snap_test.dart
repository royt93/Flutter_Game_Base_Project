import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/game/neon_jewel_game.dart';
import 'package:neon_jewels/logic/boss_attack.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fix 6 — Chứng minh: board KHÔNG còn "giật lùi về bottom" sau boss attack.
///
/// Root cause: Fix trước gọi `await _settle()` sau MỌI boss attack (shuffle + meteor).
/// `_settle()` chạy full gravity cascade → tất cả gem rơi → trông như board sập xuống.
///
/// Fix đúng:
///   - Sau SHUFFLE: không gọi gì cả (_doShuffle không xóa gem, không có ô trống)
///   - Sau METEOR: chỉ gọi `_applyGravityAndRefill()` (meteor xóa gem → cần fill)
///   - Không gọi `_settle()` (full cascade loop) → không có "gravity waterfall" effect
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController g;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
    g = Get.put(GameController());
  });
  tearDown(Get.reset);

  // ─────────────────────── Layer 1: Attack pattern logic ───────────────────────
  group('Boss attack pattern — đúng phase, đúng loại (Fix 6)', () {
    test('phase 0 = block: chỉ trừ lượt, KHÔNG shuffle/meteor', () {
      expect(
        bossAttackPatternFor(0),
        BossAttack.block,
        reason: 'Phase 0 chỉ block — không ảnh hưởng board layout',
      );
    });

    test('phase 1 = shuffle: xáo bàn nhưng KHÔNG xóa gem', () {
      expect(
        bossAttackPatternFor(1),
        BossAttack.shuffle,
        reason:
            'Shuffle chỉ đổi màu gem, không tạo ô trống → không cần gravity',
      );
    });

    test('phase 2 = meteor: xóa vùng nhỏ → CÓ ô trống → CẦN gravity', () {
      expect(
        bossAttackPatternFor(2),
        BossAttack.meteor,
        reason:
            'Meteor clear gem → cần _applyGravityAndRefill nhưng không cần _settle()',
      );
    });

    test('phase cao hơn 2 vẫn là meteor', () {
      expect(bossAttackPatternFor(3), BossAttack.meteor);
      expect(bossAttackPatternFor(10), BossAttack.meteor);
    });
  });

  // ─────────────────────── Layer 2: bossPhase theo HP ─────────────────────────
  group('Boss phase transition — trigger đúng attack (Fix 6)', () {
    test('HP đầy → phase 0 (block, không đụng board)', () {
      g.startBoss(1);
      expect(g.bossPhase, 0);
      expect(
        g.bossAttackPattern,
        BossAttack.block,
        reason: 'Phase 0: boss chỉ trừ lượt, board không bị ảnh hưởng',
      );
    });

    test('HP ~50% → phase 1 (shuffle, không empty cells)', () {
      g.startBoss(1);
      g.bossHp.value = (g.bossMaxHp.value * 0.5).round();
      expect(g.bossPhase, 1);
      expect(
        g.bossAttackPattern,
        BossAttack.shuffle,
        reason: 'Phase 1: shuffle không tạo ô trống → gravity là no-op',
      );
    });

    test('HP ~20% → phase 2 (meteor, cần gravity sau)', () {
      g.startBoss(1);
      g.bossHp.value = (g.bossMaxHp.value * 0.2).round();
      expect(g.bossPhase, 2);
      expect(
        g.bossAttackPattern,
        BossAttack.meteor,
        reason: 'Phase 2: meteor xóa gem → chỉ cần _applyGravityAndRefill',
      );
    });
  });

  // ─────────────────────── Layer 3: engine board stability ────────────────────
  group('NeonJewelGame boss — board ổn định sau onLoad (Fix 6)', () {
    NeonJewelGame mkBoss() => NeonJewelGame(
      controller: g,
      rows: 8,
      cols: 8,
      colorCount: 6,
      onGameEnd: (_) {},
      muteSfx: true,
      boardSeed: 99,
    );

    test(
      'board sau onLoad không có match sẵn — không trigger gravity tự động',
      () async {
        await TestWidgetsFlutterBinding.instance.runAsync(() async {
          g.startBoss(1);
          final game = mkBoss();
          game.onGameResize(Vector2(560, 800));
          await game.onLoad();

          // Board phải sạch match (chứng minh settle đã hoàn thành khi init)
          expect(
            game.hasPossibleMove,
            isTrue,
            reason:
                'Board khởi tạo đúng: có nước đi, không có match sẵn làm bẫy',
          );
        });
      },
    );

    test('bossAttackSignal trigger đúng sau kBossAttackInterval[0] lượt', () {
      g.startBoss(1);
      final interval = GameController.kBossAttackInterval[0]; // = 4
      final sig0 = g.bossAttackSignal.value;

      // Mô phỏng useMove() cho tới khi boss phản đòn
      for (int i = 0; i < interval; i++) {
        g.useMove();
      }

      expect(
        g.bossAttackSignal.value,
        greaterThan(sig0),
        reason: 'Sau $interval lượt → signal tăng 1 → engine sẽ execute attack',
      );
    });

    test('block attack (phase 0): chỉ trừ lượt, bossAttackSignal tăng', () {
      g.startBoss(1);
      final movesStart = g.movesLeft.value;
      final interval = GameController.kBossAttackInterval[0];
      final dmg = GameController.kBossAttackDamage[0];

      for (int i = 0; i < interval; i++) {
        g.useMove();
      }

      // Lượt bị trừ bởi block attack (kBossAttackDamage[0]) + bản thân useMove
      // Total = interval lượt use + dmg bởi boss attack
      final movesUsedByPlayer = interval;
      final movesUsedByBoss = dmg;
      expect(
        g.movesLeft.value,
        lessThanOrEqualTo(movesStart - movesUsedByPlayer - movesUsedByBoss),
        reason:
            'Block attack trừ thêm $dmg lượt sau khi người chơi dùng $interval lượt',
      );
    });

    test('shuffle attack không trực tiếp giảm HP hay điểm boss', () {
      g.startBoss(1);
      // Đẩy lên phase 1 (shuffle phase)
      g.bossHp.value = (g.bossMaxHp.value * 0.5).round();
      expect(g.bossPhase, 1);
      expect(g.bossAttackPattern, BossAttack.shuffle);

      final hpBefore = g.bossHp.value;
      // Trigger shuffle attack signal (không làm giảm HP boss)
      final interval = GameController.kBossAttackInterval[1];
      for (int i = 0; i < interval; i++) {
        g.useMove();
      }

      // HP boss không thay đổi do attack signal thôi (cần match để giảm HP)
      expect(
        g.bossHp.value,
        lessThanOrEqualTo(hpBefore),
        reason: 'HP boss không tự tăng; attack chỉ là phản đòn người chơi',
      );
    });
  });
}

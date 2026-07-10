import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/logic/board_mechanics.dart';
import 'package:neon_jewels/logic/gem_data.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===== Logic THUẦN — băng chuyền / cổng =====
  group('board_mechanics (pure)', () {
    test('conveyorNewCol cyclic + wrap mép', () {
      const cols = 8;
      // sang phải
      expect(conveyorNewCol(0, 1, cols), 1);
      expect(conveyorNewCol(6, 1, cols), 7);
      expect(conveyorNewCol(7, 1, cols), 0); // wrap phải → mép trái
      // sang trái
      expect(conveyorNewCol(0, -1, cols), 7); // wrap trái → mép phải
      expect(conveyorNewCol(1, -1, cols), 0);
    });

    test('conveyor dịch nguyên hàng là HOÁN VỊ (không mất/nhân ô)', () {
      const cols = 8;
      final dests = {for (int c = 0; c < cols; c++) conveyorNewCol(c, 1, cols)};
      expect(dests.length, cols); // bijective: 8 cột → 8 đích phân biệt
    });

    test('buildPortalLinks tạo map 2 CHIỀU', () {
      final links = buildPortalLinks([
        [const Cell(1, 1), const Cell(6, 6)],
      ]);
      expect(links[const Cell(1, 1)], const Cell(6, 6));
      expect(links[const Cell(6, 6)], const Cell(1, 1));
      expect(links.containsKey(const Cell(0, 0)), isFalse);
    });

    test('expandPortals thêm ĐỐI TÁC (1 hop, không lặp)', () {
      final links = buildPortalLinks([
        [const Cell(1, 1), const Cell(6, 6)],
      ]);
      final out = expandPortals({const Cell(1, 1)}, links);
      expect(out.contains(const Cell(6, 6)), isTrue);
      expect(out.length, 2);
      // ô không phải cổng → không đổi
      expect(expandPortals({const Cell(3, 3)}, links), {const Cell(3, 3)});
      // map rỗng → trả nguyên
      expect(expandPortals({const Cell(1, 1)}, {}), {const Cell(1, 1)});
    });
  });

  // ===== Level specs — Wave 11 weave =====
  group('Wave 11 level specs', () {
    test('conveyor/portal/dispenser RỜI NHAU (W1-10 là màn SCORE)', () {
      final all = [
        ...kConveyorSpec.keys,
        ...kPortalSpec.keys,
        ...kDispenserSpec.keys,
      ];
      // không trùng nhau + không trùng order/spread/bomb
      expect(
        all.toSet().length,
        all.length,
        reason: 'không trùng giữa 3 cơ chế',
      );
      for (final idx in all) {
        expect(kOrderLevels.contains(idx), isFalse);
        expect(kSpreadLevels.contains(idx), isFalse);
        expect(kBombLevels.contains(idx), isFalse);
        // W28.1 (201-208): overlay gắn độc lập objective (relax rule cũ),
        // level cũ (≤200) vẫn giữ nguyên tắc mechanic luôn gắn màn score.
        if (idx <= 200) {
          expect(kLevels[idx - 1].objective, ObjectiveType.score);
        }
      }
    });

    test('màn băng chuyền được +lượt (khó hơn)', () {
      // 25 là score thường ≡1 mod 6; so với màn score không cơ chế kề (19 có
      // dispenser nên dùng 7 làm mốc sạch). Băng chuyền +5 lượt.
      for (final idx in kConveyorSpec.keys) {
        expect(kLevels[idx - 1].moves, greaterThan(15));
      }
    });
  });

  // ===== Color Rush — chế độ phụ =====
  group('Color Rush', () {
    late GameController c;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs));
      c = Get.put(GameController());
    });
    tearDown(Get.reset);

    test('startColorRush bật cờ + mục tiêu điểm + là side mode', () {
      c.startColorRush();
      expect(c.isColorRush.value, isTrue);
      expect(c.isSideMode, isTrue);
      expect(c.movesLeft.value, kColorRushMoves);
      expect(c.targetScore.value, kColorRushTarget);
      expect(c.colorRushHot.value, 0);
    });

    test(
      'tickColorRush đổi màu nóng mỗi kColorRushChangeEvery lượt (cyclic)',
      () {
        c.startColorRush();
        final n = c.level.colorCount;
        for (int i = 1; i < kColorRushChangeEvery; i++) {
          c.tickColorRush();
          expect(c.colorRushHot.value, 0, reason: 'lượt $i chưa đổi');
        }
        c.tickColorRush(); // lượt thứ N → đổi
        expect(c.colorRushHot.value, 1);
        for (int i = 0; i < kColorRushChangeEvery; i++) {
          c.tickColorRush();
        }
        expect(c.colorRushHot.value, 2 % n);
      },
    );

    test('colorRushBonus cộng điểm bội; no-op khi không phải mode', () {
      c.startColorRush();
      final s0 = c.score.value;
      c.colorRushBonus(3);
      expect(c.score.value, s0 + 3 * kColorRushBonusPerGem);
      // mode khác → không cộng
      c.startLevel(1);
      final s1 = c.score.value;
      c.colorRushBonus(5);
      expect(c.score.value, s1);
    });

    test('thắng Color Rush: side mode, KHÔNG đụng win-streak/totalWins', () {
      c.startColorRush();
      final streak = c.winStreak.value;
      final wins = c.totalWins.value;
      c.score.value = kColorRushTarget;
      expect(c.checkEnd(), 'win');
      expect(c.winStreak.value, streak);
      expect(c.totalWins.value, wins);
      // Wave 12: thưởng side-mode = 30+sao*15 (trận đầu/ngày → full).
      expect(c.lastCoinReward, 30 + c.lastStars * 15);
    });

    test('thua Color Rush → lose, KHÔNG reset win-streak', () {
      c.startColorRush();
      c.winStreak.value = 4;
      c.movesLeft.value = 0;
      expect(c.checkEnd(), 'lose');
      expect(c.winStreak.value, 4);
    });

    test('chuyển mode reset cờ colorRush', () {
      c.startColorRush();
      expect(c.isColorRush.value, isTrue);
      c.startBoss(1);
      expect(c.isColorRush.value, isFalse);
    });
  });
}

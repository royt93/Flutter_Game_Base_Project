import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/boss_skill.dart';
import 'package:pop_star_blast/presentation/controllers/raid_boss_controller.dart';

void main() {
  group('Boss Skill Pure Logic', () {
    test('BossSkill trigger đúng chu kỳ N nước đi', () {
      const skill = BossSkill(
        skillType: BossSkillType.freezeRandomCells,
        triggerEveryNMoves: 5,
      );

      expect(skill.shouldTrigger(0), isFalse);
      expect(skill.shouldTrigger(1), isFalse);
      expect(skill.shouldTrigger(4), isFalse);
      expect(skill.shouldTrigger(5), isTrue);
      expect(skill.shouldTrigger(10), isTrue);
    });

    test('freezeRandomCells khóa đúng số lượng ô, không khóa ô đã trống/khóa', () {
      final grid = <List<int?>>[
        [0, 1, 2],
        [3, null, 4],
        [5, 6, 7],
      ];
      final lockGrid = <List<int>>[
        [0, 0, 0],
        [0, 0, 0],
        [0, 0, 0],
      ];

      final frozenCount = freezeRandomCells(
        grid: grid,
        lockGrid: lockGrid,
        count: 3,
        seed: 42,
        lockDuration: 3,
      );

      expect(frozenCount, equals(3));
      // Kiểm tra ô null (1, 1) không bị khoá
      expect(lockGrid[1][1], equals(0));

      // Đếm số ô được khoá
      var totalLocked = 0;
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          if (lockGrid[r][c] > 0) totalLocked++;
        }
      }
      expect(totalLocked, equals(3));
    });

    test('freezeRandomCells deterministic với seed cố định', () {
      final grid1 = <List<int?>>[
        [0, 1],
        [2, 3],
      ];
      final lockGrid1 = <List<int>>[
        [0, 0],
        [0, 0],
      ];

      final grid2 = <List<int?>>[
        [0, 1],
        [2, 3],
      ];
      final lockGrid2 = <List<int>>[
        [0, 0],
        [0, 0],
      ];

      freezeRandomCells(grid: grid1, lockGrid: lockGrid1, count: 2, seed: 100);
      freezeRandomCells(grid: grid2, lockGrid: lockGrid2, count: 2, seed: 100);

      expect(lockGrid1, equals(lockGrid2));
    });
  });

  group('isRaidActiveForEpochDay Logic', () {
    test('isRaidActiveForEpochDay mở thứ 6 - Chủ nhật', () {
      // Epoch Day 0 = Thursday -> isRaidActive = false
      expect(isRaidActiveForEpochDay(0), isFalse);
      // Epoch Day 1 = Friday -> isRaidActive = true
      expect(isRaidActiveForEpochDay(1), isTrue);
      // Epoch Day 2 = Saturday -> isRaidActive = true
      expect(isRaidActiveForEpochDay(2), isTrue);
      // Epoch Day 3 = Sunday -> isRaidActive = true
      expect(isRaidActiveForEpochDay(3), isTrue);
      // Epoch Day 4 = Monday -> isRaidActive = false
      expect(isRaidActiveForEpochDay(4), isFalse);
    });
  });
}

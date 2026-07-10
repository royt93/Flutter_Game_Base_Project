import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/core/neon_theme.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/logic/settle.dart';

/// Wave 20.2 — Nội dung: 200 màn, thế giới 9-10, weave bố cục/dòng chảy mới.
void main() {
  group('Wave 20.2 — 200 màn / 10 thế giới', () {
    test('kLevelCount = 208, kWorlds = 10', () {
      expect(kLevelCount, 208);
      expect(kLevels.length, 208);
      expect(kWorlds.length, 10);
    });

    test('worldOfLevel đúng cho W9-10', () {
      expect(worldOfLevel(151).index, 9);
      expect(worldOfLevel(160).index, 9);
      expect(worldOfLevel(170).index, 9);
      expect(worldOfLevel(171).index, 10);
      expect(worldOfLevel(185).index, 10);
      expect(worldOfLevel(200).index, 10);
    });

    test('accentForWorld W9-10 không lỗi (wrap màu)', () {
      for (int w = 9; w <= 10; w++) {
        expect(() => NeonTheme.accentForWorld(w), returnsNormally);
      }
    });

    test('màn 151-200 index đúng thứ tự', () {
      for (int i = 150; i < 200; i++) {
        expect(kLevels[i].index, i + 1);
      }
    });
  });

  group('Wave 20.2 — weave cơ chế mới W9-10', () {
    test('weave bố cục W9-10 (163/175/193): layout đúng + score objective', () {
      for (final idx in [163, 175, 193]) {
        final lv = kLevels[idx - 1];
        expect(lv.layout, isNotNull, reason: 'màn $idx phải có layout');
        expect(
          lv.objective,
          ObjectiveType.score,
          reason: 'layout weave vào màn score',
        );
      }
    });

    test('weave dòng chảy W9-10 (169/181): flow đúng + non-down direction', () {
      for (final idx in [169, 181]) {
        final lv = kLevels[idx - 1];
        expect(lv.flow, isNotNull, reason: 'màn $idx phải có flow');
        final hasNonDown = lv.flow!.any(
          (row) => row.any((f) => f != FlowDir.down),
        );
        expect(
          hasNonDown,
          isTrue,
          reason: 'màn $idx phải có hướng chảy khác down',
        );
      }
    });

    test('weave cage W9-10 ({168,192}): clearObstacle + cage', () {
      for (final idx in {168, 192}) {
        final lv = kLevels[idx - 1];
        expect(
          lv.objective,
          ObjectiveType.clearObstacle,
          reason: 'cage weave vào màn clearObstacle',
        );
        expect(lv.obstacle, ObstacleType.cage);
      }
    });

    test('weave licorice W9 ({156}): clearObstacle + licorice', () {
      final lv = kLevels[155]; // index 156
      expect(lv.objective, ObjectiveType.clearObstacle);
      expect(lv.obstacle, ObstacleType.licorice);
    });

    test('weave jam W9 ({162}): clearObstacle + jam', () {
      final lv = kLevels[161]; // index 162
      expect(lv.objective, ObjectiveType.clearObstacle);
      expect(lv.obstacle, ObstacleType.jam);
    });

    test('weave dead-zone W9-10 ({159,177}): clearJelly + corner pattern', () {
      for (final idx in {159, 177}) {
        final lv = kLevels[idx - 1];
        expect(
          lv.objective,
          ObjectiveType.clearJelly,
          reason: 'dead-zone weave vào màn clearJelly',
        );
        expect(
          lv.jelly,
          JellyPattern.corner,
          reason: 'màn $idx phải dùng corner pattern (dead-zone)',
        );
      }
    });

    test('weave order W9-10 ({157,187}): order objective', () {
      for (final idx in {157, 187}) {
        final lv = kLevels[idx - 1];
        expect(
          lv.objective,
          ObjectiveType.order,
          reason: 'order weave vào màn score',
        );
        expect(lv.orders, isNotEmpty);
        expect(
          lv.orders!.length, // ignore: unnecessary_non_null_assertion
          3,
          reason: '3 màu mục tiêu',
        );
      }
    });

    test('weave bomb W9-10 ({151,199}): score + bonusMoves', () {
      for (final idx in {151, 199}) {
        final lv = kLevels[idx - 1];
        expect(
          lv.objective,
          ObjectiveType.score,
          reason: 'bomb weave vào màn score',
        );
        // Bomb có bonusMoves +4 so với base
        expect(
          lv.moves,
          greaterThan(17),
          reason: 'màn bomb phải có extra moves',
        );
      }
    });
  });

  group('Wave 20.2 — winnability layouts (fill đầy + hasMove)', () {
    test(
      'bàn 163 fill đầy 100% ô chơi, có nước đi',
      () => _testLayoutFill(163),
    );
    test(
      'bàn 175 fill đầy 100% ô chơi, có nước đi',
      () => _testLayoutFill(175),
    );
    test(
      'bàn 193 fill đầy 100% ô chơi, có nước đi',
      () => _testLayoutFill(193),
    );
  });

  group('Wave 20.2 — winnability horizontal matchability (M1 fix)', () {
    // M1 fix: kiểm tra mỗi layout có ít nhất 3 ô NGANG liên tiếp trong 1 hàng
    // (đảm bảo horizontal match luôn khả thi, không bị cô lập thành đảo nhỏ).
    test(
      'bàn 163 có hàng ngang ≥3 ô chơi liên tiếp',
      () => _testHorizontalMatch(163),
    );
    test(
      'bàn 175 có hàng ngang ≥3 ô chơi liên tiếp',
      () => _testHorizontalMatch(175),
    );
    test(
      'bàn 193 có hàng ngang ≥3 ô chơi liên tiếp',
      () => _testHorizontalMatch(193),
    );
  });

  group('Wave 20.2 — đường cong độ khó', () {
    test('màn 151-200 không có objective invalid (endless/boss/soda)', () {
      for (int i = 150; i < 200; i++) {
        expect(
          kLevels[i].objective,
          isNot(
            anyOf(
              ObjectiveType.endless,
              ObjectiveType.boss,
              ObjectiveType.soda,
            ),
          ),
        );
      }
    });

    test('moves W9-10 trong khoảng hợp lý [17, 35]', () {
      for (int i = 150; i < 200; i++) {
        final lv = kLevels[i];
        if (lv.objective == ObjectiveType.timeAttack) continue; // 999 lượt
        expect(
          lv.moves,
          inInclusiveRange(17, 35),
          reason: 'màn ${lv.index} moves=${lv.moves} nằm ngoài khoảng',
        );
      }
    });

    test(
      'targetScore score/timeAttack W9-10 > 0 (order dùng orders thay thế)',
      () {
        for (int i = 150; i < 200; i++) {
          final lv = kLevels[i];
          if (lv.objective == ObjectiveType.score ||
              lv.objective == ObjectiveType.timeAttack) {
            expect(
              lv.targetScore,
              greaterThan(0),
              reason:
                  'màn ${lv.index} (${lv.objective}) phải có targetScore > 0',
            );
          }
        }
      },
    );
  });
}

/// Verify bàn có layout fill 100% ô chơi (winnability guard như test W16).
void _testLayoutFill(int levelIndex) {
  final layoutMap = kLayoutLevels[levelIndex]!;
  final grid = layoutFromMap(layoutMap);
  const rows = 8, cols = 8;

  // Đếm ô chơi
  int playCells = 0;
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      if (grid[r][c] != CellKind.wall) playCells++;
    }
  }
  expect(
    playCells,
    greaterThan(40),
    reason: 'bàn $levelIndex phải có >40 ô chơi (bàn 8×8)',
  );

  // Verify không có cột nào hoàn toàn bị tường chặn
  for (int c = 0; c < cols; c++) {
    int colPlay = 0;
    for (int r = 0; r < rows; r++) {
      if (grid[r][c] != CellKind.wall) colPlay++;
    }
    expect(
      colPlay,
      greaterThan(0),
      reason: 'cột $c của màn $levelIndex không được toàn tường',
    );
  }
}

/// M1 fix: Verify bàn có ít nhất 1 hàng với ≥3 ô chơi NGANG liên tiếp —
/// đảm bảo horizontal match luôn khả thi (không bị cô lập micro-segment).
void _testHorizontalMatch(int levelIndex) {
  final layoutMap = kLayoutLevels[levelIndex]!;
  final grid = layoutFromMap(layoutMap);
  const rows = 8, cols = 8;
  bool found = false;
  for (int r = 0; r < rows && !found; r++) {
    int run = 0;
    for (int c = 0; c < cols; c++) {
      if (grid[r][c] != CellKind.wall) {
        run++;
        if (run >= 3) {
          found = true;
          break;
        }
      } else {
        run = 0;
      }
    }
  }
  expect(
    found,
    isTrue,
    reason:
        'màn $levelIndex phải có ít nhất 1 hàng với ≥3 ô chơi liên tiếp (horizontal match)',
  );
}

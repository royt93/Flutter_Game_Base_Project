import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/boss_rush.dart';
import 'package:pop_star_blast/data/worlds.dart';

void main() {
  group('bossRushLevelForStage', () {
    test('boss tile luôn vừa bàn (fitsBoard)', () {
      for (var stage = 1; stage <= 60; stage++) {
        for (var world = 0; world < kWorlds.length; world++) {
          final level = bossRushLevelForStage(stage, world);
          expect(level.bossTileSpec, isNotNull);
          expect(
            level.bossTileSpec!.fitsBoard(level.rows, level.cols),
            isTrue,
            reason: 'stage=$stage world=$world',
          );
        }
      }
    });

    test(
      'deterministic: cùng stage + maxUnlockedWorld → kết quả giống hệt',
      () {
        final a = bossRushLevelForStage(5, 3);
        final b = bossRushLevelForStage(5, 3);
        expect(a.rows, b.rows);
        expect(a.cols, b.cols);
        expect(a.colorCount, b.colorCount);
        expect(a.targetScore, b.targetScore);
        expect(a.bossTileSpec!.startHp, b.bossTileSpec!.startHp);
      },
    );

    test(
      'maxUnlockedWorld=0 → bàn nguồn luôn thuộc world đầu (rows=8, cols=6)',
      () {
        // World 0 (level 1..20) là world duy nhất luôn có rows=8/cols=6 cố định
        // (công thức levels.dart: rows=8+(0~/2)=8, cols=6+0=6) — world khác
        // không bao giờ trùng cặp rows/cols này, nên đây là bằng chứng đủ mạnh
        // để xác nhận nguồn không lọt sang world cao hơn.
        for (var stage = 1; stage <= 30; stage++) {
          final level = bossRushLevelForStage(stage, 0);
          expect(level.rows, 8);
          expect(level.cols, 6);
        }
      },
    );

    test('targetScore tăng theo stage nhưng bị chặn trần', () {
      final low = bossRushLevelForStage(1, 5);
      final mid = bossRushLevelForStage(20, 5);
      final high = bossRushLevelForStage(200, 5);
      expect(mid.targetScore, greaterThan(low.targetScore));
      expect(high.targetScore, greaterThan(mid.targetScore));
      // stage 200 và 400 đều vượt trần scale (2.5x) → hệ số nhân bằng đúng
      // trần, không tiếp tục leo.
      expect(bossRushStageMultiplier(200), bossRushStageScaleCap);
      expect(bossRushStageMultiplier(400), bossRushStageScaleCap);
    });

    test('id luôn âm và không trùng giữa các stage', () {
      final ids = {
        for (var s = 1; s <= 20; s++) bossRushLevelForStage(s, 2).id,
      };
      expect(ids.length, 20);
      expect(ids.every((id) => id < 0), isTrue);
    });
  });

  group('bossRushStageMultiplier', () {
    test('stage 1 → hệ số gần 1.05', () {
      expect(bossRushStageMultiplier(1), closeTo(1.05, 0.001));
    });

    test('không bao giờ vượt bossRushStageScaleCap', () {
      for (final s in [50, 100, 1000, 10000]) {
        expect(
          bossRushStageMultiplier(s),
          lessThanOrEqualTo(bossRushStageScaleCap),
        );
      }
    });
  });
}

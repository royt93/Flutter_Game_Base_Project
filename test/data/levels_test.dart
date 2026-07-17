import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/levels.dart';

void main() {
  group('kLevels', () {
    test('có đúng kLevelCount màn, id liên tục 1..N', () {
      expect(kLevels.length, kLevelCount);
      for (var i = 0; i < kLevels.length; i++) {
        expect(kLevels[i].id, i + 1);
      }
    });

    test('mọi màn có board hợp lệ', () {
      for (final lv in kLevels) {
        expect(lv.rows, greaterThanOrEqualTo(1));
        expect(lv.cols, greaterThanOrEqualTo(1));
        expect(lv.colorCount, greaterThanOrEqualTo(2));
      }
    });

    // Bàn hữu hạn + KHÔNG refill → điểm đạt được scale theo số ô, không theo
    // index màn. targetScore PHẢI neo vào diện tích bàn, nếu không màn cao thành
    // bất khả thi (bug cũ: công thức leo-tuyến-tính khiến ~146/200 màn thua chắc).
    // Guard: greedy-bot (lower bound, không booster) đạt ~10 điểm/ô ở đầu game,
    // nên target 1-sao phải nằm trong [4, 9] điểm/ô.
    test('targetScore neo vào diện tích bàn (chống mis-scaling)', () {
      for (final lv in kLevels.where((l) => !l.isBoss)) {
        final perCell = lv.targetScore / (lv.rows * lv.cols);
        expect(
          perCell,
          inInclusiveRange(4, 9),
          reason:
              'L${lv.id}: target ${lv.targetScore} = '
              '${perCell.toStringAsFixed(1)} điểm/ô — ngoài khoảng đạt được',
        );
      }
    });

    // F11: boss level target nhân bossTargetMultiplier → khoảng khả thi nới
    // rộng theo đúng hệ số, không random tay.
    test('boss targetScore vẫn trong khoảng khả thi mở rộng', () {
      for (final lv in kLevels.where((l) => l.isBoss)) {
        final perCell = lv.targetScore / (lv.rows * lv.cols);
        expect(
          perCell,
          inInclusiveRange(4, 9 * bossTargetMultiplier),
          reason: 'L${lv.id}: target ${lv.targetScore} ngoài khoảng khả thi',
        );
      }
    });

    // F11: level cuối mỗi world (20, 40, ..., 200) là boss.
    test('isBoss đúng level id % 20 == 0', () {
      for (final lv in kLevels) {
        expect(
          lv.isBoss,
          lv.id % 20 == 0,
          reason: 'L${lv.id}: isBoss=${lv.isBoss} sai',
        );
      }
    });

    // F11: target boss = target thường cùng world × bossTargetMultiplier,
    // luôn cao hơn hẳn level thường liền trước.
    test('boss target = target thường × bossTargetMultiplier, cao hơn màn '
        'liền trước', () {
      for (final lv in kLevels.where((l) => l.isBoss)) {
        final world = (lv.id - 1) ~/ 20;
        final ramp = 1.0 + world * 0.03;
        final baseTarget = (lv.rows * lv.cols * 6 * ramp).round();
        expect(
          lv.targetScore,
          (baseTarget * bossTargetMultiplier).round(),
          reason: 'L${lv.id}: target boss sai công thức',
        );
        final prev = kLevels[lv.id - 2];
        expect(
          lv.targetScore,
          greaterThan(prev.targetScore),
          reason: 'L${lv.id}: boss target không cao hơn L${prev.id}',
        );
      }
    });

    // I21: colorCount đa dạng theo level, không chỉ theo world (mỗi world
    // 20 màn phải có ít nhất 2 giá trị colorCount khác nhau).
    test('colorCount đa dạng trong cùng world, vẫn kẹp trần/sàn 4..7', () {
      for (var world = 0; world < kLevelCount ~/ 20; world++) {
        final levelsInWorld = kLevels.sublist(world * 20, world * 20 + 20);
        final distinct = levelsInWorld.map((l) => l.colorCount).toSet();
        expect(
          distinct.length,
          greaterThanOrEqualTo(2),
          reason: 'World $world: colorCount không đa dạng ($distinct)',
        );
        for (final lv in levelsInWorld) {
          expect(lv.colorCount, inInclusiveRange(4, 7));
        }
      }
    });

    // F9/task#6: objective rotate chu kỳ 9 màn (3 score, rồi clearColor/
    // clearObstacle/collect/moveLimitBonus/obstacleInMoves/openGift) xuyên
    // suốt các màn thường. I25: màn boss có luân phiên riêng (xem group
    // 'boss variant' dưới), nên bỏ qua isBoss ở đây.
    test('objective luân phiên đúng chu kỳ 9 màn (màn thường)', () {
      for (var i = 0; i < kLevels.length; i++) {
        if (kLevels[i].isBoss) continue;
        final expected = switch (i % 9) {
          3 => ObjectiveType.clearColor,
          4 => ObjectiveType.clearObstacle,
          5 => ObjectiveType.collect,
          6 => ObjectiveType.moveLimitBonus,
          7 => ObjectiveType.obstacleInMoves,
          8 => ObjectiveType.openGift,
          _ => ObjectiveType.score,
        };
        expect(
          kLevels[i].objective.type,
          expected,
          reason: 'L${kLevels[i].id} (slot ${i % 9}) sai objective',
        );
      }
    });

    // I25 (task #15): boss level (id % 20 == 0) luân phiên 4 variant theo
    // world (world % 4) — không theo chu kỳ 9-slot của màn thường.
    test('boss variant luân phiên đúng theo world % 4', () {
      for (final lv in kLevels.where((l) => l.isBoss)) {
        final world = (lv.id - 1) ~/ 20;
        final expected = switch (world % 4) {
          1 => ObjectiveType.clearColor,
          2 => ObjectiveType.obstacleInMoves,
          3 => ObjectiveType.openGift,
          _ => ObjectiveType.score,
        };
        expect(
          lv.objective.type,
          expected,
          reason:
              'L${lv.id} (world $world, variant ${world % 4}) sai boss '
              'objective',
        );
      }
    });

    // task#6: openGift target phải >=2 và không vượt số ô trống trên bàn.
    test('openGift: target hợp lý, không vượt số ô của bàn', () {
      for (final lv in kLevels.where(
        (l) => l.objective.type == ObjectiveType.openGift,
      )) {
        final target = lv.objective.target!;
        expect(
          target,
          inInclusiveRange(2, lv.rows * lv.cols),
          reason: 'L${lv.id}: openGift target $target vô lý',
        );
      }
    });
  });

  // F12: generator Endless — board hợp lệ, khó dần theo boardIndex, kẹp trần.
  group('endlessLevelForIndex', () {
    test('board luôn hợp lệ (rows/cols/colorCount tối thiểu)', () {
      for (var i = 0; i < 200; i++) {
        final lv = endlessLevelForIndex(i);
        expect(lv.rows, greaterThanOrEqualTo(7));
        expect(lv.cols, greaterThanOrEqualTo(6));
        expect(lv.colorCount, greaterThanOrEqualTo(4));
        expect(lv.id, -3);
        expect(lv.targetScore, 0);
      }
    });

    test('không giảm khi boardIndex tăng (khó dần hoặc giữ nguyên)', () {
      var prev = endlessLevelForIndex(0);
      for (var i = 1; i < 100; i++) {
        final lv = endlessLevelForIndex(i);
        expect(lv.rows, greaterThanOrEqualTo(prev.rows));
        expect(lv.cols, greaterThanOrEqualTo(prev.cols));
        expect(lv.colorCount, greaterThanOrEqualTo(prev.colorCount));
        prev = lv;
      }
    });

    test('kẹp trần rows/cols/colorCount ở board xa', () {
      final lv = endlessLevelForIndex(1000);
      expect(lv.rows, 14);
      expect(lv.cols, 14);
      expect(lv.colorCount, 8);
    });
  });
}

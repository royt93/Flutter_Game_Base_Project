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
      for (final lv in kLevels) {
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

    // F6b: objective rotate chu kỳ 5 màn (3 score, 1 clearColor, 1
    // clearObstacle) xuyên suốt cả 200 màn.
    test('objective luân phiên đúng chu kỳ 5 màn', () {
      for (var i = 0; i < kLevels.length; i++) {
        final expected = switch (i % 5) {
          3 => ObjectiveType.clearColor,
          4 => ObjectiveType.clearObstacle,
          _ => ObjectiveType.score,
        };
        expect(
          kLevels[i].objective.type,
          expected,
          reason: 'L${kLevels[i].id} (slot ${i % 5}) sai objective',
        );
      }
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/data/levels.dart';

void main() {
  group('kLevels — tính hợp lệ', () {
    test('có đúng 100 level', () {
      expect(kLevels.length, kLevelCount);
      expect(kLevels.length, 100);
    });

    test('index liên tục từ 1', () {
      for (int i = 0; i < kLevels.length; i++) {
        expect(kLevels[i].index, i + 1);
      }
    });

    test('tham số cơ bản hợp lệ', () {
      for (final lv in kLevels) {
        expect(lv.rows, greaterThanOrEqualTo(5));
        expect(lv.cols, greaterThanOrEqualTo(5));
        expect(lv.colorCount, inInclusiveRange(3, 6));
        expect(lv.moves, greaterThan(0));
      }
    });

    test('cấu hình mục tiêu nhất quán theo loại', () {
      for (final lv in kLevels) {
        switch (lv.objective) {
          case ObjectiveType.score:
            expect(lv.targetScore, greaterThan(0),
                reason: 'level ${lv.index} score cần targetScore > 0');
            break;
          case ObjectiveType.collect:
            expect(lv.collectTarget, greaterThan(0));
            expect(lv.collectColor, isNotNull);
            break;
          case ObjectiveType.clearJelly:
            expect(lv.jelly, isNot(JellyPattern.none));
            break;
        }
      }
    });

    test('có đủ 3 loại mục tiêu trong 5 màn demo', () {
      final types = kLevels.map((l) => l.objective).toSet();
      expect(types, containsAll(ObjectiveType.values));
    });

    test('mọi màn dùng board 8x8 chuẩn (đồng nhất)', () {
      for (final lv in kLevels) {
        expect(lv.rows, 8, reason: 'level ${lv.index} rows != 8');
        expect(lv.cols, 8, reason: 'level ${lv.index} cols != 8');
      }
    });
  });
}

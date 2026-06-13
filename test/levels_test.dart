import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/data/levels.dart';

void main() {
  group('kLevels — tính hợp lệ', () {
    test('có đúng 5 level', () {
      expect(kLevels.length, 5);
    });

    test('index liên tục từ 1', () {
      for (int i = 0; i < kLevels.length; i++) {
        expect(kLevels[i].index, i + 1);
      }
    });

    test('mọi tham số dương & hợp lý', () {
      for (final lv in kLevels) {
        expect(lv.rows, greaterThanOrEqualTo(5));
        expect(lv.cols, greaterThanOrEqualTo(5));
        expect(lv.colorCount, inInclusiveRange(3, 6));
        expect(lv.moves, greaterThan(0));
        expect(lv.targetScore, greaterThan(0));
      }
    });

    test('độ khó tăng dần (điểm mục tiêu)', () {
      for (int i = 1; i < kLevels.length; i++) {
        expect(kLevels[i].targetScore, greaterThan(kLevels[i - 1].targetScore));
      }
    });
  });
}

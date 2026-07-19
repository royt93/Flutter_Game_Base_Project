import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/combo_milestones.dart';

void main() {
  group('isComboMilestone', () {
    test('đúng cho mọi giá trị trong kComboMilestones', () {
      for (final m in kComboMilestones) {
        expect(isComboMilestone(m), isTrue);
      }
    });

    test('sai cho giá trị ngoài danh sách mốc', () {
      for (final n in [0, 1, 4, 6, 9, 11, 14, 16, 19, 21, 100]) {
        expect(isComboMilestone(n), isFalse);
      }
    });
  });
}

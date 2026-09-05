import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/haptics.dart';

void main() {
  group('hapticLevelForGroupSize (I11 — rung theo cỡ nhóm nổ)', () {
    test('nhóm nhỏ (<4) → light', () {
      expect(hapticLevelForGroupSize(2), HapticLevel.light);
      expect(hapticLevelForGroupSize(3), HapticLevel.light);
    });

    test('nhóm vừa (4..7) → medium', () {
      expect(hapticLevelForGroupSize(4), HapticLevel.medium);
      expect(hapticLevelForGroupSize(7), HapticLevel.medium);
    });

    test('nhóm lớn (>=8) → heavy', () {
      expect(hapticLevelForGroupSize(8), HapticLevel.heavy);
      expect(hapticLevelForGroupSize(20), HapticLevel.heavy);
    });
  });
}

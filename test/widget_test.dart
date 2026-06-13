// Smoke test cơ bản cho Neon Jewels.
import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/logic/gem_data.dart';

void main() {
  test('GemColor có đủ 6 màu', () {
    expect(GemColor.values.length, 6);
  });

  test('GemType có normal + 3 special', () {
    expect(GemType.values.length, 4);
  });
}

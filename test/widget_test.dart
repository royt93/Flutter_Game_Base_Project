// Smoke test cơ bản cho Neon Jewels.
import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/logic/gem_data.dart';

void main() {
  test('GemColor có đủ 6 màu', () {
    expect(GemColor.values.length, 6);
  });

  test('GemType có normal + 6 special (striped H/V, bomb, rainbow, diagonal, lightBall)', () {
    expect(GemType.values.length, 7);
    expect(GemType.values.contains(GemType.diagonal), isTrue);
    expect(GemType.values.contains(GemType.lightBall), isTrue);
  });
}

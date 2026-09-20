import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/weighted_random_pick.dart';

void main() {
  test('1 phần tử trọng số 100% → luôn ra đúng phần tử đó', () {
    for (var i = 0; i < 20; i++) {
      expect(weightedRandomPick(['gold'], [1.0]), 'gold');
    }
  });

  test('trọng số 0 → không bao giờ được chọn', () {
    final rng = Random(42);
    for (var i = 0; i < 500; i++) {
      final pick = weightedRandomPick(
        ['common', 'never'],
        [1.0, 0.0],
        random: rng,
      );
      expect(pick, 'common');
    }
  });

  test('phân phối xấp xỉ đúng tỉ lệ trọng số qua nhiều lần lặp (thống kê)', () {
    final rng = Random(7);
    var rareCount = 0;
    const iterations = 10000;
    for (var i = 0; i < iterations; i++) {
      final pick = weightedRandomPick(
        ['common', 'rare'],
        [9.0, 1.0],
        random: rng,
      );
      if (pick == 'rare') rareCount++;
    }
    // Kỳ vọng ~10% — cho sai số thống kê rộng rãi (7%-13%) để test không
    // flaky theo seed/phiên bản Random.
    final ratio = rareCount / iterations;
    expect(ratio, greaterThan(0.07));
    expect(ratio, lessThan(0.13));
  });

  test('BUG-21: items.length != weights.length → ArgumentError (không phải '
      'chỉ assert — vẫn throw ở release build)', () {
    expect(() => weightedRandomPick(['a', 'b'], [1.0]), throwsArgumentError);
  });

  test('BUG-21: items rỗng → ArgumentError', () {
    expect(() => weightedRandomPick<String>([], []), throwsArgumentError);
  });

  test('BUG-21: trọng số âm → ArgumentError', () {
    expect(
      () => weightedRandomPick(['a', 'b'], [1.0, -1.0]),
      throwsArgumentError,
    );
  });

  test('BUG-21: trọng số NaN → ArgumentError', () {
    expect(
      () => weightedRandomPick(['a', 'b'], [1.0, double.nan]),
      throwsArgumentError,
    );
  });

  test('BUG-21: trọng số Infinity → ArgumentError', () {
    expect(
      () => weightedRandomPick(['a', 'b'], [1.0, double.infinity]),
      throwsArgumentError,
    );
  });

  test('BUG-21: tổng trọng số = 0 (mọi trọng số đều 0) → ArgumentError', () {
    expect(
      () => weightedRandomPick(['a', 'b'], [0.0, 0.0]),
      throwsArgumentError,
    );
  });
}

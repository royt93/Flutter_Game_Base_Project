import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/burst_styles.dart';

void main() {
  group('isBurstStyleUnlocked', () {
    test('spark (threshold 0) luôn mở khoá bất kể totalGemsPopped', () {
      final spark = kBurstStyles.firstWhere(
        (s) => s.kind == BurstStyleKind.spark,
      );
      expect(isBurstStyleUnlocked(spark, 0), isTrue);
      expect(isBurstStyleUnlocked(spark, 999999), isTrue);
    });

    test('style khác chỉ mở khoá khi totalGemsPopped >= unlockThreshold', () {
      for (final style in kBurstStyles) {
        expect(
          isBurstStyleUnlocked(style, style.unlockThreshold - 1),
          isFalse,
          reason: '${style.kind}: dưới ngưỡng vẫn coi là mở khoá',
        );
        expect(
          isBurstStyleUnlocked(style, style.unlockThreshold),
          isTrue,
          reason: '${style.kind}: đúng ngưỡng phải mở khoá',
        );
        expect(
          isBurstStyleUnlocked(style, style.unlockThreshold + 1000),
          isTrue,
          reason: '${style.kind}: vượt ngưỡng phải mở khoá',
        );
      }
    });

    test('4 style có đủ 4 kind, ngưỡng tăng dần', () {
      expect(kBurstStyles.length, 4);
      expect(
        kBurstStyles.map((s) => s.kind).toSet(),
        BurstStyleKind.values.toSet(),
      );
      for (var i = 1; i < kBurstStyles.length; i++) {
        expect(
          kBurstStyles[i].unlockThreshold,
          greaterThan(kBurstStyles[i - 1].unlockThreshold),
        );
      }
    });
  });
}

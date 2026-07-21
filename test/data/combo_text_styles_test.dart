import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/combo_text_styles.dart';

void main() {
  group('isComboTextStyleUnlocked', () {
    test('neon (threshold 0) luôn mở khoá bất kể maxComboEver', () {
      final neon = kComboTextStyles.firstWhere(
        (s) => s.kind == ComboTextStyleKind.neon,
      );
      expect(isComboTextStyleUnlocked(neon, 0), isTrue);
      expect(isComboTextStyleUnlocked(neon, 999999), isTrue);
    });

    test('style khác chỉ mở khoá khi maxComboEver >= unlockThreshold', () {
      for (final style in kComboTextStyles) {
        expect(
          isComboTextStyleUnlocked(style, style.unlockThreshold - 1),
          isFalse,
          reason: '${style.kind}: dưới ngưỡng vẫn coi là mở khoá',
        );
        expect(
          isComboTextStyleUnlocked(style, style.unlockThreshold),
          isTrue,
          reason: '${style.kind}: đúng ngưỡng phải mở khoá',
        );
        expect(
          isComboTextStyleUnlocked(style, style.unlockThreshold + 1000),
          isTrue,
          reason: '${style.kind}: vượt ngưỡng phải mở khoá',
        );
      }
    });

    test('4 style có đủ 4 kind, ngưỡng tăng dần', () {
      expect(kComboTextStyles.length, 4);
      expect(
        kComboTextStyles.map((s) => s.kind).toSet(),
        ComboTextStyleKind.values.toSet(),
      );
      for (var i = 1; i < kComboTextStyles.length; i++) {
        expect(
          kComboTextStyles[i].unlockThreshold,
          greaterThan(kComboTextStyles[i - 1].unlockThreshold),
        );
      }
    });
  });
}

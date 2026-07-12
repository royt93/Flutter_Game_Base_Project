import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/app_translations.dart';

void main() {
  test('mọi ngôn ngữ trong AppTranslations.supported đủ key như English', () {
    final keys = AppTranslations().keys;
    final enCode = AppTranslations.codeOf(AppTranslations.fallback);
    final enKeys = keys[enCode]!.keys.toSet();

    for (final locale in AppTranslations.supported) {
      final code = AppTranslations.codeOf(locale);
      expect(keys.containsKey(code), isTrue, reason: '$code thiếu trong keys');
      final missing = enKeys.difference(keys[code]!.keys.toSet());
      expect(missing, isEmpty, reason: '$code thiếu key: $missing');
    }
  });

  test('mọi locale trong supported có tên hiển thị trong languageNames', () {
    for (final locale in AppTranslations.supported) {
      final code = AppTranslations.codeOf(locale);
      expect(
        AppTranslations.languageNames.containsKey(code),
        isTrue,
        reason: '$code thiếu trong languageNames',
      );
    }
  });
}

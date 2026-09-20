import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/utils/pseudo_locale.dart';

void main() {
  group('pseudoLocalize', () {
    test('deterministic: cùng input luôn ra cùng output', () {
      expect(pseudoLocalize('Settings'), pseudoLocalize('Settings'));
    });

    test('bọc trong [[ ]]', () {
      final result = pseudoLocalize('OK');
      expect(result, startsWith('[['));
      expect(result, endsWith(']]'));
    });

    test('vowel được thay bằng ký tự có dấu tương ứng', () {
      final result = pseudoLocalize('OK');
      expect(result, contains('Ó'));
      expect(result, isNot(contains('O]')));
    });

    test(
      'chuỗi hardcode (không qua pseudoLocalize) vẫn giữ nguyên ASCII, dễ phân biệt',
      () {
        const hardcoded = 'OK';
        final translated = pseudoLocalize('OK');
        expect(hardcoded, isNot(equals(translated)));
        expect(hardcoded, 'OK');
      },
    );

    test('độ dài tăng ~40% (stress-test overflow)', () {
      final result = pseudoLocalize('Settings');
      expect(result.length, greaterThan('Settings'.length));
    });

    test('chuỗi rỗng -> vẫn không throw, vẫn có marker bracket', () {
      final result = pseudoLocalize('');
      expect(result, startsWith('[['));
      expect(result, endsWith(']]'));
    });

    test(
      'ký tự không phải vowel latin (vd tiếng Việt có dấu sẵn) giữ nguyên',
      () {
        final result = pseudoLocalize('Cài đặt');
        expect(result, contains('đ'));
      },
    );
  });

  group('PseudoLocaleTranslations', () {
    test('phủ đúng 100% key từ baseKeys, không thiếu không thừa', () {
      const base = {'a': 'Apple', 'b': 'Banana'};
      final translations = PseudoLocaleTranslations(baseKeys: base);
      final localeMap = translations.keys[translations.localeKey]!;
      expect(localeMap.keys.toSet(), base.keys.toSet());
    });

    test(
      'mọi value đều đã qua pseudoLocalize (không phải copy nguyên văn)',
      () {
        const base = {'ok': 'OK', 'cancel': 'Cancel'};
        final translations = PseudoLocaleTranslations(baseKeys: base);
        final localeMap = translations.keys[translations.localeKey]!;
        for (final entry in base.entries) {
          expect(localeMap[entry.key], pseudoLocalize(entry.value));
          expect(localeMap[entry.key], isNot(entry.value));
        }
      },
    );

    test('locale mặc định là qps_PLOC, không trùng locale thật nào', () {
      expect(PseudoLocaleTranslations.defaultLocale.languageCode, 'qps');
      expect(PseudoLocaleTranslations.defaultLocale.countryCode, 'PLOC');
    });

    test(
      'phủ toàn bộ key thật của AppTranslations (en) — không bỏ sót key production nào',
      () {
        final baseKeys = AppTranslations().keys['en']!;
        final translations = PseudoLocaleTranslations(baseKeys: baseKeys);
        final localeMap = translations.keys[translations.localeKey]!;
        expect(localeMap.keys.toSet(), baseKeys.keys.toSet());
        expect(localeMap.length, baseKeys.length);
      },
    );

    test(
      'KHÔNG nằm trong AppTranslations.supported — không rò vào danh sách locale production',
      () {
        expect(
          AppTranslations.supported.any(
            (l) =>
                l.languageCode ==
                PseudoLocaleTranslations.defaultLocale.languageCode,
          ),
          isFalse,
        );
      },
    );
  });
}

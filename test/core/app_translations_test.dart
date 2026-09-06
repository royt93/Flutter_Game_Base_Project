import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/app_translations.dart';

void main() {
  group('AppTranslations', () {
    test('en và vi có cùng bộ key (key parity)', () {
      final keys = AppTranslations().keys;
      expect(keys['en']!.keys.toSet(), keys['vi']!.keys.toSet());
    });

    test('back_button_label tồn tại ở cả en và vi', () {
      final keys = AppTranslations().keys;
      expect(keys['en'], contains('back_button_label'));
      expect(keys['vi'], contains('back_button_label'));
    });
  });
}

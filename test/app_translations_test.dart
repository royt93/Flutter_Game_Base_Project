import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/core/app_translations.dart';

void main() {
  final t = AppTranslations();
  final keys = t.keys;

  group('AppTranslations — tính toàn vẹn', () {
    test('English (en_US) là ngôn ngữ default đầu tiên', () {
      expect(AppTranslations.supported.first,
          const Locale('en', 'US'));
      expect(AppTranslations.fallback, const Locale('en', 'US'));
    });

    test('mọi locale hỗ trợ đều có bảng dịch', () {
      for (final l in AppTranslations.supported) {
        expect(keys.containsKey(AppTranslations.codeOf(l)), isTrue,
            reason: 'thiếu bảng dịch cho ${AppTranslations.codeOf(l)}');
      }
    });

    test('mọi ngôn ngữ có ĐỦ key giống English (không thiếu/dư)', () {
      final enKeys = keys['en_US']!.keys.toSet();
      for (final entry in keys.entries) {
        final langKeys = entry.value.keys.toSet();
        expect(langKeys, enKeys,
            reason: 'ngôn ngữ ${entry.key} có tập key khác English');
      }
    });

    test('không có giá trị rỗng', () {
      for (final entry in keys.entries) {
        for (final kv in entry.value.entries) {
          expect(kv.value.trim().isNotEmpty, isTrue,
              reason: '${entry.key}/${kv.key} bị rỗng');
        }
      }
    });

    test('placeholder @count / @value / @n được giữ nguyên khi dịch', () {
      expect(keys['en_US']!['levels_tagline']!.contains('@count'), isTrue);
      expect(keys['vi_VN']!['levels_tagline']!.contains('@count'), isTrue);
      expect(keys['vi_VN']!['score_value']!.contains('@value'), isTrue);
      expect(keys['vi_VN']!['stage_n']!.contains('@n'), isTrue);
    });

    test('mỗi locale hỗ trợ có tên hiển thị (native name)', () {
      for (final l in AppTranslations.supported) {
        expect(AppTranslations.languageNames[AppTranslations.codeOf(l)],
            isNotNull);
      }
    });

    test('key Wave 4 đã dịch thật (không còn fallback English)', () {
      // mẫu vài ngôn ngữ: hud_time KHÁC bản English 'TIME'
      expect(keys['es_ES']!['hud_time'], 'TIEMPO');
      expect(keys['de_DE']!['hud_time'], 'ZEIT');
      expect(keys['ja_JP']!['daily_title'], 'デイリーボーナス');
      expect(keys['ru_RU']!['buy'], 'КУПИТЬ');
      expect(keys['ar_SA']!['lives_label'], 'الأرواح');
      // placeholder vẫn còn trong bản dịch
      expect(keys['fr_FR']!['lives_buy_msg']!.contains('@n'), isTrue);
      expect(keys['th_TH']!['lives_next']!.contains('@t'), isTrue);
    });
  });
}

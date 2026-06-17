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

    // ── Chống hồi quy lỗ hổng i18n (Wave 8.9): trước đây 20 ngôn ngữ chỉ ~50%
    // key được dịch (Wave 5/7/8/9 fallback English). Test cũ chỉ kiểm KEY đủ
    // (qua fallback merge) nên KHÔNG phát hiện. 2 test dưới kiểm VALUE đã dịch.
    test('mỗi ngôn ngữ phải dịch ≥80% value (không fallback English hàng loạt)',
        () {
      final en = keys['en_US']!;
      for (final entry in keys.entries) {
        if (entry.key == 'en_US') continue;
        var diff = 0;
        entry.value.forEach((k, v) {
          if (v.trim() != en[k]?.trim()) diff++;
        });
        final ratio = diff / entry.value.length;
        expect(ratio, greaterThanOrEqualTo(0.80),
            reason: '${entry.key} chỉ dịch ${(ratio * 100).toStringAsFixed(1)}% '
                '— nghi fallback English (thêm feature mới mà quên dịch?)');
      }
    });

    test('key Wave 5/7/8/9 đã dịch thật cho 20 ngôn ngữ (mẫu)', () {
      // Các key mô tả/UI tiêu biểu (không phải tên riêng) phải KHÁC bản English.
      const sampleKeys = [
        'achievements', 'win_streak', 'tut_1', 'season_hint', 'boss_hp',
        'temple_tier', 'quest_win', 'ach_claim', 'bp_track', 'guide_versus_body',
      ];
      const langs = [
        'es_ES', 'de_DE', 'ru_RU', 'zh_CN', 'ja_JP', 'ko_KR',
        'ar_SA', 'th_TH', 'hi_IN', 'uk_UA', 'bn_BD',
      ];
      final en = keys['en_US']!;
      for (final k in sampleKeys) {
        for (final lang in langs) {
          expect(keys[lang]![k], isNot(en[k]),
              reason: '$lang/$k còn dùng English (chưa dịch Wave 5/7/8/9)');
        }
      }
      // placeholder vẫn giữ nguyên sau khi dịch
      expect(keys['ru_RU']!['streak_bonus']!.contains('@n'), isTrue);
      expect(keys['bn_BD']!['daily_ch_reward']!.contains('@c'), isTrue);
    });
  });
}

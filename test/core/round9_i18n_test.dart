import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/app_translations.dart';

/// Round 9 — 67 key mới (I81/I83/I87 + F16-F21) phải có bản dịch thật, không
/// rơi về tiếng Anh.
///
/// **Bối cảnh trung thực:** repo còn thiếu 380 key CŨ ở 20 ngôn ngữ (từ trước
/// Round 9). File này chỉ khoá phần Round 9 tự tạo ra — không giả vờ rằng i18n
/// đã đầy đủ.
///
/// Danh sách `_done` là hợp đồng: ngôn ngữ nào đã dịch thì không được rơi
/// ngược về tiếng Anh. Ngôn ngữ chưa dịch nằm ở `_pending`, và khi dịch xong
/// thì **chuyển sang `_done`** — quên chuyển thì test không nhắc, nên phần
/// dưới có ca đếm để con số luôn hiện ra.
const _round9Keys = <String>[
  'weather_bubble_name', 'weather_bubble_desc', 'weather_spark_name',
  'weather_spark_desc', 'weather_rule_banner',
  'pp_discount', 'pp_discount_desc', 'pp_star_dust', 'pp_star_dust_desc',
  'pp_craft', 'pp_craft_desc', 'pp_free_second_chance',
  'pp_free_second_chance_desc', 'pp_locked_hint', 'pp_slots',
  'journey_card_title', 'journey_card_anonymous', 'journey_card_stars',
  'journey_card_level', 'journey_card_combo', 'journey_card_days',
  'journey_share_action', 'journey_share_text',
  'digest_days_away', 'digest_stars_to_chest', 'digest_weekly_left',
  'digest_season_ending', 'digest_next_level',
  'combo_token_label', 'combo_token_short', 'token_reroll_quest',
  'token_buy_raid', 'token_buy_map', 'token_limit_reached',
  'token_not_enough',
  'puzzle_daily_label', 'puzzle_daily_desc', 'puzzle_daily_done',
  'fusion_title', 'fusion_hint', 'fusion_cost', 'fusion_cp',
  'fusion_no_recipe', 'fusion_need_cp', 'fusion_pick', 'fusion_done',
  'fusion_book',
  'pigment_seafoam', 'pigment_orchid', 'pigment_ember', 'pigment_twilight',
  'pigment_moss', 'pigment_rose_quartz',
  'ghost_duel_title', 'ghost_duel_paste_hint', 'ghost_duel_start',
  'ghost_duel_bad_code', 'ghost_duel_vs', 'ghost_duel_score',
  'ghost_duel_win', 'ghost_duel_lose', 'ghost_duel_draw',
  'ghost_duel_rematch', 'ghost_duel_copied',
  'mirror_draft_label', 'mirror_draft_tip', 'mirror_draft_no_mirror',
];

/// Ngôn ngữ đã dịch xong 67 key Round 9.
const _done = <String>[
  'en_US', 'vi_VN', 'es_ES', 'fr_FR', 'de_DE', 'pt_BR',
  'zh_CN', 'ja_JP', 'ko_KR', 'ru_RU',
];

/// Chưa dịch — vẫn rơi về tiếng Anh. Không phải lỗi, là việc còn lại.
const _pending = <String>[
  'it_IT', 'id_ID', 'th_TH', 'hi_IN', 'ar_SA', 'tr_TR',
  'nl_NL', 'pl_PL', 'ms_MY', 'uk_UA', 'bn_BD',
];

void main() {
  final keys = AppTranslations().keys;

  test('danh sách key Round 9 không trùng lặp', () {
    expect(_round9Keys.toSet().length, _round9Keys.length);
  });

  test('mọi key Round 9 tồn tại trong bản gốc tiếng Anh', () {
    final en = keys['en_US']!;
    for (final k in _round9Keys) {
      expect(en.containsKey(k), isTrue, reason: 'thiếu "$k" ở en_US');
    }
  });

  group('ngôn ngữ đã dịch: không được rơi về tiếng Anh', () {
    for (final lang in _done.where((l) => l != 'en_US')) {
      test(lang, () {
        final en = keys['en_US']!;
        final m = keys[lang];
        expect(m, isNotNull, reason: 'không có bảng dịch cho $lang');
        for (final k in _round9Keys) {
          expect(m!.containsKey(k), isTrue, reason: '$lang thiếu "$k"');
          expect(m[k]!.trim(), isNotEmpty, reason: '$lang rỗng ở "$k"');
          // Chỉ bắt buộc KHÁC tiếng Anh khi chuỗi gốc có nhiều từ. Từ đơn và
          // viết tắt ("combo", "CT") trùng nhau ở nhiều ngôn ngữ là hợp lệ —
          // ép khác đi là bịa ra bản dịch tệ hơn.
          if (en[k]!.trim().contains(' ')) {
            expect(
              m[k],
              isNot(en[k]),
              reason: '$lang để nguyên chuỗi tiếng Anh cho "$k"',
            );
          }
        }
      });
    }
  });

  test('giữ nguyên placeholder @n/@name/@rule khi dịch', () {
    // Dịch mà làm mất placeholder thì UI hiện chữ thay vì con số.
    final en = keys['en_US']!;
    final pattern = RegExp(r'@[a-z]+');
    for (final lang in _done) {
      final m = keys[lang]!;
      for (final k in _round9Keys) {
        if (!m.containsKey(k)) continue;
        final want = pattern.allMatches(en[k]!).map((x) => x[0]).toSet();
        final got = pattern.allMatches(m[k]!).map((x) => x[0]).toSet();
        expect(got, want, reason: '$lang: "$k" lệch placeholder');
      }
    }
  });

  test('CÔNG KHAI phần còn thiếu — 11 ngôn ngữ vẫn rơi về tiếng Anh', () {
    // Ca này không đỏ; nó tồn tại để con số luôn hiện ra trong output test
    // thay vì bị quên. Dịch xong ngôn ngữ nào thì chuyển từ `_pending` sang
    // `_done`, và ca "không rơi về tiếng Anh" sẽ tự canh nó.
    // `keys` MERGE `_extraEn` vào mọi locale làm fallback, nên `containsKey`
    // luôn true — phải so GIÁ TRỊ mới biết đã dịch hay chưa. (Bản đầu của ca
    // này đếm bằng `containsKey` và ra 0, tưởng đã dịch hết.)
    final en = keys['en_US']!;
    final multiWord = _round9Keys.where((k) => en[k]!.contains(' ')).toList();
    var stillEnglish = 0;
    for (final lang in _pending) {
      final m = keys[lang]!;
      for (final k in multiWord) {
        if (m[k] == en[k]) stillEnglish++;
      }
    }
    expect(_pending.length, 11);
    expect(
      stillEnglish,
      _pending.length * multiWord.length,
      reason: 'nếu số này giảm, có ngôn ngữ đã dịch mà chưa chuyển sang _done',
    );
  });
}

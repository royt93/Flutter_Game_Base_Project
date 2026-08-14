import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/app_translations.dart';

/// Nợ i18n cũ (trước Round 9) — file này vừa **khoá phần đã dọn** vừa **đếm
/// phần còn lại** để nó chỉ có thể giảm.
///
/// Vì sao cần: `app_translations_test.dart` chỉ kiểm mọi ngôn ngữ có ĐỦ key.
/// Nó luôn xanh, kể cả khi bản dịch là chuỗi tiếng Anh y nguyên — vì `keys`
/// merge `_extraEn` vào mọi locale làm fallback. Cách duy nhất phát hiện là
/// **so giá trị** với tiếng Anh, và đó là việc của file này.
///
/// Con số ban đầu: 1022 key tiếng Anh, 2091 ô rơi về tiếng Anh trên 21 locale.
/// Trừ [_kUniversal] (xem dưới) còn 1636 ô là nợ thật.

/// Key được phép giữ nguyên tiếng Anh ở **mọi** ngôn ngữ.
///
/// Không phải nợ: ký hiệu thuần (`'×@n'`, `'@n / @t ★'`), tên riêng (thú
/// cưng, NPC, chòm sao), và từ mượn đã vào ngôn ngữ đích ("Zen", "Combo",
/// "OK", "Menu").
///
/// Danh sách này lấy đúng bằng những key mà **tiếng Việt** — bản dịch đầy đủ
/// nhất repo — cũng để nguyên tiếng Anh. Đó là quyết định đã có sẵn của
/// người dịch, không phải tôi tự phong.
const _kUniversal = <String>{
  'journey_card_combo',
  'zen_title',
  'zen_short',
  'pt_star_cost',
  'pt_gold_cost',
  'rush_time_bonus',
  'ach_combo_5_t',
  'ach_combo_8_t',
  'wheel_got_booster',
  'npc_name_1',
  'npc_name_2',
  'npc_name_3',
  'npc_name_4',
  'npc_name_5',
  'bp_title',
  'bp_joker',
  'rhythm_groove',
  'color_rush_streak',
  'daily_mut_doubleCombo',
  'soda_short',
  'coll_title',
  'pet_ember_name',
  'pet_aqua_name',
  'pet_luna_name',
  'season_pass_title',
  'menu',
  'combo_milestone_label',
  'ok',
  'perfect_clear_title',
  'prestige_title',
  'prestige_confirm',
  'prestige_ready',
  'mode_gauntlet_label',
  'board_frame_neon_cyan',
  'menu_button_label',
  'craft_booster_reward_label',
  'combo_text_style_neon',
  'board_frame_seasonal_halloween',
};

/// Đợt 1 đã dọn: home "Next up", tutorial/FTUE, mẹo cuối màn, second chance,
/// cài đặt âm thanh, Star Pet, HUD.
///
/// `back_button_label` là key MỚI: `NeonBackButton` trước đây hardcode
/// `semanticLabel: 'Quay lại'`, nên TalkBack đọc tiếng Việt cho cả 21 ngôn
/// ngữ khác. Xem `i18n_hardcoded_test.dart`.
const _kDebt1 = <String>[
  'home_next_title',
  'home_next_daily',
  'home_next_spin',
  'home_next_quest',
  'home_next_chest',
  'home_next_season',
  'home_next_weekly',
  'home_next_clan',
  'home_next_level',
  'home_next_empty',
  'tutorial_shop_body',
  'tutorial_booster_body',
  'tutorial_daily_challenge_body',
  'ftue_tap_hint',
  'tip_bigger_groups',
  'tip_no_refill',
  'tip_advice_so_close',
  'tip_advice_bigger_groups',
  'tip_advice_plan_ahead',
  'second_chance_action',
  'second_chance_need_coins',
  'second_chance_hint',
  'settings_skip_tips',
  'bgm_volume',
  'sfx_volume',
  'haptics',
  'pet_equip',
  'pet_equipped',
  'pet_passive_undo',
  'pet_passive_hint',
  'pet_passive_coin',
  'pet_habitat_claim_button',
  'hud_score',
  'hud_target',
  'score_value_label',
  'target_value',
  'game_target_label',
  'btn_home',
  'booster_hint_label',
  'back_button_label',
];

/// `'<key>|<locale>'` mà bản dịch **cố tình** trùng tiếng Anh.
///
/// Từ mượn đã là cách nói bản ngữ: "Level" trong tiếng Đức/Hà Lan/Indonesia/
/// Filipino, "Target" trong tiếng Indonesia/Filipino, "Score" trong tiếng
/// Pháp/Hà Lan, "Home"/"Hint" trong tiếng Ý/Hà Lan/Filipino. Ép dịch khác đi
/// chỉ tạo ra bản dịch tệ hơn.
///
/// Những cặp này bị loại khỏi cả ca "không được rơi về tiếng Anh" lẫn phép
/// đếm nợ — nếu tính vào nợ thì con số không bao giờ về 0 được.
const _kSameAsEnglishOk = <String>{
  'booster_hint_label|nl_NL',
  'btn_home|fil_PH',
  'btn_home|it_IT',
  'btn_home|nl_NL',
  'game_target_label|fil_PH',
  'game_target_label|id_ID',
  'home_next_level|de_DE',
  'home_next_level|fil_PH',
  'home_next_level|id_ID',
  'home_next_level|nl_NL',
  'hud_score|fr_FR',
  'hud_score|nl_NL',
  'hud_target|fil_PH',
  'hud_target|id_ID',
  'score_value_label|fr_FR',
  'score_value_label|nl_NL',
  'target_value|fil_PH',
  'target_value|id_ID',
};

/// Số ô còn rơi về tiếng Anh sau đợt 1 — **chốt một chiều**.
///
/// Ca cuối chỉ cho phép con số này ĐI XUỐNG. Dọn thêm thì hạ hằng số; nếu ai
/// đó thêm key mới mà quên dịch, số vọt lên và test đỏ.
const _kDebtRemaining = 1001;

void main() {
  final keys = AppTranslations().keys;
  final en = keys['en_US']!;
  final locales = keys.keys.where((l) => l != 'en_US').toList();
  final placeholder = RegExp(r'@[a-z]+');

  test('danh sách đợt 1 không trùng lặp và có thật', () {
    expect(_kDebt1.toSet().length, _kDebt1.length);
    for (final k in _kDebt1) {
      expect(en.containsKey(k), isTrue, reason: 'key "$k" không có ở en_US');
    }
  });

  test('_kUniversal không giẫm lên _kDebt1', () {
    // Một key vừa "được phép giữ tiếng Anh" vừa "đã dịch" là mâu thuẫn: ca
    // dưới sẽ đòi dịch, còn phần đếm lại bỏ qua nó.
    expect(_kUniversal.intersection(_kDebt1.toSet()), isEmpty);
  });

  group('đợt 1 đã dịch thật ở mọi ngôn ngữ', () {
    for (final lang in locales) {
      test(lang, () {
        final m = keys[lang]!;
        for (final k in _kDebt1) {
          expect(m.containsKey(k), isTrue, reason: '$lang thiếu "$k"');
          expect(m[k]!.trim(), isNotEmpty, reason: '$lang rỗng ở "$k"');

          expect(
            placeholder.allMatches(m[k]!).map((x) => x[0]).toSet(),
            placeholder.allMatches(en[k]!).map((x) => x[0]).toSet(),
            reason: '$lang: "$k" lệch placeholder — UI sẽ hiện chữ thay vì số',
          );

          // Chuỗi một từ trùng nhau giữa các ngôn ngữ là bình thường
          // ("Score", "Hint"); chỉ soi chuỗi nhiều từ.
          if (en[k]!.trim().contains(' ') &&
              !_kSameAsEnglishOk.contains('$k|$lang')) {
            expect(
              m[k],
              isNot(en[k]),
              reason: '$lang để nguyên tiếng Anh cho "$k"',
            );
          }
        }
      });
    }
  });

  test('mọi mục trong _kSameAsEnglishOk đều còn dùng tới', () {
    // Ngoại lệ chết là ngoại lệ nói dối: nó gợi ý "chỗ này cố tình" trong khi
    // bản dịch đã khác tiếng Anh từ lâu.
    for (final entry in _kSameAsEnglishOk) {
      final parts = entry.split('|');
      expect(parts.length, 2, reason: 'sai định dạng: $entry');
      expect(_kDebt1, contains(parts[0]), reason: '$entry: key ngoài đợt 1');
      expect(
        keys[parts[1]]?[parts[0]],
        en[parts[0]],
        reason: '$entry đã khác tiếng Anh — bỏ khỏi danh sách ngoại lệ',
      );
    }
  });

  test('nợ còn lại chỉ được giảm', () {
    var debt = 0;
    for (final lang in locales) {
      final m = keys[lang]!;
      for (final k in en.keys) {
        if (_kUniversal.contains(k)) continue;
        if (_kSameAsEnglishOk.contains('$k|$lang')) continue;
        if (m[k] == en[k]) debt++;
      }
    }
    expect(
      debt,
      lessThanOrEqualTo(_kDebtRemaining),
      reason: 'nợ i18n tăng lên $debt — thêm key mới thì dịch luôn 21 locale',
    );
    // Bám sát: dọn xong thì hạ hằng số, đừng để nó nới rộng dần thành vô nghĩa.
    expect(
      debt,
      greaterThanOrEqualTo(_kDebtRemaining - 40),
      reason: 'nợ giảm còn $debt — hạ _kDebtRemaining xuống đúng con số này',
    );
  });
}

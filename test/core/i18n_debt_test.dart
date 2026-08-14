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
///
/// Đường đi: **1636 → 1001 (đợt 1) → 289 (đợt 2) → 0 (đợt 3)**.
///
/// Về 0 không có nghĩa "mọi chuỗi đều khác tiếng Anh". Nó có nghĩa: mọi ô
/// trùng tiếng Anh đều đã được khai báo — hoặc ở [_kUniversal] (đúng ở mọi
/// ngôn ngữ), hoặc ở [_kSameAsEnglishOk] (từ mượn, đúng ở ngôn ngữ cụ thể
/// đó). Không còn ô nào trùng vì bị bỏ quên.

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

/// Đợt 2 đã dọn: mục tiêu màn (`obj_*`), vòng quay, chuỗi chia sẻ, Ghost, và
/// 13 tên thế giới.
///
/// `world_path_name_*` hiện ngay trên Mode Select bằng tiếng Anh giữa màn
/// hình đã dịch hết — bộ tên cũ `world_name_*` thì đã dịch đủ, nên đây là bỏ
/// sót lúc đổi chủ đề sang kẹo.
const _kDebt2 = <String>[
  'ghost_hud',
  'ghost_play',
  'invite_friend_share_msg',
  'obj_bonus_star_moves',
  'obj_break_ice',
  'obj_clear_color',
  'obj_collect',
  'obj_finish_bonus_star',
  'obj_open_gift',
  'pigment_fusion_only',
  'rush_title',
  'rush_short',
  'zen_no_target',
  'coop_mode',
  'versus_mode',
  'share_board_text',
  'share_score_card_text',
  'share_challenge_text',
  'share_replay_text',
  'spin_already_msg',
  'spin_result_msg',
  'spin_reward_coins',
  'spin_spinning',
  'world_path_name_1',
  'world_path_name_2',
  'world_path_name_3',
  'world_path_name_4',
  'world_path_name_5',
  'world_path_name_6',
  'world_path_name_7',
  'world_path_name_8',
  'world_path_name_9',
  'world_path_name_10',
  'world_path_name_11',
  'world_path_name_12',
  'world_path_name_13',
];

/// Đợt 3 đã dọn: phần đuôi — danh từ ngắn rải rác 1-11 ngôn ngữ (boss,
/// mùa, battle pass, thành tựu, chòm sao, tên skin, tiêu đề màn hình).
///
/// Hơn nửa số ô của đợt này KHÔNG dịch: chúng là từ mượn trùng khít tiếng
/// Anh ở đúng ngôn ngữ đó — "Retro" tiếng Đức, "Inferno" tiếng Ý,
/// "Champion" tiếng Pháp, "Portal" tiếng Ba Lan. Đó là cái đuôi tự nhiên
/// của một khoản nợ dịch thuật, và chúng nằm ở [_kSameAsEnglishOk].
const _kDebt3 = <String>[
  'boss_rush_title',
  'mode_boss_rush_label',
  'boss_short',
  'boss_atk_meteor',
  'boss_atk_block',
  'boss_phase',
  'boss_hp',
  'boss_stage',
  'boss_title',
  'boss_rush_start_button',
  'raid_boss_title',
  'raid_boss_name',
  'guide_rule_boss_title',
  'skin_aurora_name',
  'skin_obsidian_name',
  'skin_ruby_name',
  'skin_emerald_name',
  'skin_sapphire_name',
  'combo_text_style_retro',
  'combo_text_style_bold_pop',
  'burst_style_confetti',
  'combo_token_short',
  'versus_p1',
  'versus_p2',
  'versus_go',
  'pigment_aqua',
  'pigment_coral',
  'pigment_mint',
  'pigment_midnight',
  'pigment_sunset',
  'portal_title',
  'clan_title',
  'dispenser_title',
  'conveyor_title',
  'labyrinth_short',
  'obstacle_jam',
  'bomb_timer',
  'ach_streak_12_t',
  'ach_wins_30_t',
  'ach_wins_60_t',
  'ach_stars_300_t',
  'quest_win',
  'ach_gems_500_title',
  'ach_gems_500_desc',
  'ach_gems_2000_title',
  'ach_gems_2000_desc',
  'ach_gems_10000_title',
  'ach_gems_10000_desc',
  'ach_gems_50000_title',
  'ach_gems_50000_desc',
  'achievement_unlocked_title',
  'achievements_title',
  'achievements_done',
  'pt_ascendant_title',
  'pt_prestige_title',
  'trophy_room_prestige_section',
  'trophy_room_mascots_section',
  'rhythm_short',
  'rhythm_title',
  'guide_rhythm_title',
  'endless_short',
  'endless_over',
  'color_rush_title',
  'color_rush_short',
  'survival_title',
  'survival_short',
  'gravity_title',
  'gravity_short',
  'mode_time_attack_label',
  'mode_zen_label',
  'bp_level',
  'bp_royal',
  'bp_color',
  'bp_gravity',
  'bp_shards',
  'bp_track',
  'season_pts_short',
  'season_magenta',
  'season_amber',
  'season_cyan',
  'season_lime',
  'season_violet',
  'season_points',
  'season_title',
  'rec_tier_bronze',
  'rec_tier_gold',
  'rec_tier_platinum',
  'puzzle_no',
  'puzzle_short',
  'puzzle_title',
  'puzzle_target',
  'puzzle_lab_title',
  'puzzle_lab_score_label',
  'constellation_dragon',
  'constellation_pegasus',
  'constellation_phoenix',
  'constellation_serpent',
  'drawer_login_streak_label',
  'login_streak_title',
  'drawer_milestone_journal_label',
  'milestone_journal_title',
  'ghost_replay_title',
  'duel_title',
  'duel_scores',
  'alchemy_reset',
  'alchemy_slot',
  'board_frame_treasure_relic',
  'board_frame_unlock_seasonal',
  'cc_side_weekly_claim',
  'guide_combo_title',
  'guide_obstacle_title',
  'home_weekend_badge',
  'home_weekend_banner',
  'journey_card_level',
  'perfect_clear_start',
  'perfect_clear_success_label',
  'quick_level1',
  'score_value',
  'shop_title',
  'shop_upgrades',
  'sky_shrine_aura_active',
  'upg_hammer',
  'world_name_10',
];

/// Mọi key đã dọn, gộp lại — các ca dưới chạy trên tập này.
const _kDone = <String>[..._kDebt1, ..._kDebt2, ..._kDebt3];

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
  'ach_stars_300_t|nl_NL',
  'ach_streak_12_t|de_DE',
  'ach_streak_12_t|id_ID',
  'ach_streak_12_t|it_IT',
  'ach_streak_12_t|nl_NL',
  'ach_streak_12_t|pt_BR',
  'ach_wins_30_t|de_DE',
  'ach_wins_30_t|id_ID',
  'ach_wins_30_t|ms_MY',
  'ach_wins_60_t|de_DE',
  'ach_wins_60_t|fr_FR',
  'alchemy_reset|nl_NL',
  'bomb_timer|de_DE',
  'bomb_timer|fil_PH',
  'bomb_timer|it_IT',
  'bomb_timer|nl_NL',
  'booster_hint_label|nl_NL',
  'boss_atk_meteor|de_DE',
  'boss_atk_meteor|fil_PH',
  'boss_atk_meteor|id_ID',
  'boss_atk_meteor|ms_MY',
  'boss_atk_meteor|pl_PL',
  'boss_atk_meteor|tr_TR',
  'boss_phase|de_DE',
  'boss_phase|fr_FR',
  'boss_short|de_DE',
  'boss_short|fil_PH',
  'boss_short|fr_FR',
  'boss_short|it_IT',
  'boss_short|nl_NL',
  'boss_short|pl_PL',
  'boss_short|tr_TR',
  'bp_color|es_ES',
  'bp_level|de_DE',
  'bp_level|fil_PH',
  'bp_level|id_ID',
  'bp_level|nl_NL',
  'bp_royal|fr_FR',
  'btn_home|fil_PH',
  'btn_home|it_IT',
  'btn_home|nl_NL',
  'burst_style_confetti|fil_PH',
  'burst_style_confetti|nl_NL',
  'clan_title|de_DE',
  'clan_title|es_ES',
  'clan_title|fil_PH',
  'clan_title|fr_FR',
  'clan_title|it_IT',
  'clan_title|nl_NL',
  'combo_text_style_retro|de_DE',
  'combo_text_style_retro|es_ES',
  'combo_text_style_retro|fil_PH',
  'combo_text_style_retro|id_ID',
  'combo_text_style_retro|it_IT',
  'combo_text_style_retro|ms_MY',
  'combo_text_style_retro|nl_NL',
  'combo_text_style_retro|pl_PL',
  'combo_text_style_retro|tr_TR',
  'combo_token_short|ar_SA',
  'combo_token_short|bn_BD',
  'combo_token_short|fil_PH',
  'combo_token_short|hi_IN',
  'combo_token_short|ja_JP',
  'combo_token_short|ko_KR',
  'combo_token_short|th_TH',
  'conveyor_title|fil_PH',
  'dispenser_title|fil_PH',
  'dispenser_title|id_ID',
  'dispenser_title|nl_NL',
  'game_target_label|fil_PH',
  'game_target_label|id_ID',
  'guide_obstacle_title|fr_FR',
  'home_next_level|de_DE',
  'home_next_level|fil_PH',
  'home_next_level|id_ID',
  'home_next_level|nl_NL',
  'hud_score|fr_FR',
  'hud_score|nl_NL',
  'hud_target|fil_PH',
  'hud_target|id_ID',
  'journey_card_level|fil_PH',
  'journey_card_level|id_ID',
  'journey_card_level|nl_NL',
  'labyrinth_short|de_DE',
  'obstacle_jam|nl_NL',
  'perfect_clear_start|nl_NL',
  'perfect_clear_start|pl_PL',
  'pigment_aqua|de_DE',
  'pigment_aqua|fil_PH',
  'pigment_aqua|fr_FR',
  'pigment_aqua|id_ID',
  'pigment_aqua|ms_MY',
  'pigment_aqua|nl_NL',
  'pigment_coral|es_ES',
  'pigment_coral|fil_PH',
  'pigment_coral|pt_BR',
  'pigment_mint|fil_PH',
  'pigment_mint|id_ID',
  'portal_title|de_DE',
  'portal_title|es_ES',
  'portal_title|fil_PH',
  'portal_title|id_ID',
  'portal_title|ms_MY',
  'portal_title|pl_PL',
  'portal_title|pt_BR',
  'portal_title|tr_TR',
  'pt_ascendant_title|fr_FR',
  'pt_ascendant_title|nl_NL',
  'pt_prestige_title|de_DE',
  'pt_prestige_title|fr_FR',
  'pt_prestige_title|nl_NL',
  'puzzle_lab_score_label|fr_FR',
  'puzzle_lab_score_label|nl_NL',
  'puzzle_target|fil_PH',
  'puzzle_target|id_ID',
  'quick_level1|de_DE',
  'quick_level1|id_ID',
  'quick_level1|nl_NL',
  'raid_boss_name|fil_PH',
  'raid_boss_name|nl_NL',
  'raid_boss_name|tr_TR',
  'rec_tier_bronze|de_DE',
  'rec_tier_bronze|fr_FR',
  'rec_tier_bronze|pt_BR',
  'rec_tier_gold|de_DE',
  'rec_tier_platinum|fil_PH',
  'rec_tier_platinum|id_ID',
  'rec_tier_platinum|ms_MY',
  'score_value_label|fr_FR',
  'score_value_label|nl_NL',
  'score_value|nl_NL',
  'season_pts_short|es_ES',
  'season_pts_short|fil_PH',
  'season_pts_short|fr_FR',
  'season_pts_short|pt_BR',
  'share_board_text|nl_NL',
  'share_score_card_text|nl_NL',
  'shop_title|de_DE',
  'shop_upgrades|nl_NL',
  'skin_aurora_name|de_DE',
  'skin_aurora_name|es_ES',
  'skin_aurora_name|fil_PH',
  'skin_aurora_name|id_ID',
  'skin_aurora_name|it_IT',
  'skin_aurora_name|ms_MY',
  'skin_aurora_name|nl_NL',
  'skin_aurora_name|pl_PL',
  'skin_aurora_name|pt_BR',
  'skin_aurora_name|tr_TR',
  'skin_obsidian_name|de_DE',
  'skin_obsidian_name|fil_PH',
  'skin_obsidian_name|id_ID',
  'skin_obsidian_name|ms_MY',
  'target_value|fil_PH',
  'target_value|id_ID',
  'trophy_room_mascots_section|fr_FR',
  'trophy_room_prestige_section|de_DE',
  'trophy_room_prestige_section|fr_FR',
  'trophy_room_prestige_section|nl_NL',
  'upg_hammer|de_DE',
  'versus_mode|es_ES',
  'versus_mode|pt_BR',
  'versus_p1|bn_BD',
  'versus_p1|fil_PH',
  'versus_p1|hi_IN',
  'versus_p1|id_ID',
  'versus_p1|ja_JP',
  'versus_p1|ms_MY',
  'versus_p1|th_TH',
  'versus_p2|bn_BD',
  'versus_p2|fil_PH',
  'versus_p2|hi_IN',
  'versus_p2|id_ID',
  'versus_p2|ja_JP',
  'versus_p2|ms_MY',
  'versus_p2|th_TH',
};

/// Số ô còn rơi về tiếng Anh mà **chưa được khai báo** — nay là 0.
///
/// Giữ hằng số (thay vì viết thẳng `isZero`) để lần sau có ai thêm một đợt
/// key mới chưa dịch xong, họ có chỗ ghi con số tạm thời thay vì xoá cả ca.
const _kDebtRemaining = 0;

void main() {
  final keys = AppTranslations().keys;
  final en = keys['en_US']!;
  final locales = keys.keys.where((l) => l != 'en_US').toList();
  final placeholder = RegExp(r'@[a-z]+');

  test('danh sách key đã dọn không trùng lặp và có thật', () {
    expect(_kDone.toSet().length, _kDone.length);
    for (final k in _kDone) {
      expect(en.containsKey(k), isTrue, reason: 'key "$k" không có ở en_US');
    }
  });

  test('_kUniversal không giẫm lên danh sách đã dọn', () {
    // Một key vừa "được phép giữ tiếng Anh" vừa "đã dịch" là mâu thuẫn: ca
    // dưới sẽ đòi dịch, còn phần đếm lại bỏ qua nó.
    expect(_kUniversal.intersection(_kDone.toSet()), isEmpty);
  });

  group('key đã dọn phải dịch thật ở mọi ngôn ngữ', () {
    for (final lang in locales) {
      test(lang, () {
        final m = keys[lang]!;
        for (final k in _kDone) {
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
      expect(_kDone, contains(parts[0]), reason: '$entry: key chưa được dọn');
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
      reason:
          'nợ i18n tăng lên $debt — mỗi ô là một chuỗi đang hiện tiếng Anh '
          'cho người dùng ngôn ngữ khác. Dịch nó, hoặc nếu đó là từ mượn '
          'đúng ở ngôn ngữ đó thì khai vào _kSameAsEnglishOk kèm lý do.',
    );
    // Bám sát: dọn xong thì hạ hằng số, đừng để nó nới rộng dần thành vô nghĩa.
    expect(
      debt,
      greaterThanOrEqualTo(_kDebtRemaining),
      reason: 'nợ giảm còn $debt — hạ _kDebtRemaining xuống đúng con số này',
    );
  });
}

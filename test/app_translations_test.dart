import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/core/app_translations.dart';

void main() {
  final t = AppTranslations();
  final keys = t.keys;

  group('AppTranslations — tính toàn vẹn', () {
    test('English (en_US) là ngôn ngữ default đầu tiên', () {
      expect(AppTranslations.supported.first, const Locale('en', 'US'));
      expect(AppTranslations.fallback, const Locale('en', 'US'));
    });

    test('mọi locale hỗ trợ đều có bảng dịch', () {
      for (final l in AppTranslations.supported) {
        expect(
          keys.containsKey(AppTranslations.codeOf(l)),
          isTrue,
          reason: 'thiếu bảng dịch cho ${AppTranslations.codeOf(l)}',
        );
      }
    });

    test('mọi ngôn ngữ có ĐỦ key giống English (không thiếu/dư)', () {
      final enKeys = keys['en_US']!.keys.toSet();
      for (final entry in keys.entries) {
        final langKeys = entry.value.keys.toSet();
        expect(
          langKeys,
          enKeys,
          reason: 'ngôn ngữ ${entry.key} có tập key khác English',
        );
      }
    });

    test('không có giá trị rỗng', () {
      for (final entry in keys.entries) {
        for (final kv in entry.value.entries) {
          expect(
            kv.value.trim().isNotEmpty,
            isTrue,
            reason: '${entry.key}/${kv.key} bị rỗng',
          );
        }
      }
    });

    test('placeholder @count / @value / @n được giữ nguyên khi dịch', () {
      expect(keys['en_US']!['levels_tagline']!.contains('@count'), isTrue);
      expect(keys['vi_VN']!['levels_tagline']!.contains('@count'), isTrue);
      expect(keys['vi_VN']!['score_value']!.contains('@value'), isTrue);
      expect(keys['vi_VN']!['stage_n']!.contains('@n'), isTrue);
    });

    test('mọi placeholder @... phải khớp English cho mọi locale', () {
      final placeholder = RegExp(r'@[A-Za-z_][A-Za-z0-9_]*');
      final en = keys['en_US']!;
      for (final entry in keys.entries) {
        if (entry.key == 'en_US') continue;
        for (final k in en.keys) {
          final expected = placeholder
              .allMatches(en[k]!)
              .map((m) => m.group(0)!)
              .toSet();
          final actual = placeholder
              .allMatches(entry.value[k]!)
              .map((m) => m.group(0)!)
              .toSet();
          expect(
            actual,
            expected,
            reason: '${entry.key}/$k placeholder mismatch',
          );
        }
      }
    });

    test('Challenge Card side-mode labels không rơi về raw i18n key', () {
      const modeKeys = {
        'endless_short',
        'boss_short',
        'rhythm_short',
        'gravity_short',
        'soda_short',
        'color_rush_short',
      };
      for (final locale in ['en_US', 'vi_VN']) {
        for (final k in modeKeys) {
          expect(keys[locale]![k], isNot(k), reason: '$locale/$k chưa dịch');
        }
      }
    });

    test('mỗi locale hỗ trợ có tên hiển thị (native name)', () {
      for (final l in AppTranslations.supported) {
        expect(
          AppTranslations.languageNames[AppTranslations.codeOf(l)],
          isNotNull,
        );
      }
    });

    test('key Wave 4 đã dịch thật (không còn fallback English)', () {
      // mẫu vài ngôn ngữ: hud_time KHÁC bản English 'TIME'
      expect(keys['es_ES']!['hud_time'], 'Tiempo');
      expect(keys['de_DE']!['hud_time'], 'Zeit');
      expect(keys['ja_JP']!['daily_title'], 'デイリーボーナス');
      expect(keys['ru_RU']!['buy'], 'Купить');
      expect(keys['ar_SA']!['lives_label'], 'الأرواح');
      // placeholder vẫn còn trong bản dịch
      expect(keys['fr_FR']!['lives_buy_msg']!.contains('@n'), isTrue);
      expect(keys['th_TH']!['lives_next']!.contains('@t'), isTrue);
    });

    // ── Chống hồi quy lỗ hổng i18n (Wave 8.9): trước đây 20 ngôn ngữ chỉ ~50%
    // key được dịch (Wave 5/7/8/9 fallback English). Test cũ chỉ kiểm KEY đủ
    // (qua fallback merge) nên KHÔNG phát hiện. 2 test dưới kiểm VALUE đã dịch.
    test(
      'mỗi ngôn ngữ phải dịch ≥80% value (không fallback English hàng loạt)',
      () {
        final en = keys['en_US']!;
        for (final entry in keys.entries) {
          if (entry.key == 'en_US') continue;
          var diff = 0;
          entry.value.forEach((k, v) {
            if (v.trim() != en[k]?.trim()) diff++;
          });
          // M4 fix: loại trừ "universal gaming terms" khỏi tính tỉ lệ dịch —
          // những key này intentionally giữ nguyên English (ZEN, GHOST, ★ format).
          // W23.1: key W21.6+W22 ĐÃ localize 20 ngôn ngữ (_w22ByLang) → KHÔNG còn
          // loại trừ; chúng tính vào ratio như mọi key khác.
          const universalKeys = {
            'zen_title',
            'zen_short',
            'ghost_play',
            'ghost_hud',
            'pt_star_cost',
            'pt_gold_cost',
          };
          final adjustedTotal =
              entry.value.length -
              entry.value.keys.where(universalKeys.contains).length;
          final ratio = adjustedTotal > 0 ? diff / adjustedTotal : 1.0;
          expect(
            ratio,
            greaterThanOrEqualTo(0.80),
            reason:
                '${entry.key} chỉ dịch ${(ratio * 100).toStringAsFixed(1)}% '
                '— nghi fallback English (thêm feature mới mà quên dịch?)',
          );
        }
      },
    );

    test('key Wave 5/7/8/9 đã dịch thật cho 20 ngôn ngữ (mẫu)', () {
      // Các key mô tả/UI tiêu biểu (không phải tên riêng) phải KHÁC bản English.
      const sampleKeys = [
        'achievements',
        'win_streak',
        'tut_1',
        'season_hint',
        'boss_hp',
        'temple_tier',
        'quest_win',
        'ach_claim',
        'bp_track',
        'guide_versus_body',
      ];
      const langs = [
        'es_ES',
        'de_DE',
        'ru_RU',
        'zh_CN',
        'ja_JP',
        'ko_KR',
        'ar_SA',
        'th_TH',
        'hi_IN',
        'uk_UA',
        'bn_BD',
      ];
      final en = keys['en_US']!;
      for (final k in sampleKeys) {
        for (final lang in langs) {
          expect(
            keys[lang]![k],
            isNot(en[k]),
            reason: '$lang/$k còn dùng English (chưa dịch Wave 5/7/8/9)',
          );
        }
      }
      // placeholder vẫn giữ nguyên sau khi dịch
      expect(keys['ru_RU']!['streak_bonus']!.contains('@n'), isTrue);
      expect(keys['bn_BD']!['daily_ch_reward']!.contains('@c'), isTrue);
    });

    // ── Chống hồi quy W18.2/18.3: Album set reward + Achievement title + Upgrades
    // đã dịch thật (không fallback English) cho các ngôn ngữ đại diện.
    test('key W18.2/18.3 đã dịch thật cho 20 ngôn ngữ (mẫu)', () {
      const sampleW18Keys = [
        'coll_set_title', // "Album Complete!" → ngôn ngữ rõ ràng khác
        'ach_equip', // "Equip" → đeo / equipped → tên hành động khác nhau
        'shop_upgrades', // "Upgrades" → nâng cấp / Mejoras / Verbesserungen…
        'coll_set_reward', // Có placeholder @n — check dưới; value sẽ khác
        'upg_hammer_desc', // "Smash a 3×3 area" → mô tả đủ dài để dịch khác
      ];
      const langs = [
        'es_ES',
        'de_DE',
        'ru_RU',
        'zh_CN',
        'ja_JP',
        'ar_SA',
        'th_TH',
        'uk_UA',
        'bn_BD',
        'ko_KR',
      ];
      final en = keys['en_US']!;
      for (final lang in langs) {
        for (final k in sampleW18Keys) {
          // Mỗi key phải có giá trị khác English → chứng tỏ đã dịch
          expect(
            keys[lang]![k],
            isNot(en[k]),
            reason: '$lang/$k còn dùng English (W18.2/18.3 chưa dịch)',
          );
        }
      }
      // Placeholder @n giữ nguyên trong bản dịch
      expect(keys['de_DE']!['coll_set_reward']!.contains('@n'), isTrue);
      expect(keys['ja_JP']!['coll_set_reward']!.contains('@n'), isTrue);
    });

    // ── Chống hồi quy W27.3: 6 sticker cuối đổi tên từ thuật ngữ khó hiểu
    // (prism_shard, nebula_core, ...) sang tên + mô tả rõ nghĩa hơn. Audit
    // phát hiện ZERO test cho các key coll_prism_shard.../coll_desc_...
    // dù bản dịch tồn tại ở app_translations.dart — nếu ai đó thêm key mới
    // mà quên dịch, không test nào bắt được. Test dưới kiểm TOÀN BỘ 22
    // ngôn ngữ (không chỉ mẫu) vì đây là rename gần đây, rủi ro sót cao hơn.
    test(
      'W27.3: 6 tên sticker mới (coll_prism_shard..coll_singularity) và mô tả '
      'đã dịch thật cho TẤT CẢ ngôn ngữ hỗ trợ (không rơi về English)',
      () {
        const renamedIds = [
          'prism_shard',
          'nebula_core',
          'aurora_wing',
          'quasar_eye',
          'pulsar_heart',
          'singularity',
        ];
        final en = keys['en_US']!;
        for (final entry in keys.entries) {
          if (entry.key == 'en_US') continue;
          for (final id in renamedIds) {
            for (final k in ['coll_$id', 'coll_desc_$id']) {
              expect(
                entry.value[k],
                isNot(en[k]),
                reason:
                    '${entry.key}/$k còn dùng English (W27.3 rename chưa dịch)',
              );
            }
          }
        }
      },
    );

    // ── Chống hồi quy W27.2: 2050 giá trị ALL-CAPS ("CHƠI NGAY", "REWARDS"...)
    // đã đổi Title Case. 0 test khoá lại kết quả — ai đó `.toUpperCase()`
    // 1 giá trị mới hoặc dịch thêm bằng ALL-CAPS sẽ lọt qua im lặng. Test dưới
    // quét TOÀN BỘ giá trị en_US + vi_VN, báo lỗi nếu là chữ hoa toàn bộ
    // (≥3 ký tự chữ cái). Chỉ dùng bảng chữ cái Latin/Việt tường minh (không
    // dùng range Unicode À-Ỹ) vì range đó vô tình trùng khối Cyrillic/Devanagari/
    // Thái → false-positive nếu quét ngôn ngữ khác.
    test('W27.2: en_US + vi_VN không còn giá trị ALL-CAPS (regression)', () {
      final upperVi =
          'ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬÈÉẺẼẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢ'
          'ÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴĐ';
      final allCapsEn = RegExp(r"^[A-Z0-9 ·!?'\-]+$");
      final allCapsVi = RegExp("^[A-Z0-9 ·!?'\\-$upperVi]+\$");
      // acronym/tên riêng cố ý giữ nguyên chữ hoa (không phải bug ALL-CAPS câu).
      const allowlist = {'Zen', 'Ghost'};
      void checkNoAllCaps(Map<String, String> m, RegExp re, String tag) {
        for (final entry in m.entries) {
          final v = entry.value.trim();
          final letters = v.replaceAll(RegExp('[^A-Za-z$upperVi]'), '');
          if (letters.length < 3) continue; // quá ngắn, có thể là acronym
          if (allowlist.contains(v)) continue;
          final isAllCaps = re.hasMatch(v) && v != v.toLowerCase();
          expect(
            isAllCaps,
            isFalse,
            reason: '$tag/${entry.key} = "$v" vẫn ALL-CAPS (W27.2 hồi quy)',
          );
        }
      }

      checkNoAllCaps(keys['en_US']!, allCapsEn, 'en_US');
      checkNoAllCaps(keys['vi_VN']!, allCapsVi, 'vi_VN');
    });
    // ── Vá điểm mù (i18n Wave 4 gap): test ≥80% ở trên tính tỉ lệ trên TOÀN
    // BỘ key mọi wave, nên phần Wave 4 (_extraEn, 432 key: rule_/tutorial/
    // leaderboard/chest/quest/clan/boss_type/ach_desc_...) từng chỉ dịch ~5%
    // cho 20 ngôn ngữ mà vẫn PASS vì bị pha loãng bởi các wave khác đã dịch
    // đủ. Test dưới scoped CHÍNH XÁC vào danh sách 432 key Wave 4 (liệt kê
    // tường minh, không phụ thuộc dòng nguồn) và assert riêng ≥95%.
    test(
      'key Wave 4 (_extraEn, 432 key) dịch ≥95% cho từng ngôn ngữ (không pha loãng)',
      () {
        const wave4Keys = [
          'rule_boss',
          'rule_rhythm',
          'rule_survival',
          'rule_labyrinth',
          'rule_color_rush',
          'rule_soda',
          'rule_endless',
          'rule_daily',
          'rule_puzzle',
          'rule_zen',
          'rule_gravity',
          'rule_rush',
          'leaderboard_title',
          'lb_tab_campaign',
          'lb_tab_daily',
          'lb_level',
          'lb_player',
          'lb_daily_note',
          'reduce_motion',
          'tour_t0',
          'tour_m0',
          'tour_t1',
          'tour_m1',
          'tour_t2',
          'tour_m2',
          'tour_t3',
          'tour_m3',
          'tour_skip',
          'tour_next',
          'tour_done',
          'chest_reward_title',
          'chest_got_coins',
          'chest_got_hammer',
          'chest_got_moves',
          'chest_ok',
          'quest_bonus_title',
          'clan_title',
          'clan_goal',
          'clan_goal_hint',
          'clan_league',
          'boss_atk_block',
          'boss_atk_shuffle',
          'boss_atk_meteor',
          'boss_type_pulse',
          'boss_type_void',
          'ach_desc_clanContribTotal',
          'ach_clan_contrib1_t',
          'ach_clan_contrib2_t',
          'ach_desc_platinumMilestones',
          'ach_platinum_1_t',
          'ach_platinum_4_t',
          'ach_platinum_9_t',
          'zen_title',
          'zen_short',
          'zen_best',
          'ghost_play',
          'ghost_hud',
          'ghost_no_data',
          'pt_title',
          'pt_radiant_title',
          'pt_radiant_desc',
          'pt_blazing_title',
          'pt_blazing_desc',
          'pt_prestige_title',
          'pt_prestige_desc',
          'pt_ascendant_title',
          'pt_ascendant_desc',
          'pt_unlocked',
          'pt_star_cost',
          'pt_gold_cost',
          'cc_title',
          'cc_win_campaign',
          'cc_earn_coins',
          'cc_play_mode',
          'cc_reach_tier',
          'cc_side_weekly_title',
          'cc_side_weekly_claim',
          'cc_claim',
          'rush_title',
          'rush_short',
          'rush_desc',
          'rush_best',
          'rush_time_bonus',
          'endless_short',
          'boss_short',
          'rhythm_short',
          'gravity_short',
          'world_name_6',
          'world_name_7',
          'world_name_8',
          'world_name_9',
          'world_name_10',
          'survival_short',
          'survival_title',
          'survival_over',
          'survival_best',
          'labyrinth_short',
          'labyrinth_title',
          'labyrinth_hud',
          'bomb_left',
          'bomb_timer',
          'guide_w10_title',
          'guide_lightball',
          'guide_lightball_desc',
          'guide_bombdown',
          'guide_bombdown_desc',
          'guide_order',
          'guide_order_desc',
          'shop_title',
          'shop_skins',
          'shop_themes',
          'shop_equip',
          'shop_equipped',
          'hud_time',
          'hud_tide',
          'daily_title',
          'daily_claim',
          'daily_claimed',
          'daily_day',
          'daily_got',
          'daily_badge',
          'lives_label',
          'lives_none_title',
          'lives_none_msg',
          'lives_next',
          'lives_full',
          'lives_buy_title',
          'lives_buy_msg',
          'buy',
          'not_enough_coins',
          'guide_mode_time',
          'guide_mode_drop',
          'guide_mode_obstacle',
          'guide_obstacle_title',
          'guide_obstacle_body',
          'world_n',
          'achievements',
          'ach_claim',
          'ach_claimed',
          'win_streak',
          'streak_bonus',
          'ach_desc_totalWins',
          'ach_desc_totalStars',
          'ach_desc_bestCombo',
          'ach_desc_bestWinStreak',
          'ach_desc_unlockedLevel',
          'ach_desc_coinsEarned',
          'ach_first_win_t',
          'ach_wins_10_t',
          'ach_wins_30_t',
          'ach_stars_30_t',
          'ach_stars_90_t',
          'ach_combo_5_t',
          'ach_combo_8_t',
          'ach_streak_3_t',
          'ach_streak_7_t',
          'ach_world_2_t',
          'ach_world_5_t',
          'ach_rich_t',
          'ach_wins_60_t',
          'ach_wins_100_t',
          'ach_stars_180_t',
          'ach_stars_300_t',
          'ach_combo_12_t',
          'ach_streak_12_t',
          'ach_rich_5000_t',
          'wheel_title',
          'wheel_spin',
          'wheel_done',
          'wheel_got_booster',
          'tut_title',
          'tut_1',
          'tut_2',
          'tut_3',
          'tut_next',
          'tut_skip',
          'tut_start',
          'tut_swipe_hint',
          'pregame_title',
          'pregame_msg',
          'pregame_moves',
          'pregame_hammer',
          'pregame_skip',
          'world_map',
          'grid_view',
          'endless_title',
          'endless_over',
          'endless_best',
          'hud_stage',
          'world_name_1',
          'world_name_2',
          'world_name_3',
          'world_name_4',
          'world_name_5',
          'npc_name_1',
          'npc_name_2',
          'npc_name_3',
          'npc_name_4',
          'npc_name_5',
          'guide_story_title',
          'guide_story_body',
          'story_w1_intro_title',
          'story_w1_intro_l1',
          'story_w1_intro_l2',
          'story_w1_mid_title',
          'story_w1_mid_l1',
          'story_w1_mid_l2',
          'story_w1_outro_title',
          'story_w1_outro_l1',
          'story_w1_outro_l2',
          'story_w2_intro_title',
          'story_w2_intro_l1',
          'story_w2_intro_l2',
          'story_w2_mid_title',
          'story_w2_mid_l1',
          'story_w2_mid_l2',
          'story_w2_outro_title',
          'story_w2_outro_l1',
          'story_w2_outro_l2',
          'story_w3_intro_title',
          'story_w3_intro_l1',
          'story_w3_intro_l2',
          'story_w3_mid_title',
          'story_w3_mid_l1',
          'story_w3_mid_l2',
          'story_w3_outro_title',
          'story_w3_outro_l1',
          'story_w3_outro_l2',
          'story_w4_intro_title',
          'story_w4_intro_l1',
          'story_w4_intro_l2',
          'story_w4_mid_title',
          'story_w4_mid_l1',
          'story_w4_mid_l2',
          'story_w4_outro_title',
          'story_w4_outro_l1',
          'story_w4_outro_l2',
          'story_w5_intro_title',
          'story_w5_intro_l1',
          'story_w5_intro_l2',
          'story_w5_mid_title',
          'story_w5_mid_l1',
          'story_w5_mid_l2',
          'story_w5_outro_title',
          'story_w5_outro_l1',
          'story_w5_outro_l2',
          'story_next',
          'story_skip',
          'story_done',
          'temple_title',
          'temple_progress',
          'temple_tier',
          'temple_build',
          'temple_built',
          'temple_maxed',
          'temple_hint',
          'coins_short',
          'temple_gate',
          'temple_gate_desc',
          'temple_pillar',
          'temple_pillar_desc',
          'temple_altar',
          'temple_altar_desc',
          'temple_spire',
          'temple_spire_desc',
          'temple_core',
          'temple_core_desc',
          'bp_title',
          'bp_level',
          'bp_track',
          'bp_shards',
          'bp_hammer',
          'bp_moves',
          'bp_color',
          'bp_joker',
          'bp_lightning',
          'bp_royal',
          'bp_gravity',
          'quest_daily',
          'quest_win',
          'quest_play',
          'quest_coins',
          'quest_combo',
          'quest_stars',
          'season_title',
          'season_ends',
          'season_points',
          'season_pts_short',
          'season_hint',
          'season_cyan',
          'season_magenta',
          'season_lime',
          'season_amber',
          'season_violet',
          'boss_title',
          'boss_hp',
          'boss_weak',
          'boss_stage',
          'boss_phase',
          'gravity_title',
          'rhythm_title',
          'rhythm_groove',
          'rhythm_onbeat',
          'rhythm_offbeat',
          'guide_rhythm_title',
          'guide_rhythm_body',
          'versus_title',
          'versus_pick',
          'versus_mode',
          'versus_mode_desc',
          'coop_mode',
          'coop_mode_desc',
          'versus_p1',
          'versus_p2',
          'versus_p1_win',
          'versus_p2_win',
          'versus_draw',
          'coop_win',
          'coop_lose',
          'coop_goal',
          'versus_go',
          'guide_versus_title',
          'guide_versus_body',
          'challenge_modes',
          'meta_section',
          'daily_ch_title',
          'daily_ch_sub',
          'daily_ch_done',
          'daily_ch_streak',
          'daily_ch_reward',
          'daily_ch_play',
          'daily_ch_short',
          'endless_event_moves',
          'endless_event_scoreX2',
          'endless_event_gems',
          'color_rush_streak',
          'soda_nozzle_burst',
          'rec_new_best',
          'rec_milestone',
          'rec_tier_bronze',
          'rec_tier_silver',
          'rec_tier_gold',
          'rec_tier_platinum',
          'hard_variant_on',
          'hard_variant_off',
          'puzzle_short',
          'puzzle_title',
          'puzzle_sub',
          'puzzle_no',
          'puzzle_target',
          'puzzle_solved',
          'puzzle_all_done',
          'puzzle_progress',
          'utilities',
          'coll_set_title',
          'coll_set_reward',
          'coll_set_owned_reward',
          'ach_equip',
          'ach_equipped',
          'shop_upgrades',
          'shop_owned',
          'upg_hammer',
          'upg_hammer_desc',
          'upg_moves',
          'upg_moves_desc',
          'daily_mut_only4Colors',
          'daily_mut_lowMoves',
          'daily_mut_doubleCombo',
          'daily_mut_noSpecial',
          'daily_mut_bonusMoves',
          'color_rush_title',
          'color_rush_short',
          'color_rush_hot',
          'hud_flip_in',
          'hud_maze_walls',
          'hud_streak',
          'color_rush_desc',
          'conveyor_title',
          'portal_title',
          'dispenser_title',
          'guide_w11_title',
          'guide_w11_body',
          'soda_title',
          'soda_short',
          'soda_hud',
          'soda_desc',
          'obstacle_licorice',
          'obstacle_jam',
          'guide_w14_title',
          'guide_w14_body',
          'coll_title',
          'coll_points',
          'coll_hint',
          'coll_cyan_spark',
          'coll_magenta_bloom',
          'coll_lime_leaf',
          'coll_amber_sun',
          'coll_orange_ember',
          'coll_violet_dusk',
          'coll_prism_shard',
          'coll_nebula_core',
          'coll_aurora_wing',
          'coll_quasar_eye',
          'coll_pulsar_heart',
          'coll_singularity',
          'coll_desc_cyan_spark',
          'coll_desc_magenta_bloom',
          'coll_desc_lime_leaf',
          'coll_desc_amber_sun',
          'coll_desc_orange_ember',
          'coll_desc_violet_dusk',
          'coll_desc_prism_shard',
          'coll_desc_nebula_core',
          'coll_desc_aurora_wing',
          'coll_desc_quasar_eye',
          'coll_desc_pulsar_heart',
          'coll_desc_singularity',
          'coll_close',
          'piggy_title',
          'piggy_smash',
          'piggy_ready',
          'piggy_min',
          'piggy_smashed',
          'piggy_got',
          'tour_title',
          'tour_you',
          'tour_rank',
          'tour_ends',
          'tour_points',
          'tour_claimed',
          'tour_claim_reward',
          'tour_play_hint',
        ];
        // Danh mục key "hợp lệ giữ nguyên English" — xác định bằng thống kê:
        // giá trị y hệt English ở >=3/20 ngôn ngữ dịch ĐỘC LẬP (khó trùng
        // ngẫu nhiên) → gồm placeholder thuần (không chữ), danh từ riêng
        // (tên NPC/world/item sưu tầm dạng thương hiệu), tên mode/rank ngắn
        // hay giữ nguyên kiểu game quốc tế (Zen, Boss, Rush, Bronze...).
        const universalKeys = {
          'ghost_play',
          'ghost_hud',
          'pt_star_cost',
          'pt_gold_cost',
          'color_rush_streak',
          'rush_time_bonus',
          'zen_title',
          'zen_short',
          'npc_name_1',
          'npc_name_2',
          'npc_name_3',
          'npc_name_4',
          'npc_name_5',
          'boss_short',
          'rhythm_groove',
          'versus_mode',
          'rush_title',
          'rush_short',
          'bp_joker',
          'versus_p1',
          'versus_p2',
          'portal_title',
          'coll_title',
          'wheel_got_booster',
          'bp_title',
          'season_pts_short',
          'daily_mut_doubleCombo',
          'color_rush_title',
          'color_rush_short',
          'soda_short',
          'clan_title',
          'boss_atk_meteor',
          'ach_combo_5_t',
          'ach_combo_8_t',
          'ach_streak_12_t',
          'lb_level',
          'pt_prestige_title',
          'pt_ascendant_title',
          'rhythm_short',
          'survival_short',
          'survival_title',
          'bomb_timer',
          'bp_level',
          'rhythm_title',
          'puzzle_short',
          'puzzle_no',
          'endless_short',
          'endless_title',
          'coop_mode',
          'rec_tier_bronze',
          'dispenser_title',
          'labyrinth_short',
          'ach_wins_30_t',
          'bp_royal',
          'boss_title',
          'boss_phase',
          'rec_tier_platinum',
          'conveyor_title',
          'obstacle_licorice',
        };
        final en = keys['en_US']!;
        for (final entry in keys.entries) {
          if (entry.key == 'en_US') continue;
          var diff = 0;
          var total = 0;
          for (final k in wave4Keys) {
            if (universalKeys.contains(k)) continue;
            total++;
            if (entry.value[k]?.trim() != en[k]?.trim()) diff++;
          }
          final ratio = total > 0 ? diff / total : 1.0;
          expect(
            ratio,
            greaterThanOrEqualTo(0.95),
            reason:
                '${entry.key} chỉ dịch ${(ratio * 100).toStringAsFixed(1)}% '
                'key Wave 4 — fallback English còn nhiều',
          );
        }
      },
    );
  });
}

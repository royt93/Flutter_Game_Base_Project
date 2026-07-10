import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tập trung MỌI key lưu trữ — tránh gõ string literal rải rác, dễ sai.
class StorageKeys {
  StorageKeys._();

  static const String unlockedLevel = 'unlockedLevel';
  static const String coins = 'coins';
  static const String localeCode = 'locale_code';
  static const String audioMuted = 'audio_muted';

  // Daily reward
  static const String dailyLastClaim = 'daily_last_claim'; // epoch-day
  static const String dailyStreak = 'daily_streak';

  /// Ngày (epoch-day) CAO NHẤT từng thấy — chống chỉnh giờ LÙI để nhận lại quà.
  static const String maxDay = 'max_epoch_day';

  // Wave 9 — Thử thách hằng ngày (puzzle chơi theo ngày, seed = epoch-day)
  /// Epoch-day của lần HOÀN THÀNH (thắng) gần nhất — thưởng chỉ 1 lần/ngày.
  static const String dailyChLastDone = 'daily_ch_last_done';
  static const String dailyChStreak = 'daily_ch_streak';
  static const String dailyChBestStreak = 'daily_ch_best_streak';

  /// W22.4A — điểm cao nhất CỦA NGÀY cho Daily Leaderboard, dạng `'<epochDay>|<score>'`.
  /// Sang ngày mới → coi như chưa có (đọc so khớp epochDay). Pure offline.
  static const String dailyBestScore = 'daily_best_score';

  // Lives / energy
  static const String lives = 'lives';
  static const String livesRegenAt = 'lives_regen_at'; // epoch ms mốc hồi kế

  // Wave 5 — meta giữ chân
  static const String winStreak = 'win_streak';
  static const String bestWinStreak = 'best_win_streak';
  static const String totalWins = 'total_wins';
  static const String bestCombo = 'best_combo';
  static const String coinsEarned = 'coins_earned'; // tổng xu kiếm (lifetime)
  static const String wheelLastSpin = 'wheel_last_spin'; // epoch-day
  static const String wheelCoinStreak = 'wheel_coin_streak'; // W28.3 pity
  static const String tutorialSeen = 'tutorial_seen';
  static const String viewMode = 'view_mode'; // 0 = world map, 1 = grid

  /// W22.1 — "giảm hiệu ứng động" (accessibility): 0 = đầy đủ, 1 = giảm.
  static const String juiceReduced = 'juice_reduced';

  /// W22.3 — đã xem tour giới thiệu Home lần đầu chưa (0 = chưa, 1 = rồi).
  static const String homeTourSeen = 'home_tour_seen';

  /// W22.5 — đã nhận rương báu thế giới [w] chưa (1 = rồi). 1 rương/thế giới.
  static String chestClaimed(int world) => 'chest_claimed_$world';

  /// W23.2 — đã hạ mini-boss thế giới [w] chưa (1 = rồi). Thưởng 1 lần.
  static String miniBossCleared(int world) => 'miniboss_cleared_$world';

  // Wave 6 — Endless mode (high score riêng)
  static const String endlessHigh = 'endless_high';
  static const String zenHigh = 'zen_high'; // W20.4
  static const String zenMilestoneTier = 'zen_milestone_tier'; // W28.1

  // Wave 15 — Survival mode (kỷ lục điểm sống sót)
  static const String survivalHigh = 'survival_high';

  // Wave 16 — DDA/Pity: số lần thua LIÊN TIẾP màn [level] (reset khi thắng).
  static String pityFails(int level) => 'pity_$level';

  // Wave 12 — chống farm side-mode: đếm số trận side-mode đã thưởng trong NGÀY
  // (reset theo epoch-day) → thưởng giảm dần sau N trận đầu.
  static const String sideModeDay = 'side_mode_day';
  static const String sideModeWins = 'side_mode_wins';

  // Wave 7 — Meta build "Đền Neon"
  static const String shards = 'shards'; // (CŨ) mảnh neon — Wave 9 gộp về xu
  /// Wave 9: đã quy đổi shard cũ → xu (×10) chưa (1 = rồi). Chạy 1 lần.
  static const String shardsMigrated = 'shards_migrated';

  /// Tier hiện tại của 1 hạng mục đền (0 = chưa xây).
  static String templeTier(String id) => 'temple_$id';

  // Wave 7 — Battle Pass + nhiệm vụ ngày
  static const String bpXp = 'bp_xp'; // tổng XP pass
  static const String bpLevel = 'bp_level'; // cấp pass hiện tại
  static String bpClaimed(int level) => 'bp_claimed_$level'; // 1 = đã nhận
  static const String questDay = 'quest_day'; // epoch-day của bộ quest hiện tại
  static String questProgress(int idx) =>
      'quest_prog_$idx'; // tiến trình quest #idx
  static String questCredited(int idx) => 'quest_cred_$idx'; // 1 = đã cộng XP

  /// W23 — epoch-day đã nhận thưởng "hoàn thành cả 3 quest" (1 lần/ngày).
  static const String questBonusDay = 'quest_bonus_day';

  /// W23 — Clan: đóng góp tuần của người chơi, dạng `'<week>|<pts>'` (đổi tuần → reset).
  static const String clanPointsWeek = 'clan_points_week';

  /// W23 — Clan: tổng đóng góp TÍCH LUỸ (lifetime) cho thành tựu.
  static const String clanContribLifetime = 'clan_contrib_lifetime';

  /// W23 — Clan: tuần đã nhận thưởng mục tiêu (1 lần/tuần).
  static const String clanRewardWeek = 'clan_reward_week';

  /// W23 — Clan: tuần đã nhận thưởng XẾP HẠNG Clan-vs-Clan (top 3, 1 lần/tuần).
  static const String clanLeagueRewardWeek = 'clan_league_reward_week';

  // Wave 7 — Sự kiện theo mùa (tuần)
  static const String seasonIdx = 'season_idx'; // chỉ số mùa của điểm đang giữ
  static const String seasonPoints = 'season_points'; // điểm mùa hiện tại
  /// 1 = đã nhận mốc [m] của mùa [idx] (keyed tuyệt đối → chống chỉnh giờ lùi).
  static String seasonClaimed(int idx, int m) => 'season_cl_${idx}_$m';

  // Wave 6 — Story / Episode: cờ "đã xem" của 1 beat.
  static String storySeen(String beatId) => 'story_$beatId';

  static String highScore(int level) => 'hs_$level';
  static String star(int level) => 'star_$level';

  /// Cờ "đã nhận thưởng" của thành tựu [id].
  static String achievementClaimed(String id) => 'ach_$id';

  // W19.1 — Kỷ lục chế độ phụ ([key] = SideModeRecordSpec.key).
  static String recValue(String key) =>
      'rec_${key}_v'; // giá trị chỉ số (best/count)
  static String recTier(String key) => 'rec_${key}_t'; // bậc mốc đã nhận (0..4)
  static String recPlays(String key) => 'rec_${key}_p'; // số lần chơi
  // W25.1 Phase 1C — Thử Thách (hard variant, tự chọn sau Gold): 1 = đang bật.
  static String recHardVariant(String key) => 'rec_${key}_hv';

  // W19.2 — Cấu đố (Puzzle): sao tốt nhất từng cấu đố + số cấu đố đã mở khoá.
  static String puzzleStars(int id) => 'pz_star_$id';
  static const String puzzleUnlocked =
      'pz_unlocked'; // id cao nhất đã mở (1-based)

  // Wave 9 — Cửa hàng trang trí (skin gem + theme bàn, mua bằng xu)
  static String ownedSkin(String id) => 'skin_$id'; // 1 = đã sở hữu
  static String ownedTheme(String id) => 'theme_$id';
  static const String selectedSkin = 'sel_skin'; // id skin đang dùng
  static const String selectedTheme = 'sel_theme'; // id theme đang dùng

  // Wave 14 — Album sưu tập (điểm lifetime + cờ mở từng sticker)
  static const String collectionPoints = 'coll_points';
  static String collectionClaimed(String id) => 'coll_$id'; // 1 = đã mở
  // W18.2 — đã nhận thưởng HOÀN TẤT BỘ album (1 lần)
  static const String collectionSetClaimed = 'coll_set_done';
  // W28.3 — mốc thưởng giữa chừng album (tier 0/1/2 = 25/50/75%)
  static String collectionMilestoneClaimed(int tier) => 'coll_milestone_$tier';

  // W18.2 — Thành tựu: danh hiệu (title) đang ĐEO (id thành tựu, '' = không đeo)
  static const String equippedTitle = 'ach_equipped_title';

  // Wave 14 — Heo đất (xu đang tích trong ống)
  static const String piggySaved = 'piggy_saved';

  // Wave 14 — Giải đấu tuần (điểm tuần + tuần đang giữ + tuần đã nhận thưởng)
  static const String tournamentWeek = 'tour_week';
  static const String tournamentPoints = 'tour_points';
  static const String tournamentClaimedWeek = 'tour_claimed_week';

  // W18.1 — Mùa giải (gộp Mùa + Giải đấu). Dùng LẠI seasonPoints/seasonIdx (pool),
  // seasonClaimed (mốc), tournamentClaimedWeek (hạng). Chỉ thêm cờ migrate 1 lần.
  static const String leagueMigrated = 'league_migrated';

  // Booster
  static const String bHammer = 'b_hammer';
  static const String bMoves = 'b_moves';
  static const String bSwap = 'b_swap';
  static const String bBomb = 'b_bomb';
  static const String bColor = 'b_color';
  static const String bJoker = 'b_joker';
  static const String bLightning = 'b_light';
  static const String bRoyal = 'b_royal';
  static const String bGravity = 'b_grav';

  // W18.3 — Nâng cấp booster vĩnh viễn (coin-sink). 1 = đã nâng cấp.
  static const String upgHammer = 'upg_hammer';
  static const String upgMoves = 'upg_moves';

  // Wave 20.3 — Ghost Replay: nước đi tốt nhất theo màn (campaign only).
  // Format: "r1c1r2c2" × N moves, ghép liền (mỗi move = 4 char, coord 0-7).
  static String ghostMoves(int level) => 'gm_mv_$level';
  static String ghostScore(int level) => 'gm_sc_$level';

  // Wave 20.3 — Progression Tree: nodes đã mở khoá.
  static String ptUnlocked(String nodeId) => 'pt_node_$nodeId';
  // W28.3 — node `ascendant`: epoch-day lần cuối dùng lượt miễn phí/ngày.
  static const String ptAscendantFreeMoveDay = 'pt_ascendant_free_move_day';

  // Wave 20.3 — Challenge Card: thử thách tuần.
  static const String ccWeekIdx = 'cc_week'; // tuần hiện tại (epochDay~/7)
  static String ccProgress(int i) => 'cc_prog_$i'; // tiến trình thử thách #i
  static String ccClaimed(int i) => 'cc_claimed_$i'; // 1 = đã claim
  // H2 fix: baseline xu đầu tuần (dùng bởi ChallengeCardController.refreshCoins)
  static const String ccCoinsStart = 'cc_coins_start';

  // W25.3 — trục điểm side-mode/tuần (tách biệt campaign).
  static const String ccSideWeekPoints = 'cc_side_pts';
  static const String ccSideMilestone = 'cc_side_milestone'; // 0..3 mốc đã nhận
}

/// Service lưu trữ local dùng chung (bọc SharedPreferences).
/// Đăng ký 1 lần ở main: `Get.put(StorageService(prefs), permanent: true)`.
class StorageService extends GetxService {
  final SharedPreferences _prefs;
  StorageService(this._prefs);

  static StorageService get to => Get.find<StorageService>();

  int getInt(String key, {int def = 0}) => _prefs.getInt(key) ?? def;
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  bool getBool(String key, {bool def = false}) => _prefs.getBool(key) ?? def;
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  Future<void> remove(String key) => _prefs.remove(key);
}

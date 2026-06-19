import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tập trung MỌI key lưu trữ — tránh gõ string literal rải rác, dễ sai.
class StorageKeys {
  StorageKeys._();

  static const String unlockedLevel = 'unlockedLevel';
  static const String coins = 'coins';
  static const String localeCode = 'locale_code';

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
  static const String tutorialSeen = 'tutorial_seen';
  static const String viewMode = 'view_mode'; // 0 = world map, 1 = grid

  // Wave 6 — Endless mode (high score riêng)
  static const String endlessHigh = 'endless_high';

  // Wave 15 — Survival mode (kỷ lục điểm sống sót)
  static const String survivalHigh = 'survival_high';

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
  static String questProgress(int idx) => 'quest_prog_$idx'; // tiến trình quest #idx
  static String questCredited(int idx) => 'quest_cred_$idx'; // 1 = đã cộng XP

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

  // Wave 9 — Cửa hàng trang trí (skin gem + theme bàn, mua bằng xu)
  static String ownedSkin(String id) => 'skin_$id'; // 1 = đã sở hữu
  static String ownedTheme(String id) => 'theme_$id';
  static const String selectedSkin = 'sel_skin'; // id skin đang dùng
  static const String selectedTheme = 'sel_theme'; // id theme đang dùng

  // Wave 14 — Album sưu tập (điểm lifetime + cờ mở từng sticker)
  static const String collectionPoints = 'coll_points';
  static String collectionClaimed(String id) => 'coll_$id'; // 1 = đã mở

  // Wave 14 — Heo đất (xu đang tích trong ống)
  static const String piggySaved = 'piggy_saved';

  // Wave 14 — Giải đấu tuần (điểm tuần + tuần đang giữ + tuần đã nhận thưởng)
  static const String tournamentWeek = 'tour_week';
  static const String tournamentPoints = 'tour_points';
  static const String tournamentClaimedWeek = 'tour_claimed_week';

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
}

/// Service lưu trữ local dùng chung (bọc SharedPreferences).
/// Đăng ký 1 lần ở main: `Get.put(StorageService(prefs), permanent: true)`.
class StorageService extends GetxService {
  final SharedPreferences _prefs;
  StorageService(this._prefs);

  static StorageService get to => Get.find<StorageService>();

  int getInt(String key, {int def = 0}) => _prefs.getInt(key) ?? def;
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  Future<void> remove(String key) => _prefs.remove(key);
}

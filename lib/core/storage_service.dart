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

  // Wave 6 — Story / Episode: cờ "đã xem" của 1 beat.
  static String storySeen(String beatId) => 'story_$beatId';

  static String highScore(int level) => 'hs_$level';
  static String star(int level) => 'star_$level';

  /// Cờ "đã nhận thưởng" của thành tựu [id].
  static String achievementClaimed(String id) => 'ach_$id';

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

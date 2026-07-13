import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tập trung MỌI key lưu trữ — tránh gõ string literal rải rác, dễ sai.
class StorageKeys {
  StorageKeys._();

  static const String unlockedLevel = 'unlockedLevel';
  static const String coins = 'coins';
  static const String localeCode = 'locale_code';
  static const String audioMuted = 'audio_muted';
  static const String colorblindMode = 'colorblind_mode';
  // I15 Day/Night theme toggle.
  static const String themeDark = 'theme_dark';

  static String highScore(int level) => 'hs_$level';
  static String star(int level) => 'star_$level';

  // Booster (mid-game): bomb (nổ 3x3), shuffle (xáo bàn), undo (revert 1 bước),
  // rainbow (xoá mọi ô cùng màu)
  static const String bombCount = 'bomb_count';
  static const String shuffleCount = 'shuffle_count';
  static const String undoCount = 'undo_count';
  static const String rainbowCount = 'rainbow_count';
  // F10: swap (đổi màu 2 ô), freeze (chặn giảm bền obstacle N lượt).
  static const String swapCount = 'swap_count';
  static const String freezeCount = 'freeze_count';

  // F7 Star road: bitmask rương đã claim (bit i = mốc thứ i).
  static const String claimedChests = 'claimed_chests';

  // F2 Daily reward.
  static const String lastClaimDay = 'last_claim_day';
  static const String dailyStreak = 'daily_streak';
  static const String maxEpochDaySeen = 'max_epoch_day_seen';

  // I10 Comeback bonus.
  static const String lastOpenDay = 'last_open_day';

  // F8 Time-attack side mode best score (không đụng campaign highScore).
  static const String timeAttackBest = 'time_attack_best';

  // X1 Onboarding/FTUE: đã xem overlay "chạm để nổ" chưa (chỉ hiện 1 lần).
  static const String hasSeenFtue = 'has_seen_ftue';

  // X2: mức âm lượng riêng nhạc nền/hiệu ứng (0.0..1.0) + bật/tắt haptics.
  static const String bgmVolume = 'bgm_volume';
  static const String sfxVolume = 'sfx_volume';
  static const String hapticsEnabled = 'haptics_enabled';

  // X5: đã hiện review prompt chưa (chỉ hiện đúng 1 lần trong đời cài đặt).
  static const String hasShownReviewPrompt = 'has_shown_review_prompt';

  // I7 Vòng quay hằng ngày (biệt lập với F2 daily reward).
  static const String lastSpinDay = 'last_spin_day';

  // F12 Endless mode: điểm cao nhất (biệt lập campaign/time-attack).
  static const String endlessBest = 'endless_best';

  // F13 Daily Challenge: ngày + điểm đã ghi nhận lần gần nhất (1 lượt/ngày).
  static const String lastDailyChallengeDay = 'last_daily_challenge_day';
  static const String dailyChallengeScore = 'daily_challenge_score';

  // I6 Battle-pass mùa (free-track only): điểm mùa, mốc đã nhận, mùa gần nhất.
  static const String seasonPoints = 'season_points';
  static const String claimedSeasonMask = 'claimed_season_mask';
  static const String lastSeasonIndex = 'last_season_index';

  // F14 Relic/Perk: id perk active, nối bằng dấu phẩy (tối đa 2).
  static const String activePerks = 'active_perks';
}

/// Service lưu trữ local dùng chung (bọc SharedPreferences).
/// Đăng ký 1 lần ở main: `Get.put(StorageService(prefs), permanent: true)`.
///
/// [_prefs] null khi `SharedPreferences.getInstance()` lỗi lúc boot (thiết bị
/// hiếm, storage hỏng) — dùng [_fallback] in-memory để app vẫn chạy được với
/// giá trị mặc định an toàn thay vì crash trắng màn hình (không persist qua
/// session, nhưng đó là quyền lấy sau, không phải crash).
class StorageService extends GetxService {
  final SharedPreferences? _prefs;
  final Map<String, Object> _fallback = {};
  StorageService(this._prefs);

  static StorageService get to => Get.find<StorageService>();

  int getInt(String key, {int def = 0}) =>
      _prefs?.getInt(key) ?? (_fallback[key] as int?) ?? def;
  Future<void> setInt(String key, int value) async {
    if (_prefs != null) {
      await _prefs.setInt(key, value);
      return;
    }
    _fallback[key] = value;
  }

  bool getBool(String key, {bool def = false}) =>
      _prefs?.getBool(key) ?? (_fallback[key] as bool?) ?? def;
  Future<void> setBool(String key, bool value) async {
    if (_prefs != null) {
      await _prefs.setBool(key, value);
      return;
    }
    _fallback[key] = value;
  }

  double getDouble(String key, {double def = 1.0}) =>
      _prefs?.getDouble(key) ?? (_fallback[key] as double?) ?? def;
  Future<void> setDouble(String key, double value) async {
    if (_prefs != null) {
      await _prefs.setDouble(key, value);
      return;
    }
    _fallback[key] = value;
  }

  String? getString(String key) =>
      _prefs?.getString(key) ?? _fallback[key] as String?;
  Future<void> setString(String key, String value) async {
    if (_prefs != null) {
      await _prefs.setString(key, value);
      return;
    }
    _fallback[key] = value;
  }

  Future<void> remove(String key) async {
    if (_prefs != null) {
      await _prefs.remove(key);
      return;
    }
    _fallback.remove(key);
  }
}

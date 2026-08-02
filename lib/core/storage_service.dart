import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'debug_log.dart';

/// Tập trung MỌI key lưu trữ — tránh gõ string literal rải rác, dễ sai.
class StorageKeys {
  StorageKeys._();

  static const String unlockedLevel = 'unlockedLevel';
  static const String coins = 'coins';
  static const String localeCode = 'locale_code';
  // I26 (task #18): tên hiển thị dùng để tạo mã "so tài" bạn bè.
  static const String playerName = 'player_name';
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

  // A7: tắt slow-mo/zoom-punch/shake cho người nhạy chuyển động.
  static const String reduceMotion = 'reduce_motion';

  // I28: bật ghi lại lượt tap để tạo mã ghost-replay chia sẻ (mặc định tắt).
  static const String recordReplay = 'record_replay';

  // X5: đã hiện review prompt chưa (chỉ hiện đúng 1 lần trong đời cài đặt).
  static const String hasShownReviewPrompt = 'has_shown_review_prompt';

  // I7 Vòng quay hằng ngày (biệt lập với F2 daily reward).
  static const String lastSpinDay = 'last_spin_day';

  // F12 Endless mode: điểm cao nhất (biệt lập campaign/time-attack).
  static const String endlessBest = 'endless_best';

  // I47 Mirror Mode: điểm cao nhất (biệt lập các mode khác).
  static const String mirrorModeBest = 'mirror_mode_best';

  // F13 Daily Challenge: ngày + điểm đã ghi nhận lần gần nhất (1 lượt/ngày).
  static const String lastDailyChallengeDay = 'last_daily_challenge_day';
  static const String dailyChallengeScore = 'daily_challenge_score';

  // I6 Battle-pass mùa (free-track only): điểm mùa, mốc đã nhận, mùa gần nhất.
  static const String seasonPoints = 'season_points';
  static const String claimedSeasonMask = 'claimed_season_mask';
  static const String lastSeasonIndex = 'last_season_index';

  // F14 Relic/Perk: id perk active, nối bằng dấu phẩy (tối đa 2).
  static const String activePerks = 'active_perks';

  // I22 Achievements: counter tích lũy đời (không reset giữa các ván) + id đã
  // unlock (CSV, giống activePerks).
  static const String totalGemsPopped = 'total_gems_popped';
  static const String maxComboEver = 'max_combo_ever';
  static const String levelsThreeStarred = 'levels_three_starred';
  static const String boardsFullyCleared = 'boards_fully_cleared';
  static const String totalBoostersUsed = 'total_boosters_used';
  static const String unlockedAchievements = 'unlocked_achievements';

  // I36 Achievement Titles: id achievement đang chọn làm danh hiệu hiển thị
  // cạnh tên (rỗng = không có danh hiệu).
  static const String activeAchievementTitleId = 'active_achievement_title_id';

  // I27 Prestige/New Game+: tier hiện tại (0 = chưa prestige); đã hoàn
  // thành level cuối (220) ít nhất 1 lần ở tier hiện tại chưa (điều kiện mở
  // khoá nút Prestige — `unlockedLevel` tự chặn ở kLevelCount nên không
  // dùng được làm tín hiệu "đã xong hết").
  static const String prestigeTier = 'prestige_tier';
  static const String allLevelsCompleted = 'all_levels_completed';

  // I30 Mascot Wardrobe: id skin đang active + set id skin đã mở khoá (CSV,
  // giống unlockedAchievements) — mặc định chỉ có skin free.
  static const String activeMascotSkin = 'active_mascot_skin';
  static const String unlockedMascotSkins = 'unlocked_mascot_skins';

  // I42 Puzzle Lab: mã bàn tự vẽ đã lưu (JSON list, tối đa 5 phần tử — cắt ở
  // tầng caller).
  static const String savedPuzzles = 'saved_puzzles';

  // I43 Boss Rush: số stage (bàn boss) đã dọn sạch liên tiếp cao nhất từng
  // đạt được (chuỗi đứt khi thua/kẹt).
  static const String bossRushBestStreak = 'boss_rush_best_streak';

  // I52 Pop Burst Style Picker: id style hiệu ứng nổ đang chọn (mặc định
  // 'spark').
  static const String activeBurstStyle = 'active_burst_style';

  // I48 Login Streak Calendar: streak hiện tại, epoch-day lần điểm danh
  // cuối, bitmask ngày đã claim thưởng trong cycle 7 ngày hiện tại.
  static const String loginStreakCount = 'login_streak_count';
  static const String lastLoginEpochDay = 'last_login_epoch_day';
  static const String loginStreakClaimedMask = 'login_streak_claimed_mask';

  // I54 Combo Text Style: id style chữ combo-milestone đang chọn (mặc định
  // 'neon').
  static const String activeComboTextStyle = 'active_combo_text_style';

  // I50 Weekly Goal Card: tiến độ cộng dồn tuần hiện tại, chỉ số tuần
  // (`epochDay ~/ 7`) của lần cập nhật cuối, và chỉ số tuần đã nhận thưởng
  // (chống nhận 2 lần cùng tuần).
  static const String weeklyGoalProgress = 'weekly_goal_progress';
  static const String weeklyGoalWeek = 'weekly_goal_week';
  static const String weeklyGoalClaimedWeek = 'weekly_goal_claimed_week';

  // I33 Daily Modifier Gauntlet: ngày + điểm đã ghi nhận lần gần nhất (1
  // lượt/ngày, giống lastDailyChallengeDay/dailyChallengeScore).
  static const String lastGauntletDay = 'last_gauntlet_day';
  static const String gauntletScore = 'gauntlet_score';

  // I38 Weekly Featured Level: tuần (epochDay ~/ 7) của best score đang lưu +
  // best score đó — không dùng highScore(levelId) vì mục đích khác campaign
  // thường (không giới hạn số lần chơi, reset mỗi tuần vì level tuần đổi).
  static const String lastFeaturedWeekSeen = 'last_featured_week_seen';
  static const String featuredLevelScore = 'featured_level_score';

  // I51 Board Frame Cosmetics: id khung viền board đang chọn (mặc định
  // 'classic') — không persist "đã mở khoá" vì suy trực tiếp từ prestigeTier
  // (I27) + unlockedAchievements (I22) đã có sẵn.
  static const String activeBoardFrame = 'active_board_frame';

  // I62 Color Alchemy: map slot-index → pigment-id và các pigment đã mua.
  static const String gemColorOverrides = 'gem_color_overrides';
  static const String unlockedPigments = 'unlocked_pigments';

  // I60 Treasure Map: consumable entry tickets + exclusive chest unlock.
  static const String treasureMapCount = 'treasure_map_count';
  static const String treasureMapCompleted = 'treasure_map_completed';
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

  /// An toàn khi gọi từ widget test độc lập chưa đăng ký service (vd các
  /// widget hiệu ứng nhỏ như confetti/mascot/pulse-glow test riêng lẻ).
  static StorageService? get maybe =>
      Get.isRegistered<StorageService>() ? Get.find<StorageService>() : null;

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

  /// I42: đọc JSON list (khác pattern CSV-join của các key khác trong file
  /// này) — dùng cho danh sách mã puzzle tự vẽ đã lưu.
  List<String> getStringList(String key) {
    final raw = getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> setStringList(String key, List<String> value) =>
      setString(key, jsonEncode(value));

  Future<void> remove(String key) async {
    if (_prefs != null) {
      await _prefs.remove(key);
      return;
    }
    _fallback.remove(key);
  }

  /// Dump toàn bộ storage hiện có thành map — dùng API generic của
  /// SharedPreferences (getKeys/get) thay vì hand-list từng StorageKeys, để
  /// không phải nhớ cập nhật danh sách này mỗi khi thêm key mới.
  Map<String, Object> exportAll() {
    final prefs = _prefs;
    if (prefs == null) return Map<String, Object>.from(_fallback);
    return {for (final k in prefs.getKeys()) k: prefs.get(k) as Object};
  }

  /// Ghi đè storage từ map đã export. Giá trị chỉ có thể là int/bool/double/
  /// String (StorageService không bao giờ set List thẳng xuống
  /// SharedPreferences — [setStringList] tự JSON-encode thành String).
  Future<void> importAll(Map<String, Object?> data) async {
    if (data.values.any(
      (value) =>
          value is! int &&
          value is! bool &&
          value is! double &&
          value is! String,
    )) {
      throw const FormatException('Unsupported backup value type');
    }
    final normalized = <String, Object>{
      for (final entry in data.entries) entry.key: entry.value!,
    };
    final previous = exportAll();
    try {
      await _replaceAll(normalized);
    } catch (error) {
      // SharedPreferences has no transaction primitive. Re-apply the
      // snapshot so a partial write cannot leave a half-restored profile.
      try {
        await _replaceAll(previous);
      } catch (rollbackError) {
        // Preserve the original failure; callers still show a restore error.
        dlog('roy93~ importAll rollback thất bại: $rollbackError');
      }
      rethrow;
    }
  }

  Future<void> _replaceAll(Map<String, Object> data) async {
    final prefs = _prefs;
    if (prefs != null) {
      for (final key in prefs.getKeys().toList()) {
        await prefs.remove(key);
      }
    } else {
      _fallback.clear();
    }
    for (final entry in data.entries) {
      final value = entry.value;
      switch (value) {
        case int v:
          await setInt(entry.key, v);
        case bool v:
          await setBool(entry.key, v);
        case double v:
          await setDouble(entry.key, v);
        case String v:
          await setString(entry.key, v);
      }
    }
  }
}

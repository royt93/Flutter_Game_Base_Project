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

  // I80 Remix Levels: điểm cao nhất riêng từng level remix (biệt lập
  // highScore campaign của cùng levelId).
  static String remixBest(int levelId) => 'remix_best_$levelId';

  // Booster (mid-game): bomb (nổ 3x3), shuffle (xáo bàn), undo (revert 1 bước),
  // rainbow (xoá mọi ô cùng màu)
  static const String bombCount = 'bomb_count';
  static const String shuffleCount = 'shuffle_count';
  static const String undoCount = 'undo_count';
  static const String rainbowCount = 'rainbow_count';
  // F10: swap (đổi màu 2 ô), freeze (chặn giảm bền obstacle N lượt).
  static const String swapCount = 'swap_count';
  static const String freezeCount = 'freeze_count';
  // I55: streak freeze — bảo vệ login streak (I48) khi lỡ đúng 1 ngày.
  static const String streakFreezeCount = 'streak_freeze_count';

  // I56: bật/tắt local reminder nhắc spin/streak/weekly-goal (mặc định bật).
  static const String remindersEnabled = 'reminders_enabled';

  // F7 Star road: bitmask rương đã claim (bit i = mốc thứ i).
  static const String claimedChests = 'claimed_chests';

  // F2 Daily reward.
  static const String lastClaimDay = 'last_claim_day';
  static const String dailyStreak = 'daily_streak';
  static const String maxEpochDaySeen = 'max_epoch_day_seen';

  /// X22: mốc mili-giây lớn nhất từng thấy — bản độ-phân-giải-cao của
  /// [maxEpochDaySeen], dùng cho thưởng idle của Star Pet (I65).
  static const String maxMsSeen = 'max_ms_seen';

  // I10 Comeback bonus.
  static const String lastOpenDay = 'last_open_day';

  // F8 Time-attack side mode best score (không đụng campaign highScore).
  static const String timeAttackBest = 'time_attack_best';

  // I75 Combo Rush side mode best score (đua giữ combo, không timer).
  static const String comboRushBest = 'combo_rush_best';

  // I76b Frost Rush side mode best score (Combo Rush + mật độ Ice Tile ép cao).
  static const String frostRushBest = 'frost_rush_best';

  // I77 Sticker Album: bitmask mốc "tổng cosmetic sở hữu" đã nhận thưởng xu
  // (bit i = mốc thứ i trong GameController.stickerAlbumMilestones).
  static const String stickerMilestonesClaimed = 'sticker_milestones_claimed';

  // X1 Onboarding/FTUE: đã xem overlay "chạm để nổ" chưa (chỉ hiện 1 lần).
  static const String hasSeenFtue = 'has_seen_ftue';

  // Round-7 Tutorial mở rộng: 3 coach-mark thêm cho tính năng dễ bị bỏ sót.
  static const String hasSeenShopTutorial = 'has_seen_shop_tutorial';
  static const String hasSeenBoosterTutorial = 'has_seen_booster_tutorial';
  static const String hasSeenDailyChallengeTutorial =
      'has_seen_daily_challenge_tutorial';

  // X2: mức âm lượng riêng nhạc nền/hiệu ứng (0.0..1.0) + bật/tắt haptics.
  static const String bgmVolume = 'bgm_volume';
  static const String sfxVolume = 'sfx_volume';
  static const String hapticsEnabled = 'haptics_enabled';

  // A7: tắt slow-mo/zoom-punch/shake cho người nhạy chuyển động.
  static const String reduceMotion = 'reduce_motion';

  // I71: giảm cường độ rung (heavy/medium hạ xuống 1 bậc), mặc định tắt.
  static const String hapticSoftMode = 'haptic_soft_mode';

  // I71: nới hit-test ở mép ngoài bàn cờ cho người khó nhắm chính xác.
  static const String largerTapTargets = 'larger_tap_targets';

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

  // I72 Milestone Journal: epochDay lúc unlock từng achievement, JSON
  // `Map<String,int>` id -> epochDay (để sort feed mốc lịch sử theo thời gian).
  static const String achievementUnlockDays = 'achievement_unlock_days';

  // I36 Achievement Titles: id achievement đang chọn làm danh hiệu hiển thị
  // cạnh tên (rỗng = không có danh hiệu).
  static const String activeAchievementTitleId = 'active_achievement_title_id';

  // I27 Prestige/New Game+: tier hiện tại (0 = chưa prestige); đã hoàn
  // thành level cuối (220) ít nhất 1 lần ở tier hiện tại chưa (điều kiện mở
  // khoá nút Prestige — `unlockedLevel` tự chặn ở kLevelCount nên không
  // dùng được làm tín hiệu "đã xong hết").
  static const String prestigeTier = 'prestige_tier';
  static const String allLevelsCompleted = 'all_levels_completed';
  // Round-8 I79: `kLevelCount` tại thời điểm [allLevelsCompleted] được set —
  // dùng để phát hiện campaign đã mở rộng (vd 240→260) sau khi cờ này đã lưu
  // `true`, tránh Prestige "chui" mà chưa chơi các level mới. Xem
  // `_migrateAllLevelsCompletedFlag` trong game_controller.dart.
  static const String allLevelsCompletedAtCount =
      'all_levels_completed_at_count';

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

  // I67 Daily Quest Board: ngày, ba tiến độ song song, và index đã claim.
  static const String dailyQuestDay = 'daily_quest_day';
  static const String dailyQuestProgress = 'daily_quest_progress';
  static const String dailyQuestClaimed = 'daily_quest_claimed';

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

  // I64 Star Constellation & Sky Shrine: Star Seed currency, mask chòm sao đã
  // nhận Star Seed, và id hiệu ứng aura đang chọn.
  static const String starSeedCount = 'star_seed_count';
  static const String claimedStarSeedMask = 'claimed_star_seed_mask';
  static const String activeSkyAura = 'active_sky_aura';

  // I61 Boss Breakout Event Raid: số lượt thử đã dùng hôm nay, tổng sát thương tuần,
  // chỉ số tuần của sự kiện, và trạng thái đã nhận thưởng tuần chưa.
  static const String raidBossAttemptsUsed = 'raid_boss_attempts_used';
  static const String raidBossLastAttemptDay = 'raid_boss_last_attempt_day';
  static const String raidBossTotalDamage = 'raid_boss_total_damage';
  static const String raidBossEventWeek = 'raid_boss_event_week';
  static const String raidBossRewardClaimedWeek =
      'raid_boss_reward_claimed_week';

  // I62 Color Alchemy: map slot-index → pigment-id và các pigment đã mua.
  static const String gemColorOverrides = 'gem_color_overrides';
  static const String unlockedPigments = 'unlocked_pigments';

  // I60 Treasure Map: consumable entry tickets + exclusive chest unlock.
  static const String treasureMapCount = 'treasure_map_count';
  static const String treasureMapCompleted = 'treasure_map_completed';

  // I65 Star Pet Companion Habitat: xu tiên tệ riêng (Star Dust), danh sách
  // pet sở hữu (JSON-encode list PetInstance), mốc thời gian lần hốt thưởng
  // idle gần nhất — key mới hoàn toàn, không tái dùng lastOpenDay (mục đích
  // khác: đó là streak điểm danh, đây là mốc tính idle-reward liên tục).
  static const String starDustCount = 'star_dust_count';
  static const String starOwnedPets = 'star_owned_pets';
  static const String lastPetCollectTimestampMs = 'last_pet_collect_ms';

  // I66 Clan Lite: đóng góp tuần (reset theo tuần, mirror weeklyGoalWeek) +
  // đóng góp lifetime (không reset) + tuần/trạng thái đã nhận thưởng pool.
  static const String clanContribWeek = 'clan_contrib_week';
  static const String clanContribTotal = 'clan_contrib_total';
  static const String clanGoalWeek = 'clan_goal_week';
  static const String clanGoalClaimedWeek = 'clan_goal_claimed_week';

  // I74 Home Screen Widget: KHÔNG phải key của SharedPreferences app (không
  // đọc/ghi qua StorageService.to) — đây là key của file prefs riêng do
  // `home_widget` plugin quản lý (`HomeWidget.saveWidgetData`), phía Kotlin
  // đọc lại đúng 2 chuỗi này trong `StreakWidgetProvider.kt`. Đặt const ở
  // đây chỉ để tránh string-literal trùng lặp phía Dart + làm điểm đối
  // chiếu tên với hằng số Kotlin tương ứng (2 ngôn ngữ không thể import
  // chung 1 hằng số, chỉ đồng bộ được tên).
  static const String widgetStreakKey = 'streak';
  static const String widgetCoinsKey = 'coins';
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

  /// X24: số lần thật sự chạm `SharedPreferences` (platform channel + ghi
  /// đĩa). Tăng ở mọi `setX` **không** đi qua buffer, và mỗi key được
  /// [flush] đẩy xuống.
  ///
  /// Tồn tại để đo được khiếm khuyết X24 bằng test tất định thay vì profile
  /// tay trên device: `registerPop()` từng ghi 6 lần cho MỖI cú tap. Một
  /// `int++` không đáng kể ở runtime, đổi lại có lưới chống hồi quy vĩnh
  /// viễn — round sau ai thêm hệ mới vào hot path là test đỏ ngay.
  int platformWrites = 0;

  /// X24: write-behind cho hot path. Giá trị ghi qua `setXBuffered` nằm ở đây
  /// tới khi [flush] đẩy xuống đĩa một lượt.
  ///
  /// **Mọi đường đọc phải tra buffer TRƯỚC `_prefs`** — nếu không, giá trị vừa
  /// ghi mà chưa flush sẽ đọc ra số cũ. Đó là bẫy chính của kiểu tối ưu này,
  /// nên [getInt]/[getBool]/[getString]/[getDouble]/[allKeys]/[exportAll] đều
  /// đã xử lý, và [remove]/[importAll] dọn buffer.
  ///
  /// CHỈ dùng cho counter trên hot path (xem `GameController.registerPop`).
  /// Giao dịch thật — mua bán, nhận thưởng, reset — phải ghi ngay bằng `setX`
  /// thường: mất chúng khi app bị kill là mất tiền/vật phẩm của người chơi.
  final Map<String, Object> _buffer = {};

  Future<void> setIntBuffered(String key, int value) async =>
      _buffer[key] = value;

  Future<void> setStringBuffered(String key, String value) async =>
      _buffer[key] = value;

  /// Đẩy toàn bộ giá trị đang đệm xuống đĩa. Gọi ở mốc an toàn: kết thúc màn,
  /// app vào nền, controller đóng, và trước mọi giao dịch có thưởng.
  Future<void> flush() async {
    if (_buffer.isEmpty) return;
    final pending = Map<String, Object>.from(_buffer);
    _buffer.clear();
    for (final entry in pending.entries) {
      final value = entry.value;
      if (value is int) {
        await setInt(entry.key, value);
      } else if (value is String) {
        await setString(entry.key, value);
      } else if (value is bool) {
        await setBool(entry.key, value);
      } else if (value is double) {
        await setDouble(entry.key, value);
      }
    }
  }

  /// X28: đọc giá trị thô rồi **kiểm kiểu**, không cast thẳng.
  ///
  /// Bản cũ dùng `_prefs.getInt(key)` / `as int?`, mà cả hai đều ném
  /// `TypeError` nếu key đang giữ kiểu khác (String ở chỗ đáng lẽ là int).
  /// Vì `GameController._load()` đọc gần 100 key và chạy trong `onInit()` của
  /// một singleton `permanent: true` dựng ngay ở `main.dart`, một key sai kiểu
  /// duy nhất là **app không boot được** — người chơi phải gỡ cài đặt.
  ///
  /// Đường vào có thật: [importAll] chỉ kiểm giá trị thuộc int/bool/double/
  /// String, KHÔNG kiểm từng key có đúng kiểu mong đợi không. Cộng với khoá
  /// backup nằm sẵn trong binary (xem `logic/backup_code.dart`), ai cũng tạo
  /// được mã backup hợp lệ chứa `"coins": "abc"`.
  ///
  /// Sai kiểu → trả mặc định, giống hệt như key chưa tồn tại. Sửa ở đây phủ
  /// **mọi** key một lượt, thay vì bọc try/catch ở từng chỗ hydrate (cách đó
  /// đã trôi mất 1 chỗ, xem [X18]).
  Object? _raw(String key) => _buffer[key] ?? _prefs?.get(key) ?? _fallback[key];

  int getInt(String key, {int def = 0}) {
    final v = _raw(key);
    return v is int ? v : def;
  }
  Future<void> setInt(String key, int value) async {
    platformWrites++;
    if (_prefs != null) {
      await _prefs.setInt(key, value);
      return;
    }
    _fallback[key] = value;
  }

  bool getBool(String key, {bool def = false}) {
    final v = _raw(key);
    return v is bool ? v : def;
  }
  Future<void> setBool(String key, bool value) async {
    platformWrites++;
    if (_prefs != null) {
      await _prefs.setBool(key, value);
      return;
    }
    _fallback[key] = value;
  }

  double getDouble(String key, {double def = 1.0}) {
    final v = _raw(key);
    return v is double ? v : def;
  }
  Future<void> setDouble(String key, double value) async {
    platformWrites++;
    if (_prefs != null) {
      await _prefs.setDouble(key, value);
      return;
    }
    _fallback[key] = value;
  }

  String? getString(String key) {
    final v = _raw(key);
    return v is String ? v : null;
  }
  Future<void> setString(String key, String value) async {
    platformWrites++;
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
    // X24: xoá cả bản đang đệm, nếu không thì giá trị chưa flush sẽ "sống
    // lại" ở lần đọc kế tiếp dù key đã bị xoá khỏi đĩa.
    _buffer.remove(key);
    if (_prefs != null) {
      await _prefs.remove(key);
      return;
    }
    _fallback.remove(key);
  }

  /// X19: mọi key đang tồn tại. Cùng lý do với [exportAll] — dùng API generic
  /// thay vì hand-list `StorageKeys`, để `resetProgress()` không phải nhớ cập
  /// nhật danh sách mỗi khi thêm key mới (danh sách tay đó đã trôi lại phía
  /// sau qua 5 round và là root cause của X19).
  Set<String> allKeys() =>
      {...?_prefs?.getKeys(), ..._fallback.keys, ..._buffer.keys};

  /// Dump toàn bộ storage hiện có thành map — dùng API generic của
  /// SharedPreferences (getKeys/get) thay vì hand-list từng StorageKeys, để
  /// không phải nhớ cập nhật danh sách này mỗi khi thêm key mới.
  Map<String, Object> exportAll() {
    final prefs = _prefs;
    // X24: giá trị đang đệm phải đè lên bản trên đĩa — backup và
    // `resetProgress` đều đọc qua đây, cả hai cần trạng thái mới nhất.
    if (prefs == null) return {..._fallback, ..._buffer};
    return {
      for (final k in prefs.getKeys()) k: prefs.get(k) as Object,
      ..._buffer,
    };
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
    // X24: import ghi đè toàn bộ profile — mọi giá trị đang đệm không còn ý
    // nghĩa và sẽ ghi đè ngược lên dữ liệu vừa khôi phục nếu flush sau đó.
    _buffer.clear();
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

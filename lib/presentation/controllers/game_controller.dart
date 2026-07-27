import 'dart:async';
import 'dart:math';

import 'package:get/get.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../core/audio_manager.dart';
import '../../core/storage_service.dart';
import '../../core/utils/comeback_bonus.dart';
import '../../core/utils/friend_code.dart';
import '../../core/utils/weekend_event.dart';
import '../../data/achievements.dart';
import '../../data/board_frames.dart';
import '../../data/burst_styles.dart';
import '../../data/combo_text_styles.dart';
import '../../data/gauntlet_modifiers.dart';
import '../../data/levels.dart';
import '../../data/lucky_color.dart';
import '../../data/mascot_skins.dart';
import '../../data/perks.dart';
import '../../data/weekly_featured.dart';
import '../../data/weekly_goal.dart';
import '../../game/pop_star_game.dart';
import '../../logic/challenge_code.dart';
import '../../logic/craft_points.dart';
import '../../logic/daily_challenge.dart';
import '../../logic/gift_tile.dart';
import '../../logic/login_streak.dart';
import '../../logic/puzzle_code.dart';

/// F8: campaign (200 màn có target/sao/mở khoá) vs side-mode biệt lập
/// (không đụng unlockedLevel/coin-campaign/star). F12: endless thêm vào nhóm
/// side-mode, không target/thắng-thua, chỉ ghi high-score riêng. I42:
/// puzzleLab chơi bàn tự vẽ, không thưởng coin/sao/unlock/best-score. I43:
/// bossRush cũng thuộc nhóm side-mode (chỉ khác coin thưởng theo chuỗi, xem
/// `BossRushController`), không booster/hint (chặn ở tầng UI, xem
/// `boss_rush_screen.dart`).
enum GameMode {
  campaign,
  timeAttack,
  zen,
  endless,
  dailyChallenge,
  puzzleLab,
  bossRush,
  mirrorMode,
  gauntlet,
  weeklyFeatured,
}

/// I7: 1 ô phần thưởng trên vòng quay hằng ngày.
class SpinReward {
  const SpinReward(this.type, this.amount);
  final String type; // 'coins' | 'bomb' | 'shuffle' | 'undo'
  final int amount;
}

/// Điều khiển 1 ván Pop Star Blast: level đang chơi, điểm, sao, xu, booster.
class GameController extends GetxController {
  final mode = GameMode.campaign.obs;
  final coins = 0.obs;
  final score = 0.obs;
  final Rx<PopLevel?> currentLevelRx = Rx<PopLevel?>(null);
  final starsEarned = 0.obs;
  final ended = false.obs;
  final cleared = false.obs;

  /// I49: index màu "may mắn" của ngày hôm nay, tính lại mỗi lần startLevel
  /// (deterministic theo ngày qua [luckyColorIndexForDay], không cần persist).
  final luckyColorIndex = 0.obs;

  /// F6b: tiến độ mục tiêu ngoài điểm (số ô/obstacle còn lại cần dọn). Luôn 0
  /// khi `currentLevel.objective` là `score` (không dùng tới).
  final objectiveRemaining = 0.obs;

  /// F9: số ô màu [collect] đã sẵn trên bàn lúc bắt đầu màn (chụp ở lần gọi
  /// [updateObjectiveProgress] đầu tiên, trước khi có pop nào) — dùng để suy
  /// ra số đã thu được (initial - current) vì `collect` là mục tiêu thu 1
  /// phần, không phải dọn sạch như `clearColor`.
  int? _collectInitial;

  /// F9: số lượt tap-pop đã dùng trong màn hiện tại — dùng cho bonus sao của
  /// `moveLimitBonus`/`obstacleInMoves`. Không ảnh hưởng thắng/thua.
  final movesUsed = 0.obs;

  /// F6b: đọc lại [grid] sau mỗi lần bàn ổn định để cập nhật tiến độ mục
  /// tiêu — gọi từ `PopStarGame._checkEnd` (cùng nhịp với check thắng/kẹt).
  void updateObjectiveProgress(List<List<int?>> grid) {
    final objective = currentLevel.objective;
    objectiveRemaining.value = switch (objective.type) {
      ObjectiveType.score => 0,
      ObjectiveType.moveLimitBonus => 0,
      ObjectiveType.clearColor =>
        grid.expand((row) => row).where((v) => v == objective.color).length,
      ObjectiveType.clearObstacle || ObjectiveType.obstacleInMoves =>
        grid.expand((row) => row).where((v) => v != null && v < 0).length,
      ObjectiveType.collect => _collectRemaining(grid, objective),
      ObjectiveType.openGift =>
        grid.expand((row) => row).where((v) => v == giftTileValue).length,
    };
  }

  int _collectRemaining(List<List<int?>> grid, LevelObjective objective) {
    final current = grid
        .expand((row) => row)
        .where((v) => v == objective.color)
        .length;
    _collectInitial ??= current;
    final collected = _collectInitial! - current;
    return (objective.target! - collected).clamp(0, objective.target!);
  }

  /// F6b: màn có mục tiêu ngoài điểm và đã dọn xong — thắng ngay dù bàn chưa
  /// hết/kẹt (điểm vẫn tính sao như thường qua [_computeStars]). F9:
  /// `moveLimitBonus` không phải điều kiện thắng (giống `score`) — chỉ cộng
  /// sao bonus khi màn kết thúc bình thường.
  bool get objectiveMet =>
      currentLevel.objective.type != ObjectiveType.score &&
      currentLevel.objective.type != ObjectiveType.moveLimitBonus &&
      objectiveRemaining.value == 0;

  final bombCount = 0.obs;
  final shuffleCount = 0.obs;
  final undoCount = 0.obs;
  final rainbowCount = 0.obs;
  final swapCount = 0.obs;
  final freezeCount = 0.obs;

  /// I5: undo đầu tiên mỗi màn miễn phí, không trừ `undoCount`. F14: perk
  /// `extra_undo` active thì cộng thêm 1 (2 lượt undo miễn phí).
  int _freeUndoLeft = 0;
  bool get hasFreeUndo => _freeUndoLeft > 0;

  /// I31: gợi ý nhóm pop tốt nhất, miễn phí theo màn/ván — KHÔNG lưu đĩa,
  /// KHÔNG tính vào `totalBoostersUsed`/achievement (khác các booster mua
  /// bằng xu ở trên).
  static const int hintsPerRun = 3;
  final hintCount = hintsPerRun.obs;

  /// Combo: nổ liên tiếp trong cửa sổ thời gian → hệ số điểm tăng dần.
  final comboCount = 0.obs;
  final comboMultiplier = 1.0.obs;
  static const double comboWindow = 3.0; // giây giữa 2 lần nổ để giữ combo
  static const double comboMax = 5.0;

  /// Tăng mỗi lần nổ nhóm lớn/combo cao → UI hiện flash trắng ngắn (G2).
  final flashTick = 0.obs;
  void triggerFlash() => flashTick.value++;

  /// I39: tăng khi combo chạm mốc cố định ([kComboMilestones]) → UI hiện
  /// text "COMBO x{N}!" bay lên. [comboMilestoneValue] là mốc vừa chạm, đọc
  /// bởi UI ngay sau khi tick đổi (không phải Rx vì chỉ cần đọc 1 lần/tick).
  final comboMilestoneTick = 0.obs;
  int comboMilestoneValue = 0;
  void triggerComboMilestone(int milestone) {
    comboMilestoneValue = milestone;
    comboMilestoneTick.value++;
  }

  /// Set bởi [PopStarGame.onLoad] khi bàn được dựng — dùng để booster gọi
  /// thẳng vào game (bomb/shuffle/undo đều thao tác trực tiếp trên grid).
  PopStarGame? activeGame;

  /// F13: bàn Daily Challenge hôm nay, sinh 1 lần trong [startDailyChallenge]
  /// — [PopStarGame] dùng làm bàn cố định thay vì random.
  List<List<int>>? dailyChallengeGrid;

  /// I42 Puzzle Lab: bàn tự vẽ đang chơi, sinh từ editor hoặc mã nhập/lưu —
  /// [PopStarGame] dùng làm bàn cố định thay vì random, giống
  /// [dailyChallengeGrid].
  List<List<int>>? puzzleLabGrid;

  /// I33 Daily Modifier Gauntlet: bàn hôm nay + modifier đang áp dụng, sinh 1
  /// lần trong [startGauntlet] — giống [dailyChallengeGrid].
  List<List<int>>? gauntletGrid;
  GauntletModifier? activeGauntletModifier;

  /// I33: combo timer rút ngắn khi đang chơi Gauntlet với modifier
  /// `shortCombo` — `null` ngoài mode Gauntlet để tránh giá trị cũ còn sót
  /// lại sau khi đổi sang mode khác (xem [PopStarGame]).
  double? get gauntletComboWindowOverride => mode.value == GameMode.gauntlet
      ? activeGauntletModifier?.comboWindowOverride
      : null;

  PopLevel get currentLevel => currentLevelRx.value!;

  /// Màn cao nhất đã mở khoá. Observable để LevelSelect refresh ngay khi thắng
  /// (getter đọc-thẳng-storage cũ không reactive → grid không cập nhật lúc quay
  /// lại màn chọn level).
  final unlockedLevel = 1.obs;

  /// I27 Prestige/New Game+: tier hiện tại (0 = chưa prestige). Tái dùng
  /// đúng 220 level có sẵn, chỉ nhân độ khó lên theo tier
  /// ([prestigeTargetScore]).
  final prestigeTier = 0.obs;

  /// Đã thắng level cuối (`kLevelCount`, ≥1 sao) ở tier hiện tại chưa —
  /// KHÔNG dùng `unlockedLevel > kLevelCount` làm điều kiện vì [_unlockNext]
  /// tự chặn ở đúng `kLevelCount`, giá trị đó không bao giờ vượt qua được.
  final allLevelsCompletedOnce = false.obs;

  /// Đã hoàn thành hết 220 level ở tier hiện tại → đủ điều kiện Prestige.
  bool get canPrestige => allLevelsCompletedOnce.value;

  static const int prestigeRewardCoins = 1000;

  /// Reset [unlockedLevel] về 1, tăng [prestigeTier] — không đụng
  /// high-score/star cũ (không phạt lịch sử chơi), thưởng coin cố định.
  /// Reset [allLevelsCompletedOnce] để tier mới lại cần thắng level cuối lần
  /// nữa (target đã nặng hơn theo [prestigeTargetScore]).
  /// Không làm gì nếu chưa đủ điều kiện [canPrestige] (tránh gọi nhầm/race
  /// khi UI chưa kịp ẩn nút).
  void prestige() {
    if (!canPrestige) return;
    prestigeTier.value++;
    unlockedLevel.value = 1;
    allLevelsCompletedOnce.value = false;
    coins.value += prestigeRewardCoins;
    StorageService.to.setInt(StorageKeys.prestigeTier, prestigeTier.value);
    StorageService.to.setInt(StorageKeys.unlockedLevel, unlockedLevel.value);
    StorageService.to.setBool(StorageKeys.allLevelsCompleted, false);
    StorageService.to.setInt(StorageKeys.coins, coins.value);
  }

  /// Set 1 lần ngay khi 1 màn mới vừa được mở khoá (id màn mới), để
  /// LevelSelectScreen phát hiện "vừa unlock" và chạy reveal animation dù
  /// state của nó đã tồn tại từ trước (không bị dispose lúc push GameScreen).
  /// Consumer tự set về null sau khi xử lý xong.
  final justUnlocked = Rxn<int>();

  /// F14: id perk đang active (tối đa 2), chọn ở màn hình riêng — không đổi
  /// giữa chừng ván vì màn đó không truy cập được lúc đang chơi.
  final activePerkIds = <String>[].obs;

  /// Perk đã mở khoá theo world đã hoàn thành (suy từ [unlockedLevel]).
  List<Perk> get unlockedPerksList => unlockedPerks(unlockedLevel.value);

  bool hasPerk(String id) =>
      activePerkIds.contains(id) && unlockedPerksList.any((p) => p.id == id);

  /// Bật/tắt 1 perk trong danh sách active, tối đa [max] cái cùng lúc.
  /// Thuần, test được: input/output là list id perk.
  static List<String> togglePerkSelection(
    List<String> active,
    String id, {
    int max = 2,
  }) {
    final next = List<String>.from(active);
    if (next.contains(id)) {
      next.remove(id);
    } else if (next.length < max) {
      next.add(id);
    }
    return next;
  }

  void togglePerk(String id) {
    activePerkIds.value = togglePerkSelection(activePerkIds, id);
    StorageService.to.setString(
      StorageKeys.activePerks,
      activePerkIds.join(','),
    );
  }

  // I22 Achievements: counter tích lũy đời (không reset giữa các ván).
  final totalGemsPopped = 0.obs;
  final maxComboEver = 0.obs;
  final levelsThreeStarred = 0.obs;
  final boardsFullyCleared = 0.obs;
  final totalBoostersUsed = 0.obs;
  final unlockedAchievementIds = <String>{}.obs;

  /// Set 1 lần khi vừa đạt mốc thành tựu mới, UI lắng nghe rồi tự clear.
  final justUnlockedAchievement = Rxn<Achievement>();

  /// I36: id achievement đang chọn làm danh hiệu hiển thị cạnh [playerName]
  /// (rỗng = không có danh hiệu).
  final activeAchievementTitleId = ''.obs;

  Achievement? get activeTitleAchievement {
    if (activeAchievementTitleId.value.isEmpty) return null;
    try {
      return kAchievements.firstWhere(
        (a) => a.id == activeAchievementTitleId.value,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> setActiveTitle(String achievementId) async {
    if (!unlockedAchievementIds.contains(achievementId)) return;
    activeAchievementTitleId.value = achievementId;
    await StorageService.to.setString(
      StorageKeys.activeAchievementTitleId,
      achievementId,
    );
  }

  Future<void> clearActiveTitle() async {
    activeAchievementTitleId.value = '';
    await StorageService.to.setString(StorageKeys.activeAchievementTitleId, '');
  }

  // I30 Mascot Wardrobe: id skin đang active + set id skin đã mở khoá. Skin
  // free ("classic") luôn có mặt trong [unlockedMascotSkinIds] mặc định.
  final activeMascotSkinId = kMascotSkins.first.id.obs;
  final unlockedMascotSkinIds = <String>{kMascotSkins.first.id}.obs;

  /// Skin đang active — phòng thủ id giả mạo/hỏng trong storage bằng cách
  /// fallback về skin đầu tiên (free) nếu không khớp id nào trong danh sách.
  MascotSkin get activeMascotSkin => kMascotSkins.firstWhere(
    (s) => s.id == activeMascotSkinId.value,
    orElse: () => kMascotSkins.first,
  );

  /// Mua skin bằng xu. False nếu skin không bán bằng xu (gated achievement),
  /// đã mở khoá rồi (tránh double-charge khi bấm liên tục/race), hoặc không
  /// đủ xu.
  bool buySkin(MascotSkin skin) {
    if (skin.coinPrice == null) return false;
    if (unlockedMascotSkinIds.contains(skin.id)) return false;
    if (coins.value < skin.coinPrice!) return false;
    coins.value -= skin.coinPrice!;
    unlockedMascotSkinIds.add(skin.id);
    StorageService.to.setInt(StorageKeys.coins, coins.value);
    StorageService.to.setString(
      StorageKeys.unlockedMascotSkins,
      unlockedMascotSkinIds.join(','),
    );
    return true;
  }

  /// Chọn skin làm active — chỉ thành công nếu đã mở khoá.
  bool selectMascotSkin(String id) {
    if (!unlockedMascotSkinIds.contains(id)) return false;
    activeMascotSkinId.value = id;
    StorageService.to.setString(StorageKeys.activeMascotSkin, id);
    return true;
  }

  // I52 Pop Burst Style Picker: kiểu hiệu ứng nổ đang chọn — mở khoá theo
  // [totalGemsPopped], không persist riêng "đã mở khoá" (suy trực tiếp từ
  // counter đời để tránh lệch dữ liệu).
  final activeBurstStyleKind = BurstStyleKind.spark.obs;

  /// Đổi style hiệu ứng nổ — chặn chọn style chưa đủ [totalGemsPopped] để mở
  /// khoá (phòng race/giả mạo qua storage trực tiếp).
  void setActiveBurstStyle(BurstStyleKind kind) {
    final style = kBurstStyles.firstWhere((s) => s.kind == kind);
    if (!isBurstStyleUnlocked(style, totalGemsPopped.value)) return;
    activeBurstStyleKind.value = kind;
    StorageService.to.setString(StorageKeys.activeBurstStyle, kind.name);
  }

  // I54 Combo Text Style: kiểu chữ combo-milestone đang chọn — mở khoá theo
  // [maxComboEver], không persist riêng "đã mở khoá" (suy trực tiếp từ
  // metric đời để tránh lệch dữ liệu).
  final activeComboTextStyleKind = ComboTextStyleKind.neon.obs;

  /// Đổi style chữ combo — chặn chọn style chưa đủ [maxComboEver] để mở khoá
  /// (phòng race/giả mạo qua storage trực tiếp).
  void setActiveComboTextStyle(ComboTextStyleKind kind) {
    final style = kComboTextStyles.firstWhere((s) => s.kind == kind);
    if (!isComboTextStyleUnlocked(style, maxComboEver.value)) return;
    activeComboTextStyleKind.value = kind;
    StorageService.to.setString(StorageKeys.activeComboTextStyle, kind.name);
  }

  // I51 Board Frame Cosmetics: id khung viền board đang chọn — mở khoá theo
  // [prestigeTier]/[unlockedAchievementIds], không persist riêng "đã mở khoá"
  // (suy trực tiếp từ state đời đã có để tránh lệch dữ liệu).
  final activeBoardFrameId = kBoardFrames.first.id.obs;

  /// Khung đang active — phòng thủ id giả mạo/hỏng trong storage bằng cách
  /// fallback về khung đầu tiên (`classic`, luôn mở khoá) nếu không khớp id.
  BoardFrame get activeBoardFrame => kBoardFrames.firstWhere(
    (f) => f.id == activeBoardFrameId.value,
    orElse: () => kBoardFrames.first,
  );

  /// Đổi khung viền board — chặn chọn khung chưa mở khoá (phòng race/giả mạo
  /// qua storage trực tiếp). Thuần cosmetic, không ảnh hưởng điểm/xu/booster.
  void setActiveBoardFrame(String id) {
    final frame = kBoardFrames.firstWhere((f) => f.id == id);
    if (!isBoardFrameUnlocked(
      frame,
      prestigeTier.value,
      unlockedAchievementIds,
    )) {
      return;
    }
    activeBoardFrameId.value = id;
    StorageService.to.setString(StorageKeys.activeBoardFrame, id);
  }

  /// Task #5: điểm cần vượt khi đang trong 1 lần Perfect Clear challenge
  /// (chụp trước khi chơi, vì [_saveBestScore] sẽ ghi đè `highScore` ngay khi
  /// thắng) — null khi không phải Perfect Clear.
  final perfectClearTarget = Rxn<int>();

  /// Set 1 lần khi vừa hoàn thành 1 lần Perfect Clear thành công, UI (dialog
  /// thắng) đọc rồi tự hiện badge.
  final perfectClearSuccess = false.obs;

  static const int perfectClearBonusCoins = 50;

  /// I32 Craft Booster: 'bomb'/'shuffle'/'undo' vừa quy đổi từ cell còn sót
  /// lại cuối màn thắng (không full-clear) — null nếu không đủ ngưỡng craft
  /// point. UI (dialog thắng) đọc rồi tự hiện dòng "+1 booster".
  final craftRewardType = Rxn<String>();

  static const int craftPointThreshold = 3;

  /// I37 Async Challenge Code: mã thách đấu đang chơi (null nếu vào level
  /// bình thường, không qua "Chơi ngay" ở màn nhập mã) — so điểm ở
  /// [checkEnd], không ảnh hưởng coin/sao/unlock bình thường.
  final activeChallenge = Rxn<ChallengeCode>();

  /// Kết quả so điểm với [activeChallenge] khi màn kết thúc — null nếu
  /// không có thách đấu đang chơi.
  final challengeWon = Rxn<bool>();

  /// Bắt đầu 1 level qua mã thách đấu — dùng nguyên [startLevel] (board
  /// random bình thường, không preset/replay) rồi gắn thêm mục tiêu so điểm.
  void startChallenge(ChallengeCode code) {
    startLevel(code.levelId);
    activeChallenge.value = code;
  }

  /// Public: [AchievementsScreen] dùng để hiển thị tiến độ mốc chưa mở khoá.
  int metricValue(AchievementMetric m) => switch (m) {
    AchievementMetric.totalGemsPopped => totalGemsPopped.value,
    AchievementMetric.maxComboEver => maxComboEver.value,
    AchievementMetric.levelsThreeStarred => levelsThreeStarred.value,
    AchievementMetric.boardsFullyCleared => boardsFullyCleared.value,
    AchievementMetric.totalBoostersUsed => totalBoostersUsed.value,
  };

  void _checkAchievements() {
    final metricValues = {
      for (final m in AchievementMetric.values) m: metricValue(m),
    };
    final newlyUnlocked = newlyUnlockedAchievementIds(
      metricValues,
      unlockedAchievementIds,
    );
    if (newlyUnlocked.isEmpty) return;
    var mascotSkinsChanged = false;
    for (final id in newlyUnlocked) {
      final a = kAchievements.firstWhere((e) => e.id == id);
      unlockedAchievementIds.add(id);
      coins.value += a.coinReward * weekendCoinMultiplier;
      justUnlockedAchievement.value = a;
      // I30: thành tựu mốc cao tự mở khoá skin gắn với nó (không tốn xu).
      for (final skin in kMascotSkins) {
        if (skin.unlockAchievementId == id &&
            unlockedMascotSkinIds.add(skin.id)) {
          mascotSkinsChanged = true;
        }
      }
    }
    StorageService.to.setString(
      StorageKeys.unlockedAchievements,
      unlockedAchievementIds.join(','),
    );
    StorageService.to.setInt(StorageKeys.coins, coins.value);
    if (mascotSkinsChanged) {
      StorageService.to.setString(
        StorageKeys.unlockedMascotSkins,
        unlockedMascotSkinIds.join(','),
      );
    }
  }

  /// I8: cuối tuần nhân đôi mọi coin thưởng (thắng level, chest, daily, spin).
  int get weekendCoinMultiplier => isWeekendEvent(DateTime.now()) ? 2 : 1;

  /// F7 Star road: tổng sao tốt nhất mọi màn + mốc rương xu.
  static const List<int> starRoadMilestones = [5, 15, 30, 50];
  static const List<int> starRoadRewards = [50, 100, 200, 400];
  final totalStars = 0.obs;
  final claimedChestMask = 0.obs;

  /// I26 (task #18): tên hiển thị dùng để tạo/hiển thị mã "so tài" bạn bè —
  /// không phải progress nên KHÔNG bị xoá trong [resetProgress].
  final playerName = ''.obs;

  Future<void> setPlayerName(String name) async {
    playerName.value = name.trim();
    await StorageService.to.setString(StorageKeys.playerName, playerName.value);
  }

  /// Mã "so tài" của chính mình, đóng gói name+totalStars+coins hiện tại.
  String myFriendCode() => encodeFriendCode(
    name: playerName.value,
    totalStars: totalStars.value,
    coins: coins.value,
  );

  /// F2 Daily reward: chuỗi ngày liên tiếp mở app + nhận thưởng (D1..D7 lặp).
  static const List<int> dailyRewards = [50, 80, 120, 160, 200, 260, 400];
  final dailyStreak = 0.obs;

  /// I7 Vòng quay hằng ngày: bảng thưởng + trọng số cố định (biệt lập F2).
  static const List<SpinReward> spinRewards = [
    SpinReward('coins', 50),
    SpinReward('coins', 100),
    SpinReward('coins', 200),
    SpinReward('bomb', 1),
    SpinReward('shuffle', 1),
    SpinReward('undo', 1),
    SpinReward('coins', 500),
  ];
  static const List<int> spinWeights = [30, 20, 8, 15, 15, 15, 2];

  /// F8 Time-attack: điểm cao nhất từng đạt (biệt lập, không phải highScore
  /// campaign theo id).
  final timeAttackBest = 0.obs;

  /// F12 Endless: điểm cao nhất từng đạt + bàn hiện tại (0-based, tăng mỗi
  /// khi dọn sạch bàn trước để bàn kế tiếp khó hơn).
  final endlessBest = 0.obs;
  int _endlessBoardIndex = 0;

  /// I47 Mirror Mode: điểm cao nhất từng đạt (bàn đối xứng gương cố định,
  /// không ramp độ khó — biệt lập, mirror [endlessBest]).
  final mirrorModeBest = 0.obs;

  /// I18: vẽ thêm symbol theo màu lên mỗi gem — hỗ trợ người mù màu.
  final colorblindMode = false.obs;

  /// I6 Battle-pass mùa (free-track only, không premium): mùa 28 ngày, điểm
  /// mùa cộng khi thắng level campaign (stars * 10), mốc thưởng coin/booster.
  static const int seasonLengthDays = 28;
  static const List<int> seasonMilestones = [50, 150, 300, 500, 800];
  static const List<SpinReward> seasonRewards = [
    SpinReward('coins', 100),
    SpinReward('coins', 200),
    SpinReward('bomb', 1),
    SpinReward('coins', 400),
    SpinReward('shuffle', 2),
  ];
  final seasonPoints = 0.obs;
  final claimedSeasonMask = 0.obs;

  /// I48 Login Streak Calendar: streak điểm danh liên tục (theo ngày thật,
  /// chống gian lận qua [_todayEpochDay]), ngày cuối đã điểm danh, và bitmask
  /// các ngày (1-7) đã nhận thưởng trong cycle 7 ngày hiện tại.
  static const Map<int, int> loginStreakRewards = {3: 20, 5: 40, 7: 100};
  final loginStreakCount = 0.obs;
  final lastLoginEpochDay = 0.obs;
  final loginStreakClaimedMask = 0.obs;

  /// I50 Weekly Goal Card: tiến độ pop gem cộng dồn xuyên suốt mọi mode
  /// (campaign + side-mode) trong tuần hiện tại (`_todayEpochDay() ~/ 7`),
  /// reset mỗi khi sang tuần mới. Thưởng 1 lần/tuần khi đạt [weeklyGoalTarget].
  static const int weeklyGoalRewardCoins = 100;
  final weeklyGoalProgress = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
    _checkLoginStreak();
  }

  void toggleColorblindMode() {
    colorblindMode.value = !colorblindMode.value;
    StorageService.to.setBool(StorageKeys.colorblindMode, colorblindMode.value);
  }

  void _load() {
    colorblindMode.value = StorageService.to.getBool(
      StorageKeys.colorblindMode,
    );
    coins.value = StorageService.to.getInt(StorageKeys.coins);
    bombCount.value = StorageService.to.getInt(StorageKeys.bombCount, def: 3);
    shuffleCount.value = StorageService.to.getInt(
      StorageKeys.shuffleCount,
      def: 1,
    );
    undoCount.value = StorageService.to.getInt(StorageKeys.undoCount, def: 1);
    rainbowCount.value = StorageService.to.getInt(StorageKeys.rainbowCount);
    swapCount.value = StorageService.to.getInt(StorageKeys.swapCount);
    freezeCount.value = StorageService.to.getInt(StorageKeys.freezeCount);
    unlockedLevel.value = StorageService.to.getInt(
      StorageKeys.unlockedLevel,
      def: 1,
    );
    prestigeTier.value = StorageService.to.getInt(StorageKeys.prestigeTier);
    allLevelsCompletedOnce.value = StorageService.to.getBool(
      StorageKeys.allLevelsCompleted,
    );
    claimedChestMask.value = StorageService.to.getInt(
      StorageKeys.claimedChests,
    );
    dailyStreak.value = StorageService.to.getInt(StorageKeys.dailyStreak);
    timeAttackBest.value = StorageService.to.getInt(StorageKeys.timeAttackBest);
    endlessBest.value = StorageService.to.getInt(StorageKeys.endlessBest);
    mirrorModeBest.value = StorageService.to.getInt(StorageKeys.mirrorModeBest);
    seasonPoints.value = StorageService.to.getInt(StorageKeys.seasonPoints);
    claimedSeasonMask.value = StorageService.to.getInt(
      StorageKeys.claimedSeasonMask,
    );
    activePerkIds.value =
        (StorageService.to.getString(StorageKeys.activePerks) ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList();
    totalGemsPopped.value = StorageService.to.getInt(
      StorageKeys.totalGemsPopped,
    );
    maxComboEver.value = StorageService.to.getInt(StorageKeys.maxComboEver);
    levelsThreeStarred.value = StorageService.to.getInt(
      StorageKeys.levelsThreeStarred,
    );
    boardsFullyCleared.value = StorageService.to.getInt(
      StorageKeys.boardsFullyCleared,
    );
    totalBoostersUsed.value = StorageService.to.getInt(
      StorageKeys.totalBoostersUsed,
    );
    unlockedAchievementIds.assignAll(
      (StorageService.to.getString(StorageKeys.unlockedAchievements) ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toSet(),
    );
    // I36: chỉ nhận lại danh hiệu đã lưu nếu id đó vẫn nằm trong achievement
    // đã unlock — phòng dữ liệu cũ/giả mạo trỏ tới id chưa (hoặc không còn)
    // được unlock.
    final storedTitleId =
        StorageService.to.getString(StorageKeys.activeAchievementTitleId) ?? '';
    activeAchievementTitleId.value =
        unlockedAchievementIds.contains(storedTitleId) ? storedTitleId : '';
    playerName.value =
        StorageService.to.getString(StorageKeys.playerName) ?? '';
    // I30 (audit fix): lọc theo id skin còn tồn tại trong kMascotSkins — id
    // giả mạo/của skin đã gỡ khỏi danh sách không tích luỹ mãi trong storage.
    final validSkinIds = kMascotSkins.map((s) => s.id).toSet();
    final storedSkins =
        (StorageService.to.getString(StorageKeys.unlockedMascotSkins) ?? '')
            .split(',')
            .where(validSkinIds.contains)
            .toSet();
    storedSkins.add(kMascotSkins.first.id); // skin free luôn mở khoá.
    unlockedMascotSkinIds.assignAll(storedSkins);
    final storedActiveId = StorageService.to.getString(
      StorageKeys.activeMascotSkin,
    );
    activeMascotSkinId.value = validSkinIds.contains(storedActiveId)
        ? storedActiveId!
        : kMascotSkins.first.id;
    // I52: validate lại theo BurstStyleKind hợp lệ + ngưỡng mở khoá hiện tại
    // (phòng storage bị sửa tay trỏ style chưa đủ điều kiện).
    final storedBurstKind = BurstStyleKind.values
        .where(
          (k) =>
              k.name ==
              StorageService.to.getString(StorageKeys.activeBurstStyle),
        )
        .firstOrNull;
    final storedBurstStyle = storedBurstKind == null
        ? null
        : kBurstStyles.firstWhere((s) => s.kind == storedBurstKind);
    activeBurstStyleKind.value =
        storedBurstStyle != null &&
            isBurstStyleUnlocked(storedBurstStyle, totalGemsPopped.value)
        ? storedBurstStyle.kind
        : BurstStyleKind.spark;
    // I54: validate lại theo ComboTextStyleKind hợp lệ + ngưỡng mở khoá hiện
    // tại (phòng storage bị sửa tay trỏ style chưa đủ điều kiện).
    final storedComboTextKind = ComboTextStyleKind.values
        .where(
          (k) =>
              k.name ==
              StorageService.to.getString(StorageKeys.activeComboTextStyle),
        )
        .firstOrNull;
    final storedComboTextStyle = storedComboTextKind == null
        ? null
        : kComboTextStyles.firstWhere((s) => s.kind == storedComboTextKind);
    activeComboTextStyleKind.value =
        storedComboTextStyle != null &&
            isComboTextStyleUnlocked(storedComboTextStyle, maxComboEver.value)
        ? storedComboTextStyle.kind
        : ComboTextStyleKind.neon;
    // I51: validate lại theo id khung hợp lệ + điều kiện mở khoá hiện tại
    // (phòng storage bị sửa tay trỏ khung chưa đủ điều kiện).
    final storedFrame = kBoardFrames
        .where(
          (f) =>
              f.id == StorageService.to.getString(StorageKeys.activeBoardFrame),
        )
        .firstOrNull;
    activeBoardFrameId.value =
        storedFrame != null &&
            isBoardFrameUnlocked(
              storedFrame,
              prestigeTier.value,
              unlockedAchievementIds,
            )
        ? storedFrame.id
        : kBoardFrames.first.id;
    weeklyGoalProgress.value = StorageService.to.getInt(
      StorageKeys.weeklyGoalProgress,
    );
    _recomputeTotalStars();
    _checkSeasonRollover();
    _checkWeeklyGoalRollover();
  }

  /// Chỉ số mùa hiện tại (28 ngày/mùa), tăng tự động theo ngày thật.
  int get currentSeasonIndex => _todayEpochDay() ~/ seasonLengthDays;

  /// Qua mùa mới → reset điểm mùa + mốc đã nhận (thưởng đã phát giữ nguyên,
  /// vì coin/booster đã cộng vào kho rồi, không bị thu lại).
  void _checkSeasonRollover() {
    final last = StorageService.to.getInt(StorageKeys.lastSeasonIndex, def: -1);
    final current = currentSeasonIndex;
    if (current == last) return;
    seasonPoints.value = 0;
    claimedSeasonMask.value = 0;
    StorageService.to.setInt(StorageKeys.seasonPoints, 0);
    StorageService.to.setInt(StorageKeys.claimedSeasonMask, 0);
    StorageService.to.setInt(StorageKeys.lastSeasonIndex, current);
  }

  /// I50: tuần hiện tại (7 ngày/tuần), tăng tự động theo ngày thật.
  int get currentWeekIndex => weekIndexForEpochDay(_todayEpochDay());

  /// Qua tuần mới → reset tiến độ mục tiêu tuần về 0 (không cộng dồn qua
  /// tuần, khác thưởng đã nhận vẫn giữ nguyên vì coin đã cộng vào kho rồi).
  void _checkWeeklyGoalRollover() {
    final last = StorageService.to.getInt(StorageKeys.weeklyGoalWeek, def: -1);
    final current = currentWeekIndex;
    if (current == last) return;
    weeklyGoalProgress.value = weeklyGoalProgressForWeek(
      previousWeek: last,
      currentWeek: current,
      previousProgress: weeklyGoalProgress.value,
    );
    StorageService.to.setInt(
      StorageKeys.weeklyGoalProgress,
      weeklyGoalProgress.value,
    );
    StorageService.to.setInt(StorageKeys.weeklyGoalWeek, current);
  }

  /// I50: cộng tiến độ mục tiêu tuần — gọi ở MỌI mode (campaign + side-mode,
  /// khác I49 Lucky Color chỉ áp dụng campaign), kẹp không vượt target.
  void addWeeklyGoalProgress(int amount) {
    if (amount <= 0) return;
    weeklyGoalProgress.value = min(
      weeklyGoalProgress.value + amount,
      weeklyGoalTarget,
    );
    StorageService.to.setInt(
      StorageKeys.weeklyGoalProgress,
      weeklyGoalProgress.value,
    );
  }

  /// Đã nhận thưởng mục tiêu tuần hiện tại chưa (chặn nhận 2 lần cùng tuần).
  bool get weeklyGoalClaimed =>
      StorageService.to.getInt(StorageKeys.weeklyGoalClaimedWeek, def: -1) ==
      currentWeekIndex;

  /// Nhận thưởng coin mục tiêu tuần khi đạt đủ [weeklyGoalTarget] và chưa
  /// nhận trong tuần hiện tại.
  bool claimWeeklyGoalReward() {
    if (weeklyGoalProgress.value < weeklyGoalTarget) return false;
    if (weeklyGoalClaimed) return false;
    coins.value += weeklyGoalRewardCoins * weekendCoinMultiplier;
    StorageService.to.setInt(
      StorageKeys.weeklyGoalClaimedWeek,
      currentWeekIndex,
    );
    StorageService.to.setInt(StorageKeys.coins, coins.value);
    return true;
  }

  void _addSeasonPoints(int amount) {
    seasonPoints.value += amount;
    StorageService.to.setInt(StorageKeys.seasonPoints, seasonPoints.value);
  }

  bool isSeasonClaimed(int index) =>
      (claimedSeasonMask.value >> index) & 1 == 1;

  bool canClaimSeason(int index) =>
      seasonPoints.value >= seasonMilestones[index] && !isSeasonClaimed(index);

  /// Nhận mốc mùa [index]: cộng coin/booster 1 lần, không cho re-claim.
  bool claimSeason(int index) {
    if (!canClaimSeason(index)) return false;
    claimedSeasonMask.value |= 1 << index;
    StorageService.to.setInt(
      StorageKeys.claimedSeasonMask,
      claimedSeasonMask.value,
    );
    final reward = seasonRewards[index];
    switch (reward.type) {
      case 'bomb':
        _grant(bombCount, StorageKeys.bombCount, reward.amount);
      case 'shuffle':
        _grant(shuffleCount, StorageKeys.shuffleCount, reward.amount);
      case 'undo':
        _grant(undoCount, StorageKeys.undoCount, reward.amount);
      default:
        coins.value += reward.amount * weekendCoinMultiplier;
        StorageService.to.setInt(StorageKeys.coins, coins.value);
    }
    return true;
  }

  void _recomputeTotalStars() {
    var sum = 0;
    for (var id = 1; id <= kLevelCount; id++) {
      sum += StorageService.to.getInt(StorageKeys.star(id));
    }
    totalStars.value = sum;
  }

  bool isChestClaimed(int index) => (claimedChestMask.value >> index) & 1 == 1;

  bool canClaimChest(int index) =>
      totalStars.value >= starRoadMilestones[index] && !isChestClaimed(index);

  /// Mở rương mốc [index]: cộng xu 1 lần, không cho re-claim sau restart.
  bool claimChest(int index) {
    if (!canClaimChest(index)) return false;
    claimedChestMask.value |= 1 << index;
    StorageService.to.setInt(StorageKeys.claimedChests, claimedChestMask.value);
    coins.value += starRoadRewards[index] * weekendCoinMultiplier;
    StorageService.to.setInt(StorageKeys.coins, coins.value);
    return true;
  }

  /// I48 Login Streak Calendar: gọi trong [onInit] sau [_load] — so ngày điểm
  /// danh cuối với hôm nay để tăng/giữ/reset streak; qua cycle 7 ngày mới thì
  /// xoá bitmask thưởng đã nhận (không thu lại thưởng cũ, chỉ mở lại slot mới).
  void _checkLoginStreak() {
    final today = _todayEpochDay();
    final prevDay = StorageService.to.getInt(
      StorageKeys.lastLoginEpochDay,
      def: -1,
    );
    final prevStreak = StorageService.to.getInt(StorageKeys.loginStreakCount);
    if (prevDay == today) {
      loginStreakCount.value = prevStreak;
      lastLoginEpochDay.value = prevDay;
      loginStreakClaimedMask.value = StorageService.to.getInt(
        StorageKeys.loginStreakClaimedMask,
      );
      return;
    }
    final newStreak = nextLoginStreak(
      previousEpochDay: prevDay,
      todayEpochDay: today,
      previousStreak: prevStreak,
    );
    var claimedMask = StorageService.to.getInt(
      StorageKeys.loginStreakClaimedMask,
    );
    final crossedCycle = (newStreak - 1) % 7 == 0 && newStreak > 1;
    if (newStreak == 1 || crossedCycle) claimedMask = 0;
    loginStreakCount.value = newStreak;
    lastLoginEpochDay.value = today;
    loginStreakClaimedMask.value = claimedMask;
    StorageService.to.setInt(StorageKeys.loginStreakCount, newStreak);
    StorageService.to.setInt(StorageKeys.lastLoginEpochDay, today);
    StorageService.to.setInt(StorageKeys.loginStreakClaimedMask, claimedMask);
  }

  /// Ngày trong cycle 7 ngày hiện tại (1..7) ứng với [loginStreakCount].
  int dayInCycle(int streak) => (streak - 1) % 7 + 1;

  /// Nhận thưởng ngày [dayInCycle] hiện tại nếu có mốc thưởng và chưa nhận.
  bool claimLoginStreakReward() {
    final day = dayInCycle(loginStreakCount.value);
    final reward = loginStreakRewards[day];
    if (reward == null) return false;
    if ((loginStreakClaimedMask.value >> day) & 1 == 1) return false;
    loginStreakClaimedMask.value |= 1 << day;
    coins.value += reward * weekendCoinMultiplier;
    StorageService.to.setInt(
      StorageKeys.loginStreakClaimedMask,
      loginStreakClaimedMask.value,
    );
    StorageService.to.setInt(StorageKeys.coins, coins.value);
    return true;
  }

  /// Số ngày kể từ epoch (UTC), kẹp không lùi dưới mốc lớn nhất từng thấy —
  /// chống gian lận bằng cách chỉnh lùi đồng hồ máy.
  int _todayEpochDay() {
    final current = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
    final maxSeen = StorageService.to.getInt(StorageKeys.maxEpochDaySeen);
    final today = current > maxSeen ? current : maxSeen;
    if (today > maxSeen) {
      StorageService.to.setInt(StorageKeys.maxEpochDaySeen, today);
    }
    return today;
  }

  /// I33: modifier Gauntlet hôm nay — dùng để hiện icon+tên trước khi vào
  /// chơi (xem `home_screen.dart`), không cần bắt đầu ván mới để biết.
  GauntletModifier get todaysGauntletModifier =>
      modifierForDay(_todayEpochDay());

  bool get canClaimDaily =>
      _todayEpochDay() !=
      StorageService.to.getInt(StorageKeys.lastClaimDay, def: -1);

  /// Nhận thưởng ngày: +1 streak nếu liên tiếp hôm qua, ngược lại reset về 1.
  /// Trả về số xu vừa nhận, hoặc null nếu hôm nay đã nhận rồi.
  int? claimDaily() {
    if (!canClaimDaily) return null;
    final today = _todayEpochDay();
    final last = StorageService.to.getInt(StorageKeys.lastClaimDay, def: -1);
    dailyStreak.value = last == today - 1 ? dailyStreak.value + 1 : 1;
    StorageService.to.setInt(StorageKeys.dailyStreak, dailyStreak.value);
    StorageService.to.setInt(StorageKeys.lastClaimDay, today);
    final reward =
        dailyRewards[(dailyStreak.value - 1) % dailyRewards.length] *
        weekendCoinMultiplier;
    coins.value += reward;
    StorageService.to.setInt(StorageKeys.coins, coins.value);
    return reward;
  }

  bool get canClaimSpin =>
      _todayEpochDay() !=
      StorageService.to.getInt(StorageKeys.lastSpinDay, def: -1);

  /// Ô đã "chốt" cho hôm nay, seed = ngày hiện tại → gọi bao nhiêu lần trong
  /// cùng 1 ngày cũng ra cùng kết quả (UI vòng quay chỉ animate tới ô này,
  /// không tự random riêng). Không đổi state, gọi được trước khi [claimSpin].
  SpinReward get todaySpinReward {
    final rnd = Random(_todayEpochDay());
    final total = spinWeights.reduce((a, b) => a + b);
    var r = rnd.nextInt(total);
    for (var i = 0; i < spinWeights.length; i++) {
      if (r < spinWeights[i]) return spinRewards[i];
      r -= spinWeights[i];
    }
    return spinRewards.last;
  }

  /// Nhận thưởng vòng quay hôm nay. Trả về null nếu đã quay rồi.
  SpinReward? claimSpin() {
    if (!canClaimSpin) return null;
    final reward = todaySpinReward;
    StorageService.to.setInt(StorageKeys.lastSpinDay, _todayEpochDay());
    switch (reward.type) {
      case 'bomb':
        _grant(bombCount, StorageKeys.bombCount, reward.amount);
      case 'shuffle':
        _grant(shuffleCount, StorageKeys.shuffleCount, reward.amount);
      case 'undo':
        _grant(undoCount, StorageKeys.undoCount, reward.amount);
      default:
        coins.value += reward.amount * weekendCoinMultiplier;
        StorageService.to.setInt(StorageKeys.coins, coins.value);
    }
    return reward;
  }

  void _grant(RxInt count, String key, int amount) {
    count.value += amount;
    StorageService.to.setInt(key, count.value);
  }

  /// I1: gift tile rơi tới đáy tự mở → cộng thưởng ngay (xem
  /// `logic/gift_tile.dart` cho bảng trọng số).
  void grantGiftReward(GiftReward reward) {
    switch (reward.type) {
      case 'bomb':
        _grant(bombCount, StorageKeys.bombCount, reward.amount);
      case 'shuffle':
        _grant(shuffleCount, StorageKeys.shuffleCount, reward.amount);
      case 'undo':
        _grant(undoCount, StorageKeys.undoCount, reward.amount);
      default:
        coins.value += reward.amount * weekendCoinMultiplier;
        StorageService.to.setInt(StorageKeys.coins, coins.value);
    }
  }

  static const int comebackBonusCoins = 300;

  /// I10: gọi 1 lần mỗi khi mở Home. Vắng >=3 ngày kể từ lần mở trước → tặng
  /// coin + 1 bomb + 1 shuffle, trả về số coin đã tặng; null nếu chưa đủ điều
  /// kiện. Luôn cập nhật lastOpenDay = hôm nay (mốc cho lần vắng kế tiếp).
  int? checkComebackBonus() {
    final today = _todayEpochDay();
    final last = StorageService.to.getInt(StorageKeys.lastOpenDay, def: -1);
    StorageService.to.setInt(StorageKeys.lastOpenDay, today);
    if (!needsComebackBonus(lastOpenEpochDay: last, todayEpochDay: today)) {
      return null;
    }
    final reward = comebackBonusCoins * weekendCoinMultiplier;
    coins.value += reward;
    StorageService.to.setInt(StorageKeys.coins, coins.value);
    _grant(bombCount, StorageKeys.bombCount, 1);
    _grant(shuffleCount, StorageKeys.shuffleCount, 1);
    return reward;
  }

  void startLevel(int levelId) {
    mode.value = GameMode.campaign;
    currentLevelRx.value = kLevels[levelId - 1];
    luckyColorIndex.value = luckyColorIndexForDay(
      _todayEpochDay(),
      currentLevel.colorCount,
    );
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    resetCombo();
    activeGame = null;
    _freeUndoLeft = hasPerk('extra_undo') ? 2 : 1;
    hintCount.value = hintsPerRun;
    movesUsed.value = 0;
    _collectInitial = null;
    perfectClearTarget.value = null;
    perfectClearSuccess.value = false;
    craftRewardType.value = null;
    activeChallenge.value = null;
    challengeWon.value = null;
  }

  /// Task #5: replay level đã qua ít nhất 1 sao, mục tiêu vượt best score
  /// hiện tại — thành công thưởng thêm [perfectClearBonusCoins], ngoài ra
  /// dùng nguyên luồng campaign (star/highscore vẫn cập nhật bình thường).
  void startPerfectClear(int levelId) {
    final target = StorageService.to.getInt(StorageKeys.highScore(levelId));
    startLevel(levelId);
    perfectClearTarget.value = target;
  }

  /// F8: bắt đầu 1 ván side-mode (Time-attack/Zen) — không đụng
  /// currentLevelRx/unlockedLevel của campaign.
  void startSideMode(GameMode sideMode) {
    mode.value = sideMode;
    currentLevelRx.value = sideMode == GameMode.timeAttack
        ? kTimeAttackLevel
        : kZenLevel;
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    resetCombo();
    activeGame = null;
    _freeUndoLeft = hasPerk('extra_undo') ? 2 : 1;
    hintCount.value = hintsPerRun;
    movesUsed.value = 0;
    _collectInitial = null;
  }

  /// F12: bắt đầu ván Endless mới, bàn đầu tiên (index 0, dễ nhất).
  void startEndless() {
    _endlessBoardIndex = 0;
    mode.value = GameMode.endless;
    currentLevelRx.value = endlessLevelForIndex(_endlessBoardIndex);
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    resetCombo();
    activeGame = null;
    _freeUndoLeft = hasPerk('extra_undo') ? 2 : 1;
    hintCount.value = hintsPerRun;
    movesUsed.value = 0;
    _collectInitial = null;
  }

  /// I47 Mirror Mode: bắt đầu ván mới, bàn đầu tiên đối xứng gương (bàn sinh
  /// thật ở `game_screen_controller.dart` qua `presetGrid`, mirror cách
  /// [startDailyChallenge]/[startPuzzleLevel] bơm bàn có sẵn).
  void startMirrorMode() {
    mode.value = GameMode.mirrorMode;
    currentLevelRx.value = kMirrorModeLevel;
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    resetCombo();
    activeGame = null;
    _freeUndoLeft = hasPerk('extra_undo') ? 2 : 1;
    hintCount.value = hintsPerRun;
    movesUsed.value = 0;
    _collectInitial = null;
  }

  /// F13: bắt đầu ván Daily Challenge — bàn sinh từ seed = ngày hiện tại
  /// (`Random(seed)` có seed, không `Random()` mặc định) nên mọi người chơi
  /// cùng ngày gặp cùng bàn.
  void startDailyChallenge() {
    mode.value = GameMode.dailyChallenge;
    currentLevelRx.value = kDailyChallengeLevel;
    dailyChallengeGrid = generateDailyChallengeGrid(_todayEpochDay());
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    resetCombo();
    activeGame = null;
    _freeUndoLeft = hasPerk('extra_undo') ? 2 : 1;
    hintCount.value = hintsPerRun;
    movesUsed.value = 0;
    _collectInitial = null;
  }

  /// I33: bắt đầu ván Gauntlet — modifier hôm nay chọn theo epoch-day
  /// ([modifierForDay], không `Random()`), bàn sinh từ cùng seed như Daily
  /// Challenge (tái dùng [generateDailyChallengeGrid]) nhưng colorCount có
  /// thể đổi theo modifier `fourColors`.
  void startGauntlet() {
    mode.value = GameMode.gauntlet;
    final modifier = modifierForDay(_todayEpochDay());
    activeGauntletModifier = modifier;
    currentLevelRx.value = gauntletLevelFor(modifier);
    gauntletGrid = generateDailyChallengeGrid(
      _todayEpochDay(),
      colorCount: modifier.colorCountOverride ?? dailyChallengeColorCount,
    );
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    resetCombo();
    activeGame = null;
    _freeUndoLeft = hasPerk('extra_undo') ? 2 : 1;
    hintCount.value = hintsPerRun;
    movesUsed.value = 0;
    _collectInitial = null;
  }

  /// I38: id level campaign được chọn làm "Level tuần này" — deterministic
  /// theo [currentWeekIndex] ([featuredLevelIdForWeek]). Nếu level đó chưa
  /// mở khoá (`unlockedLevel` chưa tới), tự thay bằng 1 level chắc chắn đã
  /// mở khoá thay vì chặn chơi bằng dialog — vẫn giữ tinh thần "mọi người
  /// cùng tuần thấy cùng thử thách" cho đa số người chơi đã tiến đủ xa.
  int get featuredLevelId {
    final picked = featuredLevelIdForWeek(currentWeekIndex);
    if (picked <= unlockedLevel.value) return picked;
    return currentWeekIndex % unlockedLevel.value + 1;
  }

  /// I38: bắt đầu ván Weekly Featured Level — chơi lại [featuredLevelId]
  /// không giới hạn số lần, không đụng star/highScore/unlock của level đó
  /// (chỉ đọc [kLevels], không gọi các hàm cập nhật progress campaign).
  void startWeeklyFeatured() {
    mode.value = GameMode.weeklyFeatured;
    currentLevelRx.value = kLevels[featuredLevelId - 1];
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    resetCombo();
    activeGame = null;
    _freeUndoLeft = hasPerk('extra_undo') ? 2 : 1;
    hintCount.value = hintsPerRun;
    movesUsed.value = 0;
    _collectInitial = null;
  }

  /// I42 Puzzle Lab: bắt đầu ván với bàn tự vẽ/nhập mã — mirror
  /// [startSideMode] (không cần reset perfectClearTarget/perfectClearSuccess
  /// vì Puzzle Lab không có Perfect Clear).
  void startPuzzleLevel(List<List<int>> grid) {
    mode.value = GameMode.puzzleLab;
    puzzleLabGrid = grid;
    final rows = grid.length;
    final cols = rows == 0 ? 0 : grid[0].length;
    currentLevelRx.value = PopLevel(
      id: -5,
      rows: rows,
      cols: cols,
      colorCount: kPuzzleMaxColorCount,
      targetScore: rows * cols * 6,
    );
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    resetCombo();
    activeGame = null;
    _freeUndoLeft = hasPerk('extra_undo') ? 2 : 1;
    hintCount.value = hintsPerRun;
    movesUsed.value = 0;
    _collectInitial = null;
  }

  /// I43: bắt đầu 1 lượt Boss Rush với bàn đầu tiên đã sinh sẵn (từ
  /// `BossRushController.startRun`) — mirror khuôn reset chung của các
  /// side-mode khác.
  void startBossRush(PopLevel level) {
    mode.value = GameMode.bossRush;
    currentLevelRx.value = level;
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    resetCombo();
    activeGame = null;
    _freeUndoLeft = hasPerk('extra_undo') ? 2 : 1;
    hintCount.value = hintsPerRun;
    movesUsed.value = 0;
    _collectInitial = null;
  }

  /// I43: gọi từ [PopStarGame] khi thắng 1 bàn Boss Rush — chỉ đổi level
  /// hiện tại, KHÔNG reset score/combo (chuỗi giữ nguyên điểm/đà tích lũy).
  void setBossRushLevel(PopLevel level) {
    currentLevelRx.value = level;
  }

  /// F13: đã ghi điểm Daily Challenge hôm nay chưa — chơi lại trong ngày
  /// không đè điểm cũ (giống `canClaimDaily`).
  bool get canRecordDailyChallengeScore =>
      _todayEpochDay() !=
      StorageService.to.getInt(StorageKeys.lastDailyChallengeDay, def: -1);

  /// F13: điểm Daily Challenge đã ghi nhận lần gần nhất (mọi ngày, không chỉ
  /// hôm nay) — dùng hiển thị kết quả ngay sau khi vừa chơi xong.
  int get dailyChallengeScoreToday =>
      StorageService.to.getInt(StorageKeys.dailyChallengeScore);

  /// I9: điểm Daily Challenge của riêng hôm nay — 0 nếu chưa chơi hôm nay,
  /// để leaderboard không hiển thị nhầm điểm của ngày trước như thể hôm nay.
  int get dailyChallengeScoreForLeaderboard =>
      canRecordDailyChallengeScore ? 0 : dailyChallengeScoreToday;

  void _saveDailyChallengeScore() {
    if (!canRecordDailyChallengeScore) return;
    StorageService.to.setInt(
      StorageKeys.lastDailyChallengeDay,
      _todayEpochDay(),
    );
    StorageService.to.setInt(StorageKeys.dailyChallengeScore, score.value);
  }

  /// I33: đã ghi điểm Gauntlet hôm nay chưa — mirror
  /// [canRecordDailyChallengeScore] (1 lượt tính điểm/ngày).
  bool get canRecordGauntletScore =>
      _todayEpochDay() !=
      StorageService.to.getInt(StorageKeys.lastGauntletDay, def: -1);

  /// I33: điểm Gauntlet đã ghi nhận lần gần nhất (mọi ngày).
  int get gauntletScoreToday =>
      StorageService.to.getInt(StorageKeys.gauntletScore);

  /// I33: điểm Gauntlet của riêng hôm nay — 0 nếu chưa chơi hôm nay, mirror
  /// [dailyChallengeScoreForLeaderboard].
  int get gauntletScoreForLeaderboard =>
      canRecordGauntletScore ? 0 : gauntletScoreToday;

  void _saveGauntletScore() {
    if (!canRecordGauntletScore) return;
    StorageService.to.setInt(StorageKeys.lastGauntletDay, _todayEpochDay());
    StorageService.to.setInt(StorageKeys.gauntletScore, score.value);
  }

  /// I38: best score TUẦN NÀY của Weekly Featured Level — tự về 0 khi tuần
  /// đổi (khác Daily Challenge/Gauntlet: đây là "best trong tuần" chỉ tăng
  /// không giảm giống `highScore(levelId)`, không phải "điểm lần chơi gần
  /// nhất", nên không cần thêm getter `...ForLeaderboard` riêng như 2 mode
  /// kia — giá trị này tự đúng cho cả hiển thị kết quả lẫn leaderboard).
  int get featuredLevelScore =>
      StorageService.to.getInt(StorageKeys.lastFeaturedWeekSeen, def: -1) ==
          currentWeekIndex
      ? StorageService.to.getInt(StorageKeys.featuredLevelScore)
      : 0;

  void _saveFeaturedLevelScore() {
    if (score.value <= featuredLevelScore) return;
    StorageService.to.setInt(
      StorageKeys.lastFeaturedWeekSeen,
      currentWeekIndex,
    );
    StorageService.to.setInt(StorageKeys.featuredLevelScore, score.value);
  }

  /// F12: bàn hiện tại vừa dọn sạch — chuyển sang bàn kế khó hơn, giữ nguyên
  /// điểm tích luỹ. Gọi từ [PopStarGame] khi `remaining == 0` ở mode endless.
  PopLevel advanceEndlessBoard() {
    _endlessBoardIndex++;
    final next = endlessLevelForIndex(_endlessBoardIndex);
    currentLevelRx.value = next;
    return next;
  }

  void _saveEndlessBest() {
    if (score.value > endlessBest.value) {
      endlessBest.value = score.value;
      StorageService.to.setInt(StorageKeys.endlessBest, score.value);
    }
  }

  void _saveMirrorModeBest() {
    if (score.value > mirrorModeBest.value) {
      mirrorModeBest.value = score.value;
      StorageService.to.setInt(StorageKeys.mirrorModeBest, score.value);
    }
  }

  void addScore(int points) => score.value += points;

  /// Ghi nhận 1 lần nổ nhóm: tăng combo, cộng điểm đã nhân hệ số.
  /// Trả về điểm thực cộng (để UI hiện popup).
  int registerPop(int baseScore, {int groupSize = 1}) {
    movesUsed.value++;
    comboCount.value++;
    comboMultiplier.value = (1 + (comboCount.value - 1) * 0.5).clamp(
      1.0,
      comboMax,
    );
    final gained = (baseScore * comboMultiplier.value).round();
    score.value += gained;
    AudioManager.maybe?.applyComboLayer(comboCount.value); // I12
    // I22 Achievements.
    totalGemsPopped.value += groupSize;
    StorageService.to.setInt(
      StorageKeys.totalGemsPopped,
      totalGemsPopped.value,
    );
    addWeeklyGoalProgress(
      groupSize,
    ); // I50: mọi mode, không phân biệt campaign.
    if (comboCount.value > maxComboEver.value) {
      maxComboEver.value = comboCount.value;
      StorageService.to.setInt(StorageKeys.maxComboEver, maxComboEver.value);
    }
    _checkAchievements();
    return gained;
  }

  void resetCombo() {
    comboCount.value = 0;
    comboMultiplier.value = 1.0;
    AudioManager.maybe?.applyComboLayer(0); // I12
  }

  void checkEnd(bool boardCleared) {
    if (ended.value) return;
    cleared.value = boardCleared;
    if (boardCleared) {
      // I22 Achievements: counter tích lũy đời, áp dụng mọi mode.
      boardsFullyCleared.value++;
      StorageService.to.setInt(
        StorageKeys.boardsFullyCleared,
        boardsFullyCleared.value,
      );
      _checkAchievements();
    }
    if (mode.value == GameMode.puzzleLab) {
      ended.value = true;
      return; // không thưởng coin/sao/unlock/best-score
    }
    if (mode.value != GameMode.campaign) {
      if (mode.value == GameMode.timeAttack) _saveTimeAttackBest();
      if (mode.value == GameMode.endless) _saveEndlessBest();
      if (mode.value == GameMode.mirrorMode) _saveMirrorModeBest();
      if (mode.value == GameMode.dailyChallenge) _saveDailyChallengeScore();
      if (mode.value == GameMode.gauntlet) _saveGauntletScore();
      if (mode.value == GameMode.weeklyFeatured) _saveFeaturedLevelScore();
      ended.value = true;
      return;
    }
    starsEarned.value = _computeStars();
    ended.value = true;
    if (activeChallenge.value != null) {
      challengeWon.value = score.value > activeChallenge.value!.score;
    }
    if (perfectClearTarget.value != null &&
        score.value > perfectClearTarget.value!) {
      perfectClearSuccess.value = true;
      coins.value += perfectClearBonusCoins * weekendCoinMultiplier;
      StorageService.to.setInt(StorageKeys.coins, coins.value);
    }
    if (starsEarned.value > 0) {
      _unlockNext();
      _saveBestScore();
      _grantCoins();
      _maybeRequestReview();
      _checkSeasonRollover();
      _addSeasonPoints(starsEarned.value * 10);
      // I27 Prestige: thắng đúng level cuối (kLevelCount) ≥1 sao → đủ điều
      // kiện Prestige. Không dùng unlockedLevel (đã bị _unlockNext chặn ở
      // kLevelCount) — phải bắt đúng lúc thắng level cuối.
      if (currentLevel.id == kLevelCount && !allLevelsCompletedOnce.value) {
        allLevelsCompletedOnce.value = true;
        StorageService.to.setBool(StorageKeys.allLevelsCompleted, true);
      }
      // I32 Craft Booster: bàn còn sót gem (không full-clear — full-clear đã
      // có clearBoardBonus riêng, không cộng trùng) đủ ngưỡng craft point →
      // đổi thành 1 booster ngẫu nhiên thay vì mất trắng.
      final grid = activeGame?.colorGrid;
      if (!boardCleared &&
          grid != null &&
          craftPointsForRemainingCells(grid) >= craftPointThreshold) {
        craftRewardType.value = _grantRandomBooster();
      }
    }
  }

  String _grantRandomBooster() {
    final type = ['bomb', 'shuffle', 'undo'][Random().nextInt(3)];
    switch (type) {
      case 'bomb':
        _grant(bombCount, StorageKeys.bombCount, 1);
      case 'shuffle':
        _grant(shuffleCount, StorageKeys.shuffleCount, 1);
      case 'undo':
        _grant(undoCount, StorageKeys.undoCount, 1);
    }
    return type;
  }

  /// X5: điều kiện thuần (test được) — hiện review prompt đúng 1 lần trong
  /// đời cài đặt, chỉ khi vừa đạt mốc tích cực (3 sao), không sau khi thua.
  static bool shouldRequestReview({
    required int stars,
    required bool alreadyShown,
  }) => stars == 3 && !alreadyShown;

  void _maybeRequestReview() {
    final already = StorageService.to.getBool(StorageKeys.hasShownReviewPrompt);
    if (!shouldRequestReview(stars: starsEarned.value, alreadyShown: already)) {
      return;
    }
    unawaited(
      StorageService.to.setBool(StorageKeys.hasShownReviewPrompt, true),
    );
    unawaited(_requestReviewSafely());
  }

  Future<void> _requestReviewSafely() async {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    } catch (_) {
      // Môi trường không có plugin gốc (vd unit test) → bỏ qua, không crash.
    }
  }

  void _saveTimeAttackBest() {
    if (score.value > timeAttackBest.value) {
      timeAttackBest.value = score.value;
      StorageService.to.setInt(StorageKeys.timeAttackBest, score.value);
    }
  }

  int _computeStars() {
    final target = prestigeTargetScore(currentLevel, prestigeTier.value);
    int stars;
    if (score.value < target) {
      stars = 0;
    } else if (score.value < target * 1.3) {
      stars = 1;
    } else if (score.value < target * 1.7) {
      stars = 2;
    } else {
      stars = 3;
    }
    if (stars > 0 && _underMoveLimitBonus()) stars = (stars + 1).clamp(0, 3);
    return stars;
  }

  /// F9: +1 sao bonus cho `moveLimitBonus`/`obstacleInMoves` nếu xong màn
  /// trong giới hạn lượt — không ảnh hưởng thắng/thua, chỉ cộng thêm khi đã
  /// đạt ít nhất 1 sao từ điểm.
  bool _underMoveLimitBonus() {
    final objective = currentLevel.objective;
    final limit = objective.moveLimit;
    if (limit == null) return false;
    return movesUsed.value <= limit;
  }

  void _unlockNext() {
    final next = currentLevel.id + 1;
    if (next > unlockedLevel.value && next <= kLevelCount) {
      StorageService.to.setInt(StorageKeys.unlockedLevel, next);
      unlockedLevel.value = next;
      justUnlocked.value = next;
    }
  }

  void _saveBestScore() {
    final id = currentLevel.id;
    final bestScore = StorageService.to.getInt(StorageKeys.highScore(id));
    if (score.value > bestScore) {
      StorageService.to.setInt(StorageKeys.highScore(id), score.value);
    }
    final bestStar = StorageService.to.getInt(StorageKeys.star(id));
    if (starsEarned.value > bestStar) {
      StorageService.to.setInt(StorageKeys.star(id), starsEarned.value);
      _recomputeTotalStars();
    }
    // I22 Achievements: chỉ tính lần đầu màn đạt 3 sao, tránh cộng lặp khi
    // replay level đã 3-sao.
    if (starsEarned.value == 3 && bestStar < 3) {
      levelsThreeStarred.value++;
      StorageService.to.setInt(
        StorageKeys.levelsThreeStarred,
        levelsThreeStarred.value,
      );
    }
    _checkAchievements();
  }

  void _grantCoins() {
    var reward = starsEarned.value * 20 * weekendCoinMultiplier;
    // F14: perk coin_bonus +10%.
    if (hasPerk('coin_bonus')) reward = (reward * 1.1).round();
    coins.value += reward;
    StorageService.to.setInt(StorageKeys.coins, coins.value);
  }

  static const bombPrice = 60;
  static const shufflePrice = 40;
  static const undoPrice = 30;
  static const rainbowPrice = 80;
  static const swapPrice = 50;
  static const freezePrice = 70;

  bool _buy(int price, RxInt count, String key) {
    if (coins.value < price) return false;
    coins.value -= price;
    count.value++;
    StorageService.to.setInt(StorageKeys.coins, coins.value);
    StorageService.to.setInt(key, count.value);
    return true;
  }

  bool buyBomb() => _buy(bombPrice, bombCount, StorageKeys.bombCount);
  bool buyShuffle() =>
      _buy(shufflePrice, shuffleCount, StorageKeys.shuffleCount);
  bool buyUndo() => _buy(undoPrice, undoCount, StorageKeys.undoCount);
  bool buyRainbow() =>
      _buy(rainbowPrice, rainbowCount, StorageKeys.rainbowCount);
  bool buySwap() => _buy(swapPrice, swapCount, StorageKeys.swapCount);
  bool buyFreeze() => _buy(freezePrice, freezeCount, StorageKeys.freezeCount);

  // I22 Achievements: gọi ở cuối mỗi nhánh dùng booster thành công.
  void _recordBoosterUsed() {
    totalBoostersUsed.value++;
    StorageService.to.setInt(
      StorageKeys.totalBoostersUsed,
      totalBoostersUsed.value,
    );
    _checkAchievements();
  }

  void useBomb(int row, int col) {
    if (mode.value == GameMode.bossRush) return;
    if (bombCount.value <= 0 || activeGame == null) return;
    if (!activeGame!.triggerBomb(row, col)) return;
    bombCount.value--;
    StorageService.to.setInt(StorageKeys.bombCount, bombCount.value);
    _recordBoosterUsed();
  }

  void useShuffle() {
    if (mode.value == GameMode.bossRush) return;
    if (shuffleCount.value <= 0 || activeGame == null) return;
    if (!activeGame!.shuffleBoard()) return;
    shuffleCount.value--;
    StorageService.to.setInt(StorageKeys.shuffleCount, shuffleCount.value);
    _recordBoosterUsed();
  }

  void useUndo() {
    if (mode.value == GameMode.bossRush) return;
    // I33: modifier "no_undo" khoá hẳn undo cho ván Gauntlet hôm nay.
    if (mode.value == GameMode.gauntlet &&
        activeGauntletModifier?.disableUndo == true) {
      return;
    }
    if (activeGame == null) return;
    // I5: lần undo đầu tiên mỗi màn miễn phí (F14: +1 nữa nếu có perk
    // extra_undo), không đụng undoCount.
    if (_freeUndoLeft > 0) {
      if (!activeGame!.undo()) return;
      _freeUndoLeft--;
      _recordBoosterUsed();
      return;
    }
    if (undoCount.value <= 0) return;
    if (!activeGame!.undo()) return;
    undoCount.value--;
    StorageService.to.setInt(StorageKeys.undoCount, undoCount.value);
    _recordBoosterUsed();
  }

  void useRainbow(int row, int col) {
    if (rainbowCount.value <= 0 || activeGame == null) return;
    if (!activeGame!.triggerRainbow(row, col)) return;
    rainbowCount.value--;
    StorageService.to.setInt(StorageKeys.rainbowCount, rainbowCount.value);
    _recordBoosterUsed();
  }

  /// F10: đổi màu 2 ô bất kỳ (không cần liền kề), không tự nổ.
  void useSwap(int row1, int col1, int row2, int col2) {
    if (swapCount.value <= 0 || activeGame == null) return;
    if (!activeGame!.triggerSwap(row1, col1, row2, col2)) return;
    swapCount.value--;
    StorageService.to.setInt(StorageKeys.swapCount, swapCount.value);
    _recordBoosterUsed();
  }

  /// F10: dùng ngay — N lượt tiếp theo obstacle không giảm bền dù nổ cạnh.
  static const int freezeTurns = 5;
  void useFreeze() {
    if (freezeCount.value <= 0 || activeGame == null) return;
    activeGame!.applyFreeze(freezeTurns);
    freezeCount.value--;
    StorageService.to.setInt(StorageKeys.freezeCount, freezeCount.value);
    _recordBoosterUsed();
  }

  /// I31: hiện ngay nhóm pop tốt nhất trong ~1.5s, bỏ qua idle timer của I4.
  /// Miễn phí theo ván, KHÔNG lưu đĩa, KHÔNG tính vào `totalBoostersUsed`.
  void useHint() {
    if (hintCount.value <= 0 || activeGame == null) return;
    if (!activeGame!.showHint()) return;
    hintCount.value--;
  }

  Future<void> resetProgress() async {
    final store = StorageService.to;
    await store.remove(StorageKeys.unlockedLevel);
    await store.remove(StorageKeys.coins);
    await store.remove(StorageKeys.bombCount);
    await store.remove(StorageKeys.shuffleCount);
    await store.remove(StorageKeys.undoCount);
    await store.remove(StorageKeys.rainbowCount);
    await store.remove(StorageKeys.swapCount);
    await store.remove(StorageKeys.freezeCount);
    await store.remove(StorageKeys.claimedChests);
    await store.remove(StorageKeys.lastClaimDay);
    await store.remove(StorageKeys.dailyStreak);
    await store.remove(StorageKeys.maxEpochDaySeen);
    await store.remove(StorageKeys.timeAttackBest);
    await store.remove(StorageKeys.endlessBest);
    await store.remove(StorageKeys.mirrorModeBest);
    await store.remove(StorageKeys.lastDailyChallengeDay);
    await store.remove(StorageKeys.dailyChallengeScore);
    await store.remove(StorageKeys.lastSpinDay);
    await store.remove(StorageKeys.lastOpenDay);
    await store.remove(StorageKeys.seasonPoints);
    await store.remove(StorageKeys.claimedSeasonMask);
    await store.remove(StorageKeys.lastSeasonIndex);
    await store.remove(StorageKeys.activePerks);
    await store.remove(StorageKeys.totalGemsPopped);
    await store.remove(StorageKeys.maxComboEver);
    await store.remove(StorageKeys.levelsThreeStarred);
    await store.remove(StorageKeys.boardsFullyCleared);
    await store.remove(StorageKeys.totalBoostersUsed);
    await store.remove(StorageKeys.unlockedAchievements);
    await store.remove(StorageKeys.activeAchievementTitleId);
    await store.remove(StorageKeys.prestigeTier);
    await store.remove(StorageKeys.allLevelsCompleted);
    await store.remove(StorageKeys.activeMascotSkin);
    await store.remove(StorageKeys.unlockedMascotSkins);
    await store.remove(StorageKeys.activeBurstStyle);
    await store.remove(StorageKeys.loginStreakCount);
    await store.remove(StorageKeys.lastLoginEpochDay);
    await store.remove(StorageKeys.loginStreakClaimedMask);
    await store.remove(StorageKeys.activeComboTextStyle);
    await store.remove(StorageKeys.weeklyGoalProgress);
    await store.remove(StorageKeys.weeklyGoalWeek);
    await store.remove(StorageKeys.weeklyGoalClaimedWeek);
    await store.remove(StorageKeys.lastGauntletDay);
    await store.remove(StorageKeys.gauntletScore);
    await store.remove(StorageKeys.lastFeaturedWeekSeen);
    await store.remove(StorageKeys.featuredLevelScore);
    await store.remove(StorageKeys.activeBoardFrame);
    for (var id = 1; id <= kLevelCount; id++) {
      await store.remove(StorageKeys.highScore(id));
      await store.remove(StorageKeys.star(id));
    }
    coins.value = 0;
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    currentLevelRx.value = null;
    activeGame = null;
    prestigeTier.value = 0;
    allLevelsCompletedOnce.value = false;
    loginStreakCount.value = 0;
    lastLoginEpochDay.value = 0;
    loginStreakClaimedMask.value = 0;
    weeklyGoalProgress.value = 0;
    _load();
    _checkLoginStreak();
  }
}

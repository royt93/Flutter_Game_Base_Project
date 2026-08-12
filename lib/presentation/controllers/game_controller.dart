import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:get/get.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../core/audio_manager.dart';
import '../../core/utils/clamped_clock.dart' as clamped;
import '../../core/home_widget_sync.dart';
import '../../core/storage_service.dart';
import '../../core/utils/comeback_bonus.dart';
import '../../core/utils/friend_code.dart';
import '../../core/utils/weekend_event.dart';
import '../../data/achievements.dart';
import '../../data/board_frames.dart';
import '../../data/burst_styles.dart';
import '../../data/clan.dart';
import '../../data/combo_text_styles.dart';
import '../../data/daily_quests.dart';
import '../../data/gauntlet_modifiers.dart';
import '../../data/levels.dart';
import '../../data/lucky_color.dart';
import '../../data/mascot_skins.dart';
import '../../data/perks.dart';
import '../../data/pigments.dart';
import '../../data/star_pets.dart';
import '../../data/weekly_featured.dart';
import '../../data/weekly_goal.dart';
import '../../game/pop_star_game.dart';
import 'raid_boss_controller.dart';
import '../../logic/challenge_code.dart';
import '../../logic/comeback_digest.dart';
import '../../logic/craft_points.dart';
import '../../logic/mystery_crate.dart';
import '../../logic/next_action.dart';
import '../../logic/second_chance.dart';
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
  passAndPlay,
  treasureMap,
  remixLevel,
  comboRush,
  frostRush,
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
  // I55: token bảo vệ login streak, mua qua cửa hàng như booster thường.
  final streakFreezeCount = 0.obs;

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

  /// I59: immutable-by-convention source board + per-turn mutable deep copy.
  List<List<int>>? passAndPlayBaseGrid;
  List<List<int>>? passAndPlayGrid;

  /// I33 Daily Modifier Gauntlet: bàn hôm nay + modifier đang áp dụng, sinh 1
  /// lần trong [startGauntlet] — giống [dailyChallengeGrid].
  List<List<int>>? gauntletGrid;
  GauntletModifier? activeGauntletModifier;
  GauntletModifier? activeTreasureMapModifier;
  GauntletModifier? activeEndlessModifier;

  /// I80 Remix Levels: modifier đang áp dụng cho level campaign đang được
  /// "remix", set trong [startRemixLevel].
  GauntletModifier? activeRemixModifier;

  /// I69: combo timer rút ngắn khi đang chơi với modifier `shortCombo`
  /// (đọc qua [activeGameplayModifier]) — `null` nếu mode không có override.
  double? get activeComboWindowOverride =>
      activeGameplayModifier?.comboWindowOverride;

  GauntletModifier? get activeGameplayModifier => switch (mode.value) {
    GameMode.gauntlet => activeGauntletModifier,
    GameMode.treasureMap => activeTreasureMapModifier,
    GameMode.endless => activeEndlessModifier,
    GameMode.remixLevel => activeRemixModifier,
    _ => null,
  };

  int? get activeMoveLimit => activeGameplayModifier?.moveLimit;
  int? get activeMinGroupSize => activeGameplayModifier?.minGroupSize;

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

  /// Round-8 I79: nếu [allLevelsCompletedOnce] đã lưu `true` từ trước khi
  /// campaign được mở rộng (vd bản cũ 240 màn → bản mới 260 màn), reset về
  /// `false` — người chơi phải thắng đúng level cuối MỚI mới đủ điều kiện
  /// Prestige, không được "chui" nhờ cờ cũ. Không đụng gì nếu chưa từng đạt
  /// cờ này, hoặc cờ đã được set đúng ở `kLevelCount` hiện tại.
  void _migrateAllLevelsCompletedFlag() {
    if (!allLevelsCompletedOnce.value) return;
    // Mặc định 0 (không phải `kLevelCount`): save cũ trước Round-8 chưa
    // từng ghi key này dù cờ đã `true` — phải coi là "chưa rõ, cần
    // migrate", không phải "vừa mới đạt ở kLevelCount hiện tại".
    final completedAtCount = StorageService.to.getInt(
      StorageKeys.allLevelsCompletedAtCount,
    );
    if (completedAtCount >= kLevelCount) return;
    allLevelsCompletedOnce.value = false;
    StorageService.to.setBool(StorageKeys.allLevelsCompleted, false);
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

  // I72 Milestone Journal: id -> epochDay lúc unlock, đọc trực tiếp bởi
  // dialog (không cần Rx — chỉ là feed lịch sử tĩnh, không hiển thị realtime).
  final Map<String, int> achievementUnlockDays = {};

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

  // I65 Star Pet Companion Habitat: tiền tệ riêng (Star Dust) + danh sách
  // pet sở hữu (nhiều instance cùng loại, khác skin mascot ở trên).
  final starDust = 0.obs;
  final starOwnedPets = <PetInstance>[].obs;
  final lastPetCollectMs = 0.obs;

  /// Xu idle đang chờ thu hoạch, tính tới thời điểm hiện tại — không mutate
  /// state, dùng để hiển thị preview trước khi người chơi bấm nút hốt.
  int get pendingIdlePetReward => idleRewardCoins(
    lastCollectMs: lastPetCollectMs.value,
    nowMs: nowMsClamped(),
    pets: starOwnedPets,
  );

  /// I82: id loại pet đang trang bị (rỗng = không trang bị). Tối đa 1 con.
  final equippedPetTypeId = ''.obs;

  PetType? get equippedPetType => equippedPetTypeId.value.isEmpty
      ? null
      : petTypeById(equippedPetTypeId.value);

  /// Trang bị pet — chỉ thành công nếu người chơi đang sở hữu ít nhất 1 con
  /// loại đó. Truyền chuỗi rỗng để tháo.
  bool equipPet(String typeId) {
    if (typeId.isNotEmpty) {
      if (petTypeById(typeId) == null) return false;
      if (!starOwnedPets.any((p) => p.typeId == typeId)) return false;
    }
    equippedPetTypeId.value = typeId;
    StorageService.to.setString(StorageKeys.equippedPet, typeId);
    return true;
  }

  /// I82: passive có hiệu lực lúc này không.
  ///
  /// **Loại trừ mọi mode dùng best-score** (time attack, combo rush, frost
  /// rush, endless, mirror): cho passive chạy ở đó thì mọi kỷ lục cũ đều bị vô
  /// hiệu vì người chơi mới có lợi thế người cũ không có khi lập kỷ lục.
  bool hasPetPassive(PetPassive passive) {
    if (_isBestScoreMode) return false;
    return equippedPetType?.passive == passive;
  }

  static const Set<GameMode> _bestScoreModes = {
    GameMode.timeAttack,
    GameMode.comboRush,
    GameMode.frostRush,
    GameMode.endless,
    GameMode.mirrorMode,
  };

  bool get _isBestScoreMode => _bestScoreModes.contains(mode.value);

  /// I82: số undo miễn phí đầu màn — gom về một chỗ thay vì lặp biểu thức ở
  /// 6 điểm `start*`. Perk F14 và passive pet cộng dồn, kẹp trần.
  int get _initialFreeUndo {
    var n = 1;
    if (hasPerk('extra_undo')) n++;
    if (hasPetPassive(PetPassive.extraUndo)) n++;
    return n > kMaxFreeUndoPerLevel ? kMaxFreeUndoPerLevel : n;
  }

  /// I82: số gợi ý mỗi ván, cùng khuôn với [_initialFreeUndo].
  int get _initialHints {
    var n = hintsPerRun;
    if (hasPetPassive(PetPassive.extraHint)) n++;
    return n > kMaxHintsPerRun ? kMaxHintsPerRun : n;
  }

  /// Ấp 1 pet loại [type] bằng Star Dust. False nếu không đủ Star Dust.
  bool hatchPet(PetType type) {
    if (starDust.value < type.hatchCost) return false;
    starDust.value -= type.hatchCost;
    starOwnedPets.add(
      PetInstance(typeId: type.id, hatchedAtMs: nowMsClamped()),
    );
    StorageService.to.setInt(StorageKeys.starDustCount, starDust.value);
    _persistOwnedPets();
    return true;
  }

  /// Hốt thưởng xu idle tích luỹ từ lần mở Habitat trước tới giờ, rồi reset
  /// mốc thời gian. 0 nếu chưa có pet hoặc chưa đủ thời gian trôi qua.
  int claimIdlePetReward() {
    final now = nowMsClamped();
    final reward = idleRewardCoins(
      lastCollectMs: lastPetCollectMs.value,
      nowMs: now,
      pets: starOwnedPets,
    );
    lastPetCollectMs.value = now;
    StorageService.to.setInt(StorageKeys.lastPetCollectTimestampMs, now);
    if (reward > 0) {
      coins.value += reward;
      StorageService.to.setInt(StorageKeys.coins, coins.value);
    }
    return reward;
  }

  void _persistOwnedPets() {
    StorageService.to.setString(
      StorageKeys.starOwnedPets,
      jsonEncode(starOwnedPets.map((p) => p.toJson()).toList()),
    );
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

  static const int mysteryCrateCost = 250;
  static const int mysteryCrateDuplicateRefund = 150;

  /// I63: Mở Mystery Crate tiêu [mysteryCrateCost] coin.
  /// Lọc pool cosmetic đã đủ điều kiện mở khoá nhưng CHƯA sở hữu/active.
  /// Trả về null nếu không đủ xu hoặc pool rỗng.
  CosmeticEntry? rollMysteryCrate({Random? rngOverride}) {
    if (coins.value < mysteryCrateCost) return null;

    final allEntries = getAllCosmeticEntries();
    final eligiblePool = <CosmeticEntry>[];

    for (final entry in allEntries) {
      switch (entry.kind) {
        case CosmeticKind.mascotSkin:
          final skin = entry.originalItem as MascotSkin;
          final isUnlocked = unlockedMascotSkinIds.contains(skin.id);
          final isEligible =
              skin.coinPrice != null ||
              (skin.unlockAchievementId != null &&
                  unlockedAchievementIds.contains(skin.unlockAchievementId));
          if (isEligible && !isUnlocked) {
            eligiblePool.add(entry);
          }
        case CosmeticKind.boardFrame:
          final frame = entry.originalItem as BoardFrame;
          final isUnlocked = isBoardFrameUnlocked(
            frame,
            prestigeTier.value,
            unlockedAchievementIds,
          );
          final isActive = activeBoardFrameId.value == frame.id;
          if (isUnlocked && !isActive) {
            eligiblePool.add(entry);
          }
        case CosmeticKind.burstStyle:
          final burst = entry.originalItem as BurstStyle;
          final isUnlocked = isBurstStyleUnlocked(burst, totalGemsPopped.value);
          final isActive = activeBurstStyleKind.value == burst.kind;
          if (isUnlocked && !isActive) {
            eligiblePool.add(entry);
          }
        case CosmeticKind.comboTextStyle:
          final combo = entry.originalItem as ComboTextStyle;
          final isUnlocked = isComboTextStyleUnlocked(
            combo,
            maxComboEver.value,
          );
          final isActive = activeComboTextStyleKind.value == combo.kind;
          if (isUnlocked && !isActive) {
            eligiblePool.add(entry);
          }
      }
    }

    if (eligiblePool.isEmpty) return null;

    // X27: roll TRƯỚC, trừ xu SAU. Bản cũ trừ 250 xu rồi mới gọi [rollCrate],
    // nên nhánh `item == null` bên dưới sẽ ăn mất xu mà không trả gì. Với code
    // hiện tại nhánh đó không với tới được (pool đã được kiểm rỗng ở trên),
    // nhưng thứ tự "trừ tiền trước, kiểm tra sau" là quả mìn cho bất kỳ ai sửa
    // [rollCrate] về sau.
    final rng = rngOverride ?? Random();
    final item = rollCrate(eligiblePool: eligiblePool, rng: rng);
    if (item == null) return null;

    coins.value -= mysteryCrateCost;
    StorageService.to.setInt(StorageKeys.coins, coins.value);

    switch (item.kind) {
      case CosmeticKind.mascotSkin:
        final skin = item.originalItem as MascotSkin;
        unlockedMascotSkinIds.add(skin.id);
        activeMascotSkinId.value = skin.id;
        StorageService.to.setString(
          StorageKeys.unlockedMascotSkins,
          unlockedMascotSkinIds.join(','),
        );
        StorageService.to.setString(StorageKeys.activeMascotSkin, skin.id);
      case CosmeticKind.boardFrame:
        final frame = item.originalItem as BoardFrame;
        setActiveBoardFrame(frame.id);
      case CosmeticKind.burstStyle:
        final burst = item.originalItem as BurstStyle;
        setActiveBurstStyle(burst.kind);
      case CosmeticKind.comboTextStyle:
        final combo = item.originalItem as ComboTextStyle;
        setActiveComboTextStyle(combo.kind);
    }

    return item;
  }

  // [prestigeTier]/[unlockedAchievementIds], không persist riêng "đã mở khoá"
  // (suy trực tiếp từ state đời đã có để tránh lệch dữ liệu).
  final activeBoardFrameId = kBoardFrames.first.id.obs;

  /// Khung đang active — phòng thủ id giả mạo/hỏng trong storage, và fallback
  /// về khung đầu tiên (`classic`, luôn mở khoá) nếu id không khớp HOẶC khung
  /// đang active không còn `isBoardFrameUnlocked()` (vd frame seasonal đã hết
  /// mùa — không xây "revert" riêng, tái dùng đúng fallback đã có).
  BoardFrame get activeBoardFrame {
    final frame = kBoardFrames.firstWhere(
      (f) => f.id == activeBoardFrameId.value,
      orElse: () => kBoardFrames.first,
    );
    if (!isBoardFrameUnlocked(
      frame,
      prestigeTier.value,
      unlockedAchievementIds,
      treasureMapCompleted: treasureMapCompleted.value,
    )) {
      return kBoardFrames.first;
    }
    return frame;
  }

  /// Đổi khung viền board — chặn chọn khung chưa mở khoá (phòng race/giả mạo
  /// qua storage trực tiếp). Thuần cosmetic, không ảnh hưởng điểm/xu/booster.
  void setActiveBoardFrame(String id) {
    final frame = kBoardFrames.firstWhere((f) => f.id == id);
    if (!isBoardFrameUnlocked(
      frame,
      prestigeTier.value,
      unlockedAchievementIds,
      treasureMapCompleted: treasureMapCompleted.value,
    )) {
      return;
    }
    activeBoardFrameId.value = id;
    StorageService.to.setString(StorageKeys.activeBoardFrame, id);
  }

  /// I73: chỉ sửa `activeBoardFrameId` khi id đã lưu KHÔNG còn tồn tại trong
  /// `kBoardFrames` (hỏng/frame bị xoá khỏi bản cập nhật) — cố ý KHÔNG đụng
  /// tới id của khung theo mùa chỉ đang tạm khoá ngoài khung thời gian: nếu
  /// ghi đè storage về classic lúc đó, sang mùa sau khung mở lại nhưng người
  /// chơi đã mất lựa chọn, phải tự chọn lại. Bằng cách chỉ sửa khi id thật sự
  /// hỏng, [activeBoardFrame] tự hiển thị fallback lúc khung đang khoá mà
  /// storage vẫn giữ nguyên id gốc — mùa sau tự hiện lại đúng khung đã chọn.
  void revalidateActiveBoardFrame() {
    final idExists = kBoardFrames.any((f) => f.id == activeBoardFrameId.value);
    if (!idExists) {
      final fallback = kBoardFrames.first.id;
      activeBoardFrameId.value = fallback;
      StorageService.to.setString(StorageKeys.activeBoardFrame, fallback);
    }
  }

  final treasureMapCount = 0.obs;
  final treasureMapCompleted = false.obs;

  bool consumeTreasureMap() {
    if (treasureMapCount.value <= 0) return false;
    treasureMapCount.value--;
    StorageService.to.setInt(
      StorageKeys.treasureMapCount,
      treasureMapCount.value,
    );
    return true;
  }

  void completeTreasureMap() {
    treasureMapCompleted.value = true;
    StorageService.to.setBool(StorageKeys.treasureMapCompleted, true);
  }

  // I62 Color Alchemy: pigment mua bằng xu được persist; pigment achievement
  // được suy trực tiếp từ unlockedAchievementIds. Override chỉ đổi màu render.
  final unlockedPigmentIds = <String>{kPigments.first.id}.obs;
  final gemColorOverrides = <int, String>{}.obs;

  bool isPigmentUnlocked(Pigment pigment) =>
      pigment.isFree ||
      unlockedPigmentIds.contains(pigment.id) ||
      (pigment.unlockAchievementId != null &&
          unlockedAchievementIds.contains(pigment.unlockAchievementId));

  bool buyPigment(Pigment pigment) {
    if (pigment.coinPrice == null || isPigmentUnlocked(pigment)) return false;
    if (coins.value < pigment.coinPrice!) return false;
    coins.value -= pigment.coinPrice!;
    unlockedPigmentIds.add(pigment.id);
    StorageService.to.setInt(StorageKeys.coins, coins.value);
    StorageService.to.setString(
      StorageKeys.unlockedPigments,
      unlockedPigmentIds.join(','),
    );
    return true;
  }

  bool setGemColorOverride(int slot, String pigmentId) {
    final pigment = kPigments.where((p) => p.id == pigmentId).firstOrNull;
    if (pigment == null || !isPigmentUnlocked(pigment)) return false;
    gemColorOverrides[slot] = pigmentId;
    StorageService.to.setString(
      StorageKeys.gemColorOverrides,
      encodeGemColorOverrides(gemColorOverrides),
    );
    return true;
  }

  void clearGemColorOverride(int slot) {
    gemColorOverrides.remove(slot);
    StorageService.to.setString(
      StorageKeys.gemColorOverrides,
      encodeGemColorOverrides(gemColorOverrides),
    );
  }

  /// Task #5: điểm cần vượt khi đang trong 1 lần Perfect Clear challenge
  /// (chụp trước khi chơi, vì [_saveBestScore] sẽ ghi đè `highScore` ngay khi
  /// thắng) — null khi không phải Perfect Clear.
  final perfectClearTarget = Rxn<int>();

  /// Set 1 lần khi vừa hoàn thành 1 lần Perfect Clear thành công, UI (dialog
  /// thắng) đọc rồi tự hiện badge.
  final perfectClearSuccess = false.obs;

  static const int perfectClearBonusCoins = 50;

  // I65: Star Dust thưởng mỗi lần thắng campaign 3 sao (mọi lần, không chỉ
  // lần đầu — cùng nếp với _grantCoins ở dưới), hoặc hoàn thành Daily
  // Challenge (1 lần/ngày, dùng chung guard canRecordDailyChallengeScore).
  static const int starDustPerThreeStarWin = 5;
  static const int starDustPerDailyChallenge = 10;

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

  /// I58: seeded QR challenge. score=0 marks the creator's first run.
  final activeSeedChallenge = Rxn<ChallengeSeedCode>();
  final seedChallengeWon = Rxn<bool>();

  /// Bắt đầu 1 level qua mã thách đấu — dùng nguyên [startLevel] (board
  /// random bình thường, không preset/replay) rồi gắn thêm mục tiêu so điểm.
  void startChallenge(ChallengeCode code) {
    startLevel(code.levelId);
    activeChallenge.value = code;
  }

  void startSeedChallenge(ChallengeSeedCode code) {
    startPuzzleLevel(generateDailyChallengeGrid(code.seed));
    activeSeedChallenge.value = code;
    seedChallengeWon.value = null;
  }

  /// Public: [AchievementsScreen] dùng để hiển thị tiến độ mốc chưa mở khoá.
  int metricValue(AchievementMetric m) => switch (m) {
    AchievementMetric.totalGemsPopped => totalGemsPopped.value,
    AchievementMetric.maxComboEver => maxComboEver.value,
    AchievementMetric.levelsThreeStarred => levelsThreeStarred.value,
    AchievementMetric.boardsFullyCleared => boardsFullyCleared.value,
    AchievementMetric.totalBoostersUsed => totalBoostersUsed.value,
    AchievementMetric.clanContribTotal => clanContribTotal.value,
  };

  /// Gộp chung với [_checkStickerMilestones] — cả 2 đều là "mốc tích luỹ tự
  /// động cộng xu" chạy trên cùng trigger (registerPop/checkEnd), gọi tách
  /// rời ở 4 call site trước đây dễ quên đồng bộ khi thêm trigger mới.
  void _checkAchievements() {
    _checkStickerMilestones();
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
      achievementUnlockDays[id] = todayEpochDay();
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
    StorageService.to.setString(
      StorageKeys.achievementUnlockDays,
      jsonEncode(achievementUnlockDays),
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
  ///
  /// X22: **cố ý** dùng `DateTime.now()` thô, KHÔNG qua [todayEpochDay] đã kẹp
  /// — đã cân nhắc và bác bỏ. Kẹp monotonic chỉ chặn được kiểu gian lận "nhảy
  /// tiến rồi lùi về" (pet idle, lượt Raid Boss): chặn bước lùi khiến mỗi lần
  /// gian lận đốt luôn thời gian thật. Nhưng ở đây người gian lận **muốn ở lại
  /// tương lai** — đặt máy sang thứ Bảy là xong. Kẹp monotonic sẽ khoá cứng
  /// trạng thái đó thành vĩnh viễn, tức là biến exploit tạm thời thành exploit
  /// không gỡ được. Tệ hơn hẳn hiện trạng.
  ///
  /// Đây là exploit "nhảy đồng hồ một chiều", không sửa được ở client nếu
  /// không có nguồn thời gian tin cậy từ server. Chấp nhận có chủ đích: game
  /// không có IAP/leaderboard thật nên người chơi tự nhân đôi coin của mình
  /// chỉ tự phá trải nghiệm của mình. Xem thêm `lib/core/utils/clamped_clock.dart`.
  int get weekendCoinMultiplier => isWeekendEvent(DateTime.now()) ? 2 : 1;

  /// F7 Star road: tổng sao tốt nhất mọi màn + mốc rương xu.
  static const List<int> starRoadMilestones = [5, 15, 30, 50];
  static const List<int> starRoadRewards = [50, 100, 200, 400];
  final totalStars = 0.obs;
  final claimedChestMask = 0.obs;

  // I77 Sticker Album: mốc "tổng cosmetic sở hữu" (mascot skin + board frame +
  // burst style + combo text style) tự động cộng xu, tương tự achievements —
  // không cần người chơi bấm nhận (khác kiểu star-road chest thủ công).
  static const List<int> stickerAlbumMilestones = [5, 10, 15, 20];
  static const List<int> stickerAlbumRewards = [50, 100, 200, 400];
  final claimedStickerMilestoneMask = 0.obs;

  /// Tổng số cosmetic đang sở hữu/mở khoá trên cả 4 hệ thống (tối đa 24:
  /// 6 mascot skin + 9 board frame + 5 burst style + 4 combo text style).
  int get totalCosmeticsOwned =>
      unlockedMascotSkinIds.length +
      kBoardFrames
          .where(
            (f) => isBoardFrameUnlocked(
              f,
              prestigeTier.value,
              unlockedAchievementIds,
              treasureMapCompleted: treasureMapCompleted.value,
            ),
          )
          .length +
      kBurstStyles
          .where((s) => isBurstStyleUnlocked(s, totalGemsPopped.value))
          .length +
      kComboTextStyles
          .where((s) => isComboTextStyleUnlocked(s, maxComboEver.value))
          .length;

  static final int _allStickerMilestonesMask =
      (1 << stickerAlbumMilestones.length) - 1;

  /// Gọi mỗi pop (qua [_checkAchievements]) — bỏ sớm khi đã nhận hết mốc để
  /// khỏi lặp lại phép tính [totalCosmeticsOwned] (18 mục) trên hot path sau
  /// khi không còn mốc nào để nhận nữa.
  void _checkStickerMilestones() {
    if (claimedStickerMilestoneMask.value == _allStickerMilestonesMask) {
      return;
    }
    final owned = totalCosmeticsOwned;
    var changed = false;
    for (var i = 0; i < stickerAlbumMilestones.length; i++) {
      if ((claimedStickerMilestoneMask.value >> i) & 1 == 1) continue;
      if (owned < stickerAlbumMilestones[i]) continue;
      claimedStickerMilestoneMask.value |= 1 << i;
      coins.value += stickerAlbumRewards[i] * weekendCoinMultiplier;
      changed = true;
    }
    if (!changed) return;
    StorageService.to.setInt(
      StorageKeys.stickerMilestonesClaimed,
      claimedStickerMilestoneMask.value,
    );
    StorageService.to.setInt(StorageKeys.coins, coins.value);
  }

  // I64 Star Constellation & Sky Shrine
  final starSeedCount = 0.obs;
  final claimedStarSeedMask = 0.obs;
  final activeSkyAura = 'default'.obs;

  bool isStarSeedClaimed(int index) =>
      (claimedStarSeedMask.value >> index) & 1 == 1;

  void claimStarSeedForConstellation(int index) {
    if (isStarSeedClaimed(index)) return;
    claimedStarSeedMask.value |= 1 << index;
    starSeedCount.value += 1;
    StorageService.to.setInt(
      StorageKeys.claimedStarSeedMask,
      claimedStarSeedMask.value,
    );
    StorageService.to.setInt(StorageKeys.starSeedCount, starSeedCount.value);
  }

  void setActiveSkyAura(String auraId) {
    activeSkyAura.value = auraId;
    StorageService.to.setString(StorageKeys.activeSkyAura, auraId);
  }

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

  /// I75 Combo Rush: điểm cao nhất từng đạt — không timer, thắng thua bằng
  /// cách giữ combo càng lâu càng tốt (bàn không refill nên ván tự kết thúc
  /// khi hết ô/kẹt), biệt lập với timeAttackBest.
  final comboRushBest = 0.obs;

  /// I76b Frost Rush: điểm cao nhất từng đạt trên bàn mật độ Ice Tile ép cao
  /// (`PopStarGame._placeForcedIceTiles`) — biệt lập với comboRushBest dù
  /// tái dùng cùng cơ chế combo.
  final frostRushBest = 0.obs;

  /// F12 Endless: điểm cao nhất từng đạt + bàn hiện tại (0-based, tăng mỗi
  /// khi dọn sạch bàn trước để bàn kế tiếp khó hơn).
  final endlessBest = 0.obs;
  int _endlessBoardIndex = 0;

  /// I47 Mirror Mode: điểm cao nhất từng đạt (bàn đối xứng gương cố định,
  /// không ramp độ khó — biệt lập, mirror [endlessBest]).
  final mirrorModeBest = 0.obs;

  /// I18: vẽ thêm symbol theo màu lên mỗi gem — hỗ trợ người mù màu.
  final colorblindMode = false.obs;

  /// I71: nới hit-test mép ngoài bàn cờ trong `cellAt()`. Rx thay vì cached
  /// field + refresh-method riêng trên `PopStarGame` — cùng pattern với
  /// [colorblindMode], luôn phản ánh giá trị mới nhất mà không cần plumbing
  /// refresh qua `GameScreenController.maybe`/app-resume lifecycle hook.
  final largerTapTargets = false.obs;

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
  /// chống gian lận qua [todayEpochDay]), ngày cuối đã điểm danh, và bitmask
  /// các ngày (1-7) đã nhận thưởng trong cycle 7 ngày hiện tại.
  static const Map<int, int> loginStreakRewards = {3: 20, 5: 40, 7: 100};
  final loginStreakCount = 0.obs;
  final lastLoginEpochDay = 0.obs;
  final loginStreakClaimedMask = 0.obs;

  /// I50 Weekly Goal Card: tiến độ pop gem cộng dồn xuyên suốt mọi mode
  /// (campaign + side-mode) trong tuần hiện tại (`todayEpochDay() ~/ 7`),
  /// reset mỗi khi sang tuần mới. Thưởng 1 lần/tuần khi đạt [weeklyGoalTarget].
  static const int weeklyGoalRewardCoins = 100;
  final weeklyGoalProgress = 0.obs;

  /// I66 Clan Lite: đóng góp gem-pop tuần này (reset theo tuần, cùng
  /// `currentWeekIndex` với Weekly Goal) và lifetime (không reset, dùng cho
  /// [AchievementMetric.clanContribTotal]). Thưởng pool 1 lần/tuần khi
  /// [clanPoolTotal] (cả clan, gồm NPC) đạt [clanGoalTarget].
  static const int clanGoalRewardCoins = 150;
  final clanContribWeek = 0.obs;
  final clanContribTotal = 0.obs;

  /// I67: ba quest cố định theo epoch-day, với tiến độ và claim độc lập.
  final dailyQuestProgress = <int>[0, 0, 0].obs;
  final dailyQuestClaimed = <int>{}.obs;
  final dailyQuests = <DailyQuest>[].obs;
  int _dailyQuestDay = -1;

  /// I74: đồng bộ home widget mỗi khi coin hoặc login streak đổi, thay cho
  /// gọi tay `syncHomeWidget(...)` rải rác ở từng chỗ cộng thưởng (dễ sót,
  /// vd `claimSpin()` từng thiếu). Trước đó dùng `debounce()` của GetX nhưng
  /// `Debouncer` nội bộ tạo `Timer` riêng mà `Worker.dispose()` không cancel
  /// được, Timer treo lại sau khi controller đã đóng — và `Get.reset()`
  /// (cách teardown chuẩn của test suite) còn không gọi `onClose()` nên dù
  /// tự quản lý Timer cũng không cứu được. Thay bằng `scheduleMicrotask` gộp
  /// nhiều lần đổi coins/loginStreak trong cùng 1 tick (vd loop mở khoá
  /// nhiều achievement) thành đúng 1 lần gọi platform channel — không dùng
  /// `Timer` nên không có gì để leak qua `Get.reset()`.
  Worker? _coinsSyncWorker;
  Worker? _loginStreakSyncWorker;
  bool _widgetSyncScheduled = false;

  void _scheduleWidgetSync([_]) {
    if (_widgetSyncScheduled) return;
    _widgetSyncScheduled = true;
    scheduleMicrotask(() {
      _widgetSyncScheduled = false;
      syncHomeWidget(streak: loginStreakCount.value, coins: coins.value);
    });
  }

  @override
  void onInit() {
    super.onInit();
    _load();
    _checkLoginStreak();
    checkDailyQuestRollover();
    // I74 fix: vài test gọi lại onInit() thủ công để giả lập reload app (vd
    // star_road_test.dart) — dispose worker cũ trước khi tạo mới để tránh
    // leak Worker cũ và để 2 field này không cần khai `late final` (chỉ gán
    // được 1 lần, crash `LateInitializationError` nếu onInit() chạy lần 2).
    _coinsSyncWorker?.dispose();
    _loginStreakSyncWorker?.dispose();
    _coinsSyncWorker = ever(coins, _scheduleWidgetSync);
    _loginStreakSyncWorker = ever(loginStreakCount, _scheduleWidgetSync);
    // `_load()`/`_checkLoginStreak()` ở trên đã set coins/streak TRƯỚC khi 2
    // Worker này tồn tại — `ever()` không bắt giá trị đã set trước lúc đăng
    // ký, nên nếu không gọi tay ở đây, widget sẽ đứng ở giá trị cũ cho tới
    // lần đổi coins/streak đầu tiên sau khi mở app.
    _scheduleWidgetSync();
  }

  @override
  void onClose() {
    // X24: đẩy nốt counter đang đệm trước khi controller biến mất.
    StorageService.to.flush();
    _coinsSyncWorker?.dispose();
    _loginStreakSyncWorker?.dispose();
    super.onClose();
  }

  void toggleColorblindMode() {
    colorblindMode.value = !colorblindMode.value;
    StorageService.to.setBool(StorageKeys.colorblindMode, colorblindMode.value);
  }

  void toggleLargerTapTargets() {
    largerTapTargets.value = !largerTapTargets.value;
    StorageService.to.setBool(
      StorageKeys.largerTapTargets,
      largerTapTargets.value,
    );
  }

  void _load() {
    colorblindMode.value = StorageService.to.getBool(
      StorageKeys.colorblindMode,
    );
    largerTapTargets.value = StorageService.to.getBool(
      StorageKeys.largerTapTargets,
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
    streakFreezeCount.value = StorageService.to.getInt(
      StorageKeys.streakFreezeCount,
    );
    // X27: kẹp ở nguồn. `def: 1` chỉ áp dụng khi key KHÔNG tồn tại — save hỏng
    // hoặc backup giả mạo có thể lưu thẳng giá trị 0/âm, và `def` không cứu
    // được. Giá trị đó làm `featuredLevelId` chia lấy dư cho 0 (crash ở màn
    // Home) và làm `kLevels[unlockedLevel - 1]` văng chỉ số. Kẹp tại đây thì
    // mọi consumer đều an toàn, không phải rải guard ở từng chỗ dùng.
    unlockedLevel.value = max(
      1,
      StorageService.to.getInt(StorageKeys.unlockedLevel, def: 1),
    );
    prestigeTier.value = StorageService.to.getInt(StorageKeys.prestigeTier);
    allLevelsCompletedOnce.value = StorageService.to.getBool(
      StorageKeys.allLevelsCompleted,
    );
    _migrateAllLevelsCompletedFlag();
    claimedChestMask.value = StorageService.to.getInt(
      StorageKeys.claimedChests,
    );
    claimedStickerMilestoneMask.value = StorageService.to.getInt(
      StorageKeys.stickerMilestonesClaimed,
    );
    dailyStreak.value = StorageService.to.getInt(StorageKeys.dailyStreak);
    timeAttackBest.value = StorageService.to.getInt(StorageKeys.timeAttackBest);
    comboRushBest.value = StorageService.to.getInt(StorageKeys.comboRushBest);
    frostRushBest.value = StorageService.to.getInt(StorageKeys.frostRushBest);
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
    clanContribTotal.value = StorageService.to.getInt(
      StorageKeys.clanContribTotal,
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
    // I72: nạp lại map ngày unlock đã lưu; bỏ qua id không còn hợp lệ
    // (giống cách unlockedMascotSkins lọc theo validSkinIds ngay bên dưới).
    achievementUnlockDays.clear();
    final storedUnlockDaysRaw = StorageService.to.getString(
      StorageKeys.achievementUnlockDays,
    );
    if (storedUnlockDaysRaw != null && storedUnlockDaysRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(storedUnlockDaysRaw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (unlockedAchievementIds.contains(entry.key)) {
            achievementUnlockDays[entry.key] = entry.value as int;
          }
        }
      } catch (_) {
        // Dữ liệu hỏng/giả mạo -> bỏ qua, feed chỉ thiếu mốc cũ chứ không crash.
      }
    }
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
    // I65: lọc theo typeId còn tồn tại trong kStarPetTypes, cùng lý do với
    // block skin ở trên — id hỏng/của type đã gỡ không được giữ lại.
    starDust.value = StorageService.to.getInt(StorageKeys.starDustCount);
    final storedPetsJson = StorageService.to.getString(
      StorageKeys.starOwnedPets,
    );
    // X18: `clear()` vô điều kiện TRƯỚC khi nạp — nếu chỉ `assignAll` bên
    // trong nhánh "có dữ liệu" thì sau [resetProgress] (key đã bị xoá) list Rx
    // vẫn giữ nguyên pet cũ trong bộ nhớ.
    starOwnedPets.clear();
    if (storedPetsJson != null && storedPetsJson.isNotEmpty) {
      // X18: save hỏng ở đây từng làm `onInit` ném và app KHÔNG BOOT ĐƯỢC
      // (`GameController` là `permanent: true`, dựng trong `main.dart`) —
      // người chơi phải gỡ cài đặt, mất sạch tiến độ. `jsonDecode` ném
      // `FormatException` với chuỗi không phải JSON, và `as List`/`as Map`
      // ném `TypeError` với JSON hợp lệ nhưng sai hình dạng. Cùng khuôn
      // try/catch với block `achievementUnlockDays` ở trên.
      //
      // Đường vào dữ liệu hỏng có thật: import backup từ nguồn không tin cậy,
      // app bị kill giữa `setString`, hoặc hạ version sau khi format đổi.
      try {
        final decoded = jsonDecode(storedPetsJson);
        if (decoded is List) {
          for (final entry in decoded) {
            // 1 phần tử hỏng không được giết cả list.
            if (entry is! Map) continue;
            final pet = PetInstance.fromJson(entry.cast<String, Object?>());
            if (pet != null && petTypeById(pet.typeId) != null) {
              starOwnedPets.add(pet);
            }
          }
        }
      } catch (_) {
        // Dữ liệu hỏng/giả mạo → bỏ pet, app vẫn boot với mọi state khác
        // nguyên vẹn (giống cách `achievementUnlockDays` chỉ thiếu mốc cũ).
      }
      // Ghi lại bản đã lọc để lần boot sau không phải parse lại rác.
      _persistOwnedPets();
    }
    lastPetCollectMs.value = StorageService.to.getInt(
      StorageKeys.lastPetCollectTimestampMs,
    );
    // I82: re-validate id pet đang trang bị theo bảng const hiện tại VÀ theo
    // pet đang thực sự sở hữu — cùng nếp với skin/frame/pigment ở trên.
    final storedPet =
        StorageService.to.getString(StorageKeys.equippedPet) ?? '';
    equippedPetTypeId.value =
        petTypeById(storedPet) != null &&
            starOwnedPets.any((p) => p.typeId == storedPet)
        ? storedPet
        : '';
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
              treasureMapCompleted: StorageService.to.getBool(
                StorageKeys.treasureMapCompleted,
              ),
            )
        ? storedFrame.id
        : kBoardFrames.first.id;
    // I64 Star Constellation & Sky Shrine
    starSeedCount.value = StorageService.to.getInt(StorageKeys.starSeedCount);
    claimedStarSeedMask.value = StorageService.to.getInt(
      StorageKeys.claimedStarSeedMask,
    );
    activeSkyAura.value =
        StorageService.to.getString(StorageKeys.activeSkyAura) ?? 'default';
    final validPigmentIds = kPigments.map((p) => p.id).toSet();
    final storedPigments =
        (StorageService.to.getString(StorageKeys.unlockedPigments) ?? '')
            .split(',')
            .where(validPigmentIds.contains)
            .toSet()
          ..add(kPigments.first.id);
    unlockedPigmentIds.assignAll(storedPigments);
    gemColorOverrides.assignAll(
      decodeGemColorOverrides(
        StorageService.to.getString(StorageKeys.gemColorOverrides),
      )..removeWhere((_, id) => !validPigmentIds.contains(id)),
    );
    weeklyGoalProgress.value = StorageService.to.getInt(
      StorageKeys.weeklyGoalProgress,
    );
    clanContribWeek.value = StorageService.to.getInt(
      StorageKeys.clanContribWeek,
    );
    dailyQuestProgress.assignAll(
      (StorageService.to.getString(StorageKeys.dailyQuestProgress) ?? '')
          .split(',')
          .map(int.tryParse)
          .whereType<int>()
          .take(3),
    );
    if (dailyQuestProgress.length != 3) {
      dailyQuestProgress.assignAll(const [0, 0, 0]);
    }
    dailyQuestClaimed.assignAll(
      (StorageService.to.getString(StorageKeys.dailyQuestClaimed) ?? '')
          .split(',')
          .map(int.tryParse)
          .whereType<int>()
          .where((i) => i >= 0 && i < 3),
    );
    treasureMapCount.value = StorageService.to.getInt(
      StorageKeys.treasureMapCount,
    );
    treasureMapCompleted.value = StorageService.to.getBool(
      StorageKeys.treasureMapCompleted,
    );
    _recomputeTotalStars();
    _checkSeasonRollover();
    _checkWeeklyGoalRollover();
    _checkClanGoalRollover();
  }

  int get currentDailyQuestDay => _dailyQuestDay;

  /// Re-evaluates daily state. [epochDay] is injectable for deterministic tests.
  void checkDailyQuestRollover({int? epochDay}) {
    final today = epochDay ?? todayEpochDay();
    final storedDay = StorageService.to.getInt(
      StorageKeys.dailyQuestDay,
      def: -1,
    );
    _dailyQuestDay = today;
    dailyQuests.assignAll(questsForDay(today));
    if (storedDay == today) return;
    dailyQuestProgress.assignAll(const [0, 0, 0]);
    dailyQuestClaimed.clear();
    StorageService.to.setInt(StorageKeys.dailyQuestDay, today);
    _persistDailyQuests();
  }

  /// X24: ghi đệm — hàm này nằm trên hot path qua [_addDailyQuestProgress]
  /// (mỗi cú tap). Nhánh nhận thưởng ([claimDailyQuest]) tự gọi
  /// `StorageService.to.flush()` để giao dịch xuống đĩa ngay.
  void _persistDailyQuests() {
    StorageService.to.setStringBuffered(
      StorageKeys.dailyQuestProgress,
      dailyQuestProgress.join(','),
    );
    StorageService.to.setStringBuffered(
      StorageKeys.dailyQuestClaimed,
      dailyQuestClaimed.join(','),
    );
  }

  void _addDailyQuestProgress(QuestKind kind, int amount) {
    if (amount <= 0) return;
    checkDailyQuestRollover();
    for (var i = 0; i < dailyQuests.length; i++) {
      final quest = dailyQuests[i];
      if (quest.kind == kind) {
        dailyQuestProgress[i] = min(
          quest.target,
          dailyQuestProgress[i] + amount,
        );
      }
    }
    _persistDailyQuests();
  }

  bool claimDailyQuest(int index) {
    checkDailyQuestRollover();
    if (index < 0 || index >= dailyQuests.length) return false;
    if (dailyQuestClaimed.contains(index)) return false;
    if (dailyQuestProgress[index] < dailyQuests[index].target) return false;
    dailyQuestClaimed.add(index);
    coins.value += dailyQuests[index].coinReward;
    StorageService.to.setInt(StorageKeys.coins, coins.value);
    _persistDailyQuests();
    // X24: nhận thưởng là giao dịch thật — cờ "đã nhận" phải xuống đĩa cùng
    // lúc với xu, nếu không app bị kill giữa chừng là nhận được 2 lần.
    StorageService.to.flush();
    return true;
  }

  /// Chỉ số mùa hiện tại (28 ngày/mùa), tăng tự động theo ngày thật.
  int get currentSeasonIndex => todayEpochDay() ~/ seasonLengthDays;

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
  int get currentWeekIndex => weekIndexForEpochDay(todayEpochDay());

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
    _checkWeeklyGoalRollover();
    weeklyGoalProgress.value = min(
      weeklyGoalProgress.value + amount,
      weeklyGoalTarget,
    );
    // X24: hot path (gọi từ [registerPop] mỗi cú tap) -> ghi đệm.
    StorageService.to.setIntBuffered(
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
    _grantTreasureMap();
    return true;
  }

  /// I66: qua tuần mới → reset đóng góp clan tuần về 0 (đóng góp lifetime +
  /// thưởng đã nhận tuần trước giữ nguyên, cùng convention rollover I50).
  void _checkClanGoalRollover() {
    final last = StorageService.to.getInt(StorageKeys.clanGoalWeek, def: -1);
    final current = currentWeekIndex;
    if (current == last) return;
    clanContribWeek.value = 0;
    StorageService.to.setInt(StorageKeys.clanContribWeek, 0);
    StorageService.to.setInt(StorageKeys.clanGoalWeek, current);
  }

  /// I66: cộng đóng góp clan tuần này + lifetime — gọi song song
  /// [addWeeklyGoalProgress] tại [registerPop], mọi mode.
  void addClanContribution(int amount) {
    if (amount <= 0) return;
    _checkClanGoalRollover();
    clanContribWeek.value += amount;
    clanContribTotal.value += amount;
    // X24: hot path (cùng hook với [addWeeklyGoalProgress]) -> ghi đệm.
    StorageService.to.setIntBuffered(
      StorageKeys.clanContribWeek,
      clanContribWeek.value,
    );
    StorageService.to.setIntBuffered(
      StorageKeys.clanContribTotal,
      clanContribTotal.value,
    );
  }

  /// Tổng pool clan tuần này (NPC + người chơi).
  int get clanPoolThisWeek =>
      clanPoolTotal(currentWeekIndex, clanContribWeek.value);

  /// Đã nhận thưởng pool clan tuần hiện tại chưa (chặn nhận 2 lần cùng tuần).
  bool get clanGoalClaimed =>
      StorageService.to.getInt(StorageKeys.clanGoalClaimedWeek, def: -1) ==
      currentWeekIndex;

  /// Nhận thưởng coin pool clan khi cả clan đạt đủ [clanGoalTarget] và chưa
  /// nhận trong tuần hiện tại.
  bool claimClanGoalReward() {
    if (clanPoolThisWeek < clanGoalTarget) return false;
    if (clanGoalClaimed) return false;
    coins.value += clanGoalRewardCoins * weekendCoinMultiplier;
    StorageService.to.setInt(StorageKeys.clanGoalClaimedWeek, currentWeekIndex);
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

  /// I84: gom state rời rạc thành danh sách "làm gì tiếp theo".
  ///
  /// Toàn bộ luật xếp hạng nằm ở [rankNextActions] (thuần, test riêng); hàm
  /// này chỉ đọc state và **không** tự quyết định thứ tự — để đổi ưu tiên chỉ
  /// phải sửa đúng một chỗ.
  ///
  /// Raid Boss cố ý không đọc qua `RaidBossController`: controller đó chỉ tồn
  /// tại khi đang ở màn raid, còn Home cần biết ngay lúc dựng. Dùng vị từ
  /// thuần [isRaidActiveForEpochDay] + số lượt đã dùng trong ngày.
  List<NextAction> nextActions() {
    final today = todayEpochDay();
    final raidAttemptsUsed =
        StorageService.to.getInt(StorageKeys.raidBossLastAttemptDay, def: -1) ==
            today
        ? StorageService.to.getInt(StorageKeys.raidBossAttemptsUsed)
        : 0;

    return rankNextActions(
      canClaimDailyReward: canClaimDaily,
      canClaimSpin: canClaimSpin,
      questsReadyToClaim: _questsReadyToClaim(),
      weeklyGoalReady:
          weeklyGoalProgress.value >= weeklyGoalTarget && !weeklyGoalClaimed,
      clanGoalReady: clanPoolThisWeek >= clanGoalTarget && !clanGoalClaimed,
      chestReady: List.generate(
        starRoadMilestones.length,
        canClaimChest,
      ).any((v) => v),
      seasonMilestoneReady: List.generate(
        seasonMilestones.length,
        canClaimSeason,
      ).any((v) => v),
      raidActiveToday: isRaidActiveForEpochDay(today),
      raidHasAttemptsLeft:
          raidAttemptsUsed < RaidBossController.maxDailyAttempts,
      unlockedLevel: unlockedLevel.value,
      levelCount: kLevelCount,
    );
  }

  int _questsReadyToClaim() {
    var ready = 0;
    for (var i = 0; i < dailyQuests.length; i++) {
      if (dailyQuestClaimed.contains(i)) continue;
      if (dailyQuestProgress[i] >= dailyQuests[i].target) ready++;
    }
    return ready;
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
    final today = todayEpochDay();
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
    final result = nextLoginStreakWithFreeze(
      previousEpochDay: prevDay,
      todayEpochDay: today,
      previousStreak: prevStreak,
      hasFreezeAvailable: streakFreezeCount.value > 0,
    );
    final newStreak = result.streak;
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
    if (result.usedFreeze) {
      streakFreezeCount.value--;
      StorageService.to.setInt(
        StorageKeys.streakFreezeCount,
        streakFreezeCount.value,
      );
    }
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
    _grantTreasureMap();
    return true;
  }

  void _grantTreasureMap() {
    treasureMapCount.value++;
    StorageService.to.setInt(
      StorageKeys.treasureMapCount,
      treasureMapCount.value,
    );
  }

  /// X22: mốc mili-giây, kẹp không lùi. Cùng cơ chế với [todayEpochDay], chỉ
  /// khác độ phân giải — idle pet (I65) tính theo giờ nên không dùng được đơn
  /// vị ngày. Key riêng ([StorageKeys.maxMsSeen]) vì hai giá trị khác đơn vị.
  ///
  /// Uỷ quyền cho `lib/core/utils/clamped_clock.dart` để hệ nào không cầm được
  /// controller (vd [RaidBossController]) cũng dùng đúng lớp bảo vệ này thay
  /// vì tự viết `DateTime.now()` thô.
  int nowMsClamped() => clamped.nowMsClamped();

  /// Số ngày kể từ epoch (UTC), kẹp không lùi dưới mốc lớn nhất từng thấy —
  /// chống gian lận bằng cách chỉnh lùi đồng hồ máy.
  int todayEpochDay() => clamped.todayEpochDayClamped();

  /// I33: modifier Gauntlet hôm nay — dùng để hiện icon+tên trước khi vào
  /// chơi (xem `home_screen.dart`), không cần bắt đầu ván mới để biết.
  GauntletModifier get todaysGauntletModifier =>
      modifierForDay(todayEpochDay());

  bool get canClaimDaily =>
      todayEpochDay() !=
      StorageService.to.getInt(StorageKeys.lastClaimDay, def: -1);

  /// Nhận thưởng ngày: +1 streak nếu liên tiếp hôm qua, ngược lại reset về 1.
  /// Trả về số xu vừa nhận, hoặc null nếu hôm nay đã nhận rồi.
  int? claimDaily() {
    if (!canClaimDaily) return null;
    final today = todayEpochDay();
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
      todayEpochDay() !=
      StorageService.to.getInt(StorageKeys.lastSpinDay, def: -1);

  /// Ô đã "chốt" cho hôm nay, seed = ngày hiện tại → gọi bao nhiêu lần trong
  /// cùng 1 ngày cũng ra cùng kết quả (UI vòng quay chỉ animate tới ô này,
  /// không tự random riêng). Không đổi state, gọi được trước khi [claimSpin].
  SpinReward get todaySpinReward {
    final rnd = Random(todayEpochDay());
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
    StorageService.to.setInt(StorageKeys.lastSpinDay, todayEpochDay());
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

  /// I86: digest kèm phần thưởng quay lại — vài dòng số liệu cụ thể thay cho
  /// một popup chỉ đưa tiền.
  ///
  /// [daysAway] do [checkComebackBonus] tính sẵn từ [todayEpochDay] (đã kẹp
  /// chống chỉnh đồng hồ), không đọc `DateTime.now()` thô.
  List<DigestLine> comebackDigest(int daysAway) {
    // Mốc rương gần nhất còn CHƯA đạt; 0 nghĩa là đã qua hết mốc.
    final nextChest = starRoadMilestones.firstWhere(
      (m) => totalStars.value < m,
      orElse: () => 0,
    );
    final dayInSeason = todayEpochDay() % seasonLengthDays;
    return buildComebackDigest(
      daysAway: daysAway,
      totalStars: totalStars.value,
      nextChestStars: nextChest,
      weeklyGoalProgress: weeklyGoalProgress.value,
      weeklyGoalTarget: weeklyGoalTarget,
      seasonDaysLeft: seasonLengthDays - dayInSeason,
      unlockedLevel: unlockedLevel.value,
      levelCount: kLevelCount,
    );
  }

  static const int comebackBonusCoins = 300;

  /// I10: gọi 1 lần mỗi khi mở Home. Vắng >=3 ngày kể từ lần mở trước → tặng
  /// coin + 1 bomb + 1 shuffle, trả về số coin đã tặng; null nếu chưa đủ điều
  /// kiện. Luôn cập nhật lastOpenDay = hôm nay (mốc cho lần vắng kế tiếp).
  /// I86: số ngày vắng của lần [checkComebackBonus] gần nhất — UI dùng để
  /// dựng digest. 0 nếu không đủ điều kiện thưởng.
  int lastComebackDaysAway = 0;

  int? checkComebackBonus() {
    final today = todayEpochDay();
    final last = StorageService.to.getInt(StorageKeys.lastOpenDay, def: -1);
    lastComebackDaysAway = last < 0 ? 0 : today - last;
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
      todayEpochDay(),
      currentLevel.colorCount,
    );
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    resetCombo();
    activeGame = null;
    _freeUndoLeft = _initialFreeUndo;
    hintCount.value = _initialHints;
    movesUsed.value = 0;
    _collectInitial = null;
    perfectClearTarget.value = null;
    perfectClearSuccess.value = false;
    usedSecondChance = false;
    boardWasRefilled = false;
    craftRewardType.value = null;
    activeChallenge.value = null;
    challengeWon.value = null;
    activeSeedChallenge.value = null;
    seedChallengeWon.value = null;
  }

  /// Task #5: replay level đã qua ít nhất 1 sao, mục tiêu vượt best score
  /// hiện tại — thành công thưởng thêm [perfectClearBonusCoins], ngoài ra
  /// dùng nguyên luồng campaign (star/highscore vẫn cập nhật bình thường).
  void startPerfectClear(int levelId) {
    final target = StorageService.to.getInt(StorageKeys.highScore(levelId));
    startLevel(levelId);
    perfectClearTarget.value = target;
  }

  /// F8: bắt đầu 1 ván side-mode (Time-attack/Zen/Combo Rush/Frost Rush) —
  /// không đụng currentLevelRx/unlockedLevel của campaign.
  void startSideMode(GameMode sideMode) {
    mode.value = sideMode;
    currentLevelRx.value = switch (sideMode) {
      GameMode.timeAttack => kTimeAttackLevel,
      GameMode.comboRush => kComboRushLevel,
      GameMode.frostRush => kFrostRushLevel,
      _ => kZenLevel,
    };
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    resetCombo();
    activeGame = null;
    _freeUndoLeft = _initialFreeUndo;
    hintCount.value = _initialHints;
    movesUsed.value = 0;
    _collectInitial = null;
  }

  /// F12: bắt đầu ván Endless mới, bàn đầu tiên (index 0, dễ nhất).
  void startEndless() {
    _endlessBoardIndex = 0;
    mode.value = GameMode.endless;
    activeEndlessModifier = modifierForDay(todayEpochDay());
    currentLevelRx.value = endlessLevelForIndex(
      _endlessBoardIndex,
      modifier: activeEndlessModifier,
    );
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    resetCombo();
    activeGame = null;
    _freeUndoLeft = _initialFreeUndo;
    hintCount.value = _initialHints;
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
    _freeUndoLeft = _initialFreeUndo;
    hintCount.value = _initialHints;
    movesUsed.value = 0;
    _collectInitial = null;
  }

  /// F13: bắt đầu ván Daily Challenge — bàn sinh từ seed = ngày hiện tại
  /// (`Random(seed)` có seed, không `Random()` mặc định) nên mọi người chơi
  /// cùng ngày gặp cùng bàn.
  void startDailyChallenge() {
    mode.value = GameMode.dailyChallenge;
    currentLevelRx.value = kDailyChallengeLevel;
    dailyChallengeGrid = generateDailyChallengeGrid(todayEpochDay());
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    resetCombo();
    activeGame = null;
    _freeUndoLeft = _initialFreeUndo;
    hintCount.value = _initialHints;
    movesUsed.value = 0;
    _collectInitial = null;
  }

  /// I33: bắt đầu ván Gauntlet — modifier hôm nay chọn theo epoch-day
  /// ([modifierForDay], không `Random()`), bàn sinh từ cùng seed như Daily
  /// Challenge (tái dùng [generateDailyChallengeGrid]) nhưng colorCount có
  /// thể đổi theo modifier `fourColors`.
  void startGauntlet() {
    mode.value = GameMode.gauntlet;
    final modifier = modifierForDay(todayEpochDay());
    activeGauntletModifier = modifier;
    currentLevelRx.value = gauntletLevelFor(modifier);
    gauntletGrid = generateDailyChallengeGrid(
      todayEpochDay(),
      colorCount: modifier.colorCountOverride ?? dailyChallengeColorCount,
    );
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    resetCombo();
    activeGame = null;
    _freeUndoLeft = _initialFreeUndo;
    hintCount.value = _initialHints;
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
    // X27: lớp phòng thủ thứ hai cho phép chia lấy dư. Nguồn đã được kẹp trong
    // `_load()`, nhưng getter này cũng đọc được `unlockedLevel` do code khác
    // gán, và chia cho 0 ở đây làm crash thẳng màn Home.
    final unlocked = unlockedLevel.value;
    if (unlocked < 1) return 1;
    return currentWeekIndex % unlocked + 1;
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
    _freeUndoLeft = _initialFreeUndo;
    hintCount.value = _initialHints;
    movesUsed.value = 0;
    _collectInitial = null;
  }

  /// I80 Remix Levels: chơi lại 1 level campaign đã có sẵn ([levelId]) với 1
  /// [GauntletModifier] áp lên trên — mirror [startWeeklyFeatured] (chỉ đọc
  /// [kLevels], không đụng star/highScore/unlock campaign của level đó).
  void startRemixLevel(int levelId, GauntletModifier mod) {
    mode.value = GameMode.remixLevel;
    activeRemixModifier = mod;
    currentLevelRx.value = remixLevelFor(kLevels[levelId - 1], mod);
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    resetCombo();
    activeGame = null;
    _freeUndoLeft = _initialFreeUndo;
    hintCount.value = _initialHints;
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
    _freeUndoLeft = _initialFreeUndo;
    hintCount.value = _initialHints;
    movesUsed.value = 0;
    _collectInitial = null;
  }

  /// I59: one random seed produces the source board shared by both players.
  void startPassAndPlayDuel() {
    passAndPlayBaseGrid = generateDailyChallengeGrid(Random().nextInt(1 << 31));
    startPassAndPlayTurn();
  }

  /// Each player receives a fresh deep copy because PopStarGame mutates it.
  void startPassAndPlayTurn() {
    final source = passAndPlayBaseGrid;
    if (source == null) return;
    mode.value = GameMode.passAndPlay;
    passAndPlayGrid = source.map((row) => List<int>.from(row)).toList();
    currentLevelRx.value = PopLevel(
      id: -59,
      rows: source.length,
      cols: source.first.length,
      colorCount: dailyChallengeColorCount,
      targetScore: source.length * source.first.length * 6,
    );
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    resetCombo();
    activeGame = null;
    _freeUndoLeft = _initialFreeUndo;
    hintCount.value = _initialHints;
    movesUsed.value = 0;
    _collectInitial = null;
  }

  /// I60: deterministic board for each of five stages on the current day.
  void startTreasureMapStage(int stage) {
    final modifier = kTreasureMapModifiers[stage - 1];
    activeTreasureMapModifier = modifier;
    mode.value = GameMode.treasureMap;
    final grid = generateDailyChallengeGrid(
      todayEpochDay() + stage,
      colorCount: modifier.colorCountOverride ?? dailyChallengeColorCount,
    );
    puzzleLabGrid = grid;
    currentLevelRx.value = PopLevel(
      id: -60 - stage,
      rows: grid.length,
      cols: grid.first.length,
      colorCount: modifier.colorCountOverride ?? dailyChallengeColorCount,
      targetScore: grid.length * grid.first.length * 5,
    );
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    resetCombo();
    activeGame = null;
    _freeUndoLeft = _initialFreeUndo;
    hintCount.value = _initialHints;
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
    _freeUndoLeft = _initialFreeUndo;
    hintCount.value = _initialHints;
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
      todayEpochDay() !=
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
      todayEpochDay(),
    );
    StorageService.to.setInt(StorageKeys.dailyChallengeScore, score.value);
    starDust.value += starDustPerDailyChallenge;
    StorageService.to.setInt(StorageKeys.starDustCount, starDust.value);
  }

  /// I33: đã ghi điểm Gauntlet hôm nay chưa — mirror
  /// [canRecordDailyChallengeScore] (1 lượt tính điểm/ngày).
  bool get canRecordGauntletScore =>
      todayEpochDay() !=
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
    StorageService.to.setInt(StorageKeys.lastGauntletDay, todayEpochDay());
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
    final next = endlessLevelForIndex(
      _endlessBoardIndex,
      modifier: activeEndlessModifier,
    );
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

  /// I80 Remix Levels: best riêng từng level (không có 1 Rx duy nhất như
  /// các mode khác vì "best" ở đây là 1 giá trị theo mỗi [levelId]) — đọc
  /// trực tiếp từ storage khi cần, cùng cách `highScore`/`star` đọc theo id.
  int remixBestFor(int levelId) =>
      StorageService.to.getInt(StorageKeys.remixBest(levelId));

  void _saveRemixBest() {
    final levelId = currentLevel.id;
    if (score.value > remixBestFor(levelId)) {
      StorageService.to.setInt(StorageKeys.remixBest(levelId), score.value);
    }
  }

  /// I88: đã dùng cơ hội thứ hai trong màn đang chơi chưa (tối đa 1 lần).
  /// Không persist — chỉ có ý nghĩa trong phạm vi 1 ván.
  bool usedSecondChance = false;

  /// I88: bàn đã được bồi thêm ô trong ván này chưa.
  ///
  /// Dùng để loại ván đó khỏi [boardsFullyCleared]: thành tựu "dọn sạch bàn"
  /// phải nói về bàn gốc, không phải bàn đã được mua thêm ô.
  bool boardWasRefilled = false;

  bool get canBuySecondChance => canOfferSecondChance(
    isCampaign: mode.value == GameMode.campaign,
    starsEarned: starsEarned.value,
    score: score.value,
    targetScore: currentLevel.targetScore,
    alreadyUsedThisLevel: usedSecondChance,
    coins: coins.value,
  );

  bool get secondChanceUnaffordable => isSecondChanceUnaffordable(
    isCampaign: mode.value == GameMode.campaign,
    starsEarned: starsEarned.value,
    score: score.value,
    targetScore: currentLevel.targetScore,
    alreadyUsedThisLevel: usedSecondChance,
    coins: coins.value,
  );

  /// Mua 1 cơ hội: trừ xu, bồi bàn, mở lại ván. Giữ nguyên **điểm và combo** —
  /// đây là cứu trợ, không phải chơi lại từ đầu.
  ///
  /// Trả `false` nếu không đủ điều kiện; caller không cần tự kiểm lại.
  bool buySecondChance() {
    if (!canBuySecondChance) return false;
    coins.value -= kSecondChanceCost;
    StorageService.to.setInt(StorageKeys.coins, coins.value);
    usedSecondChance = true;
    boardWasRefilled = true;

    // Mở lại ván: `ended` đã bật khi thua nên phải hạ xuống, nếu không mọi
    // `checkEnd` sau đó đều bị chặn ở dòng `if (ended.value) return;`.
    ended.value = false;
    cleared.value = false;
    activeGame?.refillForSecondChance();
    return true;
  }

  void addScore(int points) => score.value += points;

  /// X17: ảnh chụp các counter ĐỜI tại thời điểm `PopStarGame._saveUndo()` —
  /// không phải state của ván. Thiếu nó thì Undo chỉ hoàn tác bàn/điểm còn
  /// `totalGemsPopped`, weekly goal, clan contribution, daily quest và
  /// `maxComboEver` vẫn giữ giá trị đã cộng, cho phép farm vô hạn bằng vòng
  /// "nổ → undo → nổ lại đúng nhóm đó" (undo đầu mỗi màn còn miễn phí, I5).
  ///
  /// Chụp ở [saveUndoCounters] (gọi từ `_saveUndo`) chứ KHÔNG ở [registerPop]:
  /// booster bomb/rainbow/swap/shuffle cũng tạo điểm undo nhưng không gọi
  /// [registerPop], nên nếu chụp trong [registerPop] thì undo sau một cú bomb
  /// sẽ khôi phục nhầm counter về mốc của lần pop trước đó.
  ({
    int gems,
    int weekly,
    int clanWeek,
    int clanTotal,
    List<int> quests,
    int maxCombo,
  })?
  _undoCounters;

  void saveUndoCounters() {
    _undoCounters = (
      gems: totalGemsPopped.value,
      weekly: weeklyGoalProgress.value,
      clanWeek: clanContribWeek.value,
      clanTotal: clanContribTotal.value,
      quests: List<int>.from(dailyQuestProgress),
      maxCombo: maxComboEver.value,
    );
  }

  /// Khôi phục counter đời về mốc [saveUndoCounters] gần nhất và ghi lại đĩa.
  ///
  /// Achievement/sticker đã mở khoá trong nước đi bị hoàn tác **không** bị thu
  /// hồi (xu đã trao rồi) — nhưng cũng không mở khoá lại lần nữa khi nổ lại,
  /// vì [newlyUnlockedAchievementIds] lọc theo [unlockedAchievementIds] đã
  /// persist. Nghĩa là không có đường cộng xu lặp.
  void restoreUndoCounters() {
    final snapshot = _undoCounters;
    if (snapshot == null) return;
    _undoCounters = null;
    totalGemsPopped.value = snapshot.gems;
    weeklyGoalProgress.value = snapshot.weekly;
    clanContribWeek.value = snapshot.clanWeek;
    clanContribTotal.value = snapshot.clanTotal;
    dailyQuestProgress.assignAll(snapshot.quests);
    maxComboEver.value = snapshot.maxCombo;
    StorageService.to.setInt(
      StorageKeys.totalGemsPopped,
      totalGemsPopped.value,
    );
    StorageService.to.setInt(
      StorageKeys.weeklyGoalProgress,
      weeklyGoalProgress.value,
    );
    StorageService.to.setInt(
      StorageKeys.clanContribWeek,
      clanContribWeek.value,
    );
    StorageService.to.setInt(
      StorageKeys.clanContribTotal,
      clanContribTotal.value,
    );
    StorageService.to.setInt(StorageKeys.maxComboEver, maxComboEver.value);
    _persistDailyQuests();
  }

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
    // X24: ghi đệm — xem [StorageService.flush] cho danh sách mốc flush.
    StorageService.to.setIntBuffered(
      StorageKeys.totalGemsPopped,
      totalGemsPopped.value,
    );
    addWeeklyGoalProgress(
      groupSize,
    ); // I50: mọi mode, không phân biệt campaign.
    addClanContribution(groupSize); // I66: mọi mode, cùng hook với I50.
    _addDailyQuestProgress(QuestKind.popGems, groupSize);
    if (comboCount.value > maxComboEver.value) {
      maxComboEver.value = comboCount.value;
      StorageService.to.setIntBuffered(
        StorageKeys.maxComboEver,
        maxComboEver.value,
      );
    }
    _checkAchievements();
    return gained;
  }

  void resetCombo() {
    comboCount.value = 0;
    comboMultiplier.value = 1.0;
    AudioManager.maybe?.applyComboLayer(0); // I12
  }

  /// X24: mốc flush chính. Kết thúc màn là lúc an toàn nhất để đẩy counter
  /// đang đệm xuống đĩa — bọc ngoài thay vì rải `flush()` trước từng `return`
  /// của [_checkEnd] (hàm đó có 3 đường thoát, rất dễ thêm đường thứ 4 mà
  /// quên).
  void checkEnd(bool boardCleared) {
    _checkEnd(boardCleared);
    StorageService.to.flush();
  }

  void _checkEnd(bool boardCleared) {
    if (ended.value) return;
    cleared.value = boardCleared;
    // I88: bàn đã được bồi thêm ô thì không tính là "dọn sạch bàn" — thành
    // tựu đó phải nói về bàn gốc, không phải bàn mua thêm.
    if (boardCleared && !boardWasRefilled) {
      // I22 Achievements: counter tích lũy đời, áp dụng mọi mode.
      boardsFullyCleared.value++;
      StorageService.to.setInt(
        StorageKeys.boardsFullyCleared,
        boardsFullyCleared.value,
      );
      _checkAchievements();
    }
    if (mode.value == GameMode.puzzleLab ||
        mode.value == GameMode.passAndPlay) {
      if (boardCleared) _addDailyQuestProgress(QuestKind.winAnyMode, 1);
      if (activeSeedChallenge.value case final challenge?) {
        seedChallengeWon.value = score.value > challenge.score;
      }
      ended.value = true;
      return; // không thưởng coin/sao/unlock/best-score
    }
    if (mode.value != GameMode.campaign) {
      if (boardCleared) _addDailyQuestProgress(QuestKind.winAnyMode, 1);
      if (mode.value == GameMode.timeAttack) _saveTimeAttackBest();
      if (mode.value == GameMode.comboRush) _saveComboRushBest();
      if (mode.value == GameMode.frostRush) _saveFrostRushBest();
      if (mode.value == GameMode.endless) _saveEndlessBest();
      if (mode.value == GameMode.mirrorMode) _saveMirrorModeBest();
      if (mode.value == GameMode.dailyChallenge) _saveDailyChallengeScore();
      if (mode.value == GameMode.gauntlet) _saveGauntletScore();
      if (mode.value == GameMode.weeklyFeatured) _saveFeaturedLevelScore();
      if (mode.value == GameMode.remixLevel) _saveRemixBest();
      ended.value = true;
      return;
    }
    starsEarned.value = _computeStars();
    if (starsEarned.value > 0) {
      _addDailyQuestProgress(QuestKind.winAnyMode, 1);
    }
    if (starsEarned.value == 3) {
      _addDailyQuestProgress(QuestKind.threeStarLevel, 1);
    }
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
      if (starsEarned.value == 3) {
        starDust.value += starDustPerThreeStarWin;
        StorageService.to.setInt(StorageKeys.starDustCount, starDust.value);
      }
      _maybeRequestReview();
      _checkSeasonRollover();
      _addSeasonPoints(starsEarned.value * 10);
      // I27 Prestige: thắng đúng level cuối (kLevelCount) ≥1 sao → đủ điều
      // kiện Prestige. Không dùng unlockedLevel (đã bị _unlockNext chặn ở
      // kLevelCount) — phải bắt đúng lúc thắng level cuối.
      if (currentLevel.id == kLevelCount && !allLevelsCompletedOnce.value) {
        allLevelsCompletedOnce.value = true;
        StorageService.to.setBool(StorageKeys.allLevelsCompleted, true);
        StorageService.to.setInt(
          StorageKeys.allLevelsCompletedAtCount,
          kLevelCount,
        );
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

  void _saveComboRushBest() {
    if (score.value > comboRushBest.value) {
      comboRushBest.value = score.value;
      StorageService.to.setInt(StorageKeys.comboRushBest, score.value);
    }
  }

  void _saveFrostRushBest() {
    if (score.value > frostRushBest.value) {
      frostRushBest.value = score.value;
      StorageService.to.setInt(StorageKeys.frostRushBest, score.value);
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
    // I82: cộng dồn với perk trên, không thay thế.
    if (hasPetPassive(PetPassive.coinBonus)) reward = (reward * 1.05).round();
    coins.value += reward;
    StorageService.to.setInt(StorageKeys.coins, coins.value);
  }

  static const bombPrice = 60;
  static const shufflePrice = 40;
  static const undoPrice = 30;
  static const rainbowPrice = 80;
  static const swapPrice = 50;
  static const freezePrice = 70;
  static const streakFreezePrice = 100;

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
  bool buyStreakFreeze() =>
      _buy(streakFreezePrice, streakFreezeCount, StorageKeys.streakFreezeCount);

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
    // I33/I69: modifier "no_undo" khoá hẳn undo cho ván chơi.
    if (activeGameplayModifier?.disableUndo == true) {
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

  /// X19: các key **cố ý giữ lại** khi Reset Progress. Mọi key khác bị xoá.
  ///
  /// Đảo chiều so với bản cũ (liệt kê tay ~55 key cần xoá): danh sách tay đó
  /// đã trôi lại phía sau qua 5 round — Round 4-8 thêm ~20 hệ meta mà quên bổ
  /// sung, để lại pet/Star Dust/Star Seed/streak-freeze/remix-best nguyên vẹn
  /// sau khi người chơi bấm "xoá sạch", và pet cũ vẫn tiếp tục sinh coin idle.
  /// Với whitelist, hệ mới **tự động** được xoá đúng; chỉ khi cố ý muốn giữ
  /// mới phải đụng danh sách này.
  ///
  /// Phân loại (chốt với PO 2026-08-11):
  /// - **Cài đặt** (ngôn ngữ, âm thanh, haptics, theme, trợ năng, nhắc nhở):
  ///   không phải tiến độ, người chơi đã tự chỉnh — giữ.
  /// - **Trạng thái UX đã-xem-rồi** (`hasSeen*`, review prompt): reset xong bị
  ///   bắt xem lại tutorial hoặc bị hỏi đánh giá lần 2 đều khó chịu — giữ.
  /// - **Tên người chơi**: nội dung người dùng nhập, không phải tiến độ — giữ
  ///   (đã có tiền lệ ghi ở [playerName]).
  /// - Mọi thứ khác — kể cả `savedPuzzles`, `bossRushBestStreak`, `raidBoss*`
  ///   — là tiến độ/record kiếm được bằng chơi → **xoá**.
  ///
  /// Thêm key mới vào đây CHỈ khi nó thật sự không phải tiến độ.
  static const Set<String> keepOnReset = {
    // Cài đặt
    StorageKeys.localeCode,
    StorageKeys.audioMuted,
    StorageKeys.bgmVolume,
    StorageKeys.sfxVolume,
    StorageKeys.hapticsEnabled,
    StorageKeys.hapticSoftMode,
    StorageKeys.themeDark,
    StorageKeys.remindersEnabled,
    StorageKeys.recordReplay,
    // Trợ năng
    StorageKeys.colorblindMode,
    StorageKeys.reduceMotion,
    StorageKeys.largerTapTargets,
    // Trạng thái UX đã-xem-rồi
    StorageKeys.hasSeenFtue,
    StorageKeys.hasSeenShopTutorial,
    StorageKeys.hasSeenBoosterTutorial,
    StorageKeys.hasSeenDailyChallengeTutorial,
    StorageKeys.hasShownReviewPrompt,
    // Nội dung người dùng nhập
    StorageKeys.playerName,
  };

  Future<void> resetProgress() async {
    final store = StorageService.to;
    // Quét key thật đang tồn tại thay vì liệt kê tay — phủ luôn key động
    // (`highScore(id)`, `star(id)`, `remixBest(id)`) mà không cần vòng lặp
    // riêng theo `kLevelCount`.
    for (final key in store.allKeys().toList()) {
      if (keepOnReset.contains(key)) continue;
      await store.remove(key);
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
    clanContribWeek.value = 0;
    clanContribTotal.value = 0;
    dailyQuestProgress.assignAll(const [0, 0, 0]);
    dailyQuestClaimed.clear();
    dailyQuests.clear();
    _dailyQuestDay = -1;
    _load();
    _checkLoginStreak();
    checkDailyQuestRollover();
  }
}

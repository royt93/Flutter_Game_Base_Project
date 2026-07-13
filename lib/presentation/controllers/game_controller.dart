import 'dart:async';
import 'dart:math';

import 'package:get/get.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../core/storage_service.dart';
import '../../core/utils/comeback_bonus.dart';
import '../../core/utils/weekend_event.dart';
import '../../data/levels.dart';
import '../../data/perks.dart';
import '../../game/pop_star_game.dart';
import '../../logic/daily_challenge.dart';
import '../../logic/gift_tile.dart';

/// F8: campaign (200 màn có target/sao/mở khoá) vs side-mode biệt lập
/// (không đụng unlockedLevel/coin-campaign/star). F12: endless thêm vào nhóm
/// side-mode, không target/thắng-thua, chỉ ghi high-score riêng.
enum GameMode { campaign, timeAttack, zen, endless, dailyChallenge }

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

  /// Combo: nổ liên tiếp trong cửa sổ thời gian → hệ số điểm tăng dần.
  final comboCount = 0.obs;
  final comboMultiplier = 1.0.obs;
  static const double comboWindow = 3.0; // giây giữa 2 lần nổ để giữ combo
  static const double comboMax = 5.0;

  /// Tăng mỗi lần nổ nhóm lớn/combo cao → UI hiện flash trắng ngắn (G2).
  final flashTick = 0.obs;
  void triggerFlash() => flashTick.value++;

  /// Set bởi [PopStarGame.onLoad] khi bàn được dựng — dùng để booster gọi
  /// thẳng vào game (bomb/shuffle/undo đều thao tác trực tiếp trên grid).
  PopStarGame? activeGame;

  /// F13: bàn Daily Challenge hôm nay, sinh 1 lần trong [startDailyChallenge]
  /// — [PopStarGame] dùng làm bàn cố định thay vì random.
  List<List<int>>? dailyChallengeGrid;

  PopLevel get currentLevel => currentLevelRx.value!;

  /// Màn cao nhất đã mở khoá. Observable để LevelSelect refresh ngay khi thắng
  /// (getter đọc-thẳng-storage cũ không reactive → grid không cập nhật lúc quay
  /// lại màn chọn level).
  final unlockedLevel = 1.obs;

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

  /// I8: cuối tuần nhân đôi mọi coin thưởng (thắng level, chest, daily, spin).
  int get weekendCoinMultiplier => isWeekendEvent(DateTime.now()) ? 2 : 1;

  /// F7 Star road: tổng sao tốt nhất mọi màn + mốc rương xu.
  static const List<int> starRoadMilestones = [5, 15, 30, 50];
  static const List<int> starRoadRewards = [50, 100, 200, 400];
  final totalStars = 0.obs;
  final claimedChestMask = 0.obs;

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

  @override
  void onInit() {
    super.onInit();
    _load();
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
    claimedChestMask.value = StorageService.to.getInt(
      StorageKeys.claimedChests,
    );
    dailyStreak.value = StorageService.to.getInt(StorageKeys.dailyStreak);
    timeAttackBest.value = StorageService.to.getInt(StorageKeys.timeAttackBest);
    endlessBest.value = StorageService.to.getInt(StorageKeys.endlessBest);
    seasonPoints.value = StorageService.to.getInt(StorageKeys.seasonPoints);
    claimedSeasonMask.value = StorageService.to.getInt(
      StorageKeys.claimedSeasonMask,
    );
    activePerkIds.value =
        (StorageService.to.getString(StorageKeys.activePerks) ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList();
    _recomputeTotalStars();
    _checkSeasonRollover();
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
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    resetCombo();
    activeGame = null;
    _freeUndoLeft = hasPerk('extra_undo') ? 2 : 1;
    movesUsed.value = 0;
    _collectInitial = null;
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
    movesUsed.value = 0;
    _collectInitial = null;
  }

  /// F13: đã ghi điểm Daily Challenge hôm nay chưa — chơi lại trong ngày
  /// không đè điểm cũ (giống `canClaimDaily`).
  bool get canRecordDailyChallengeScore =>
      _todayEpochDay() !=
      StorageService.to.getInt(StorageKeys.lastDailyChallengeDay, def: -1);

  /// F13: điểm Daily Challenge đã ghi nhận lần gần nhất (mọi ngày, không chỉ
  /// hôm nay) — dùng hiển thị kết quả.
  int get dailyChallengeScoreToday =>
      StorageService.to.getInt(StorageKeys.dailyChallengeScore);

  void _saveDailyChallengeScore() {
    if (!canRecordDailyChallengeScore) return;
    StorageService.to.setInt(
      StorageKeys.lastDailyChallengeDay,
      _todayEpochDay(),
    );
    StorageService.to.setInt(StorageKeys.dailyChallengeScore, score.value);
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

  void addScore(int points) => score.value += points;

  /// Ghi nhận 1 lần nổ nhóm: tăng combo, cộng điểm đã nhân hệ số.
  /// Trả về điểm thực cộng (để UI hiện popup).
  int registerPop(int baseScore) {
    movesUsed.value++;
    comboCount.value++;
    comboMultiplier.value = (1 + (comboCount.value - 1) * 0.5).clamp(
      1.0,
      comboMax,
    );
    final gained = (baseScore * comboMultiplier.value).round();
    score.value += gained;
    return gained;
  }

  void resetCombo() {
    comboCount.value = 0;
    comboMultiplier.value = 1.0;
  }

  void checkEnd(bool boardCleared) {
    if (ended.value) return;
    cleared.value = boardCleared;
    if (mode.value != GameMode.campaign) {
      if (mode.value == GameMode.timeAttack) _saveTimeAttackBest();
      if (mode.value == GameMode.endless) _saveEndlessBest();
      if (mode.value == GameMode.dailyChallenge) _saveDailyChallengeScore();
      ended.value = true;
      return;
    }
    starsEarned.value = _computeStars();
    ended.value = true;
    if (starsEarned.value > 0) {
      _unlockNext();
      _saveBestScore();
      _grantCoins();
      _maybeRequestReview();
      _checkSeasonRollover();
      _addSeasonPoints(starsEarned.value * 10);
    }
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
    final target = currentLevel.targetScore;
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

  void useBomb(int row, int col) {
    if (bombCount.value <= 0 || activeGame == null) return;
    activeGame!.triggerBomb(row, col);
    bombCount.value--;
    StorageService.to.setInt(StorageKeys.bombCount, bombCount.value);
  }

  void useShuffle() {
    if (shuffleCount.value <= 0 || activeGame == null) return;
    activeGame!.shuffleBoard();
    shuffleCount.value--;
    StorageService.to.setInt(StorageKeys.shuffleCount, shuffleCount.value);
  }

  void useUndo() {
    if (activeGame == null) return;
    // I5: lần undo đầu tiên mỗi màn miễn phí (F14: +1 nữa nếu có perk
    // extra_undo), không đụng undoCount.
    if (_freeUndoLeft > 0) {
      if (!activeGame!.undo()) return;
      _freeUndoLeft--;
      return;
    }
    if (undoCount.value <= 0) return;
    if (!activeGame!.undo()) return;
    undoCount.value--;
    StorageService.to.setInt(StorageKeys.undoCount, undoCount.value);
  }

  void useRainbow(int row, int col) {
    if (rainbowCount.value <= 0 || activeGame == null) return;
    activeGame!.triggerRainbow(row, col);
    rainbowCount.value--;
    StorageService.to.setInt(StorageKeys.rainbowCount, rainbowCount.value);
  }

  /// F10: đổi màu 2 ô bất kỳ (không cần liền kề), không tự nổ.
  void useSwap(int row1, int col1, int row2, int col2) {
    if (swapCount.value <= 0 || activeGame == null) return;
    activeGame!.triggerSwap(row1, col1, row2, col2);
    swapCount.value--;
    StorageService.to.setInt(StorageKeys.swapCount, swapCount.value);
  }

  /// F10: dùng ngay — N lượt tiếp theo obstacle không giảm bền dù nổ cạnh.
  static const int freezeTurns = 5;
  void useFreeze() {
    if (freezeCount.value <= 0 || activeGame == null) return;
    activeGame!.freezeTurnsLeft = freezeTurns;
    freezeCount.value--;
    StorageService.to.setInt(StorageKeys.freezeCount, freezeCount.value);
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
    await store.remove(StorageKeys.lastDailyChallengeDay);
    await store.remove(StorageKeys.dailyChallengeScore);
    await store.remove(StorageKeys.lastSpinDay);
    await store.remove(StorageKeys.lastOpenDay);
    await store.remove(StorageKeys.seasonPoints);
    await store.remove(StorageKeys.claimedSeasonMask);
    await store.remove(StorageKeys.lastSeasonIndex);
    await store.remove(StorageKeys.activePerks);
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
    _load();
  }
}

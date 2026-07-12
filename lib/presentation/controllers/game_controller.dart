import 'package:get/get.dart';

import '../../core/storage_service.dart';
import '../../data/levels.dart';
import '../../game/pop_star_game.dart';

/// F8: campaign (200 màn có target/sao/mở khoá) vs 2 side-mode biệt lập
/// (không đụng unlockedLevel/coin-campaign/star).
enum GameMode { campaign, timeAttack, zen }

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

  /// F6b: đọc lại [grid] sau mỗi lần bàn ổn định để cập nhật tiến độ mục
  /// tiêu — gọi từ `PopStarGame._checkEnd` (cùng nhịp với check thắng/kẹt).
  void updateObjectiveProgress(List<List<int?>> grid) {
    final objective = currentLevel.objective;
    objectiveRemaining.value = switch (objective.type) {
      ObjectiveType.score => 0,
      ObjectiveType.clearColor =>
        grid.expand((row) => row).where((v) => v == objective.color).length,
      ObjectiveType.clearObstacle =>
        grid.expand((row) => row).where((v) => v != null && v < 0).length,
    };
  }

  /// F6b: màn có mục tiêu ngoài điểm và đã dọn xong — thắng ngay dù bàn chưa
  /// hết/kẹt (điểm vẫn tính sao như thường qua [_computeStars]).
  bool get objectiveMet =>
      currentLevel.objective.type != ObjectiveType.score &&
      objectiveRemaining.value == 0;

  final bombCount = 0.obs;
  final shuffleCount = 0.obs;
  final undoCount = 0.obs;
  final rainbowCount = 0.obs;

  /// I5: undo đầu tiên mỗi màn miễn phí, không trừ `undoCount`.
  bool _freeUndoUsedThisLevel = false;

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

  /// F7 Star road: tổng sao tốt nhất mọi màn + mốc rương xu.
  static const List<int> starRoadMilestones = [5, 15, 30, 50];
  static const List<int> starRoadRewards = [50, 100, 200, 400];
  final totalStars = 0.obs;
  final claimedChestMask = 0.obs;

  /// F2 Daily reward: chuỗi ngày liên tiếp mở app + nhận thưởng (D1..D7 lặp).
  static const List<int> dailyRewards = [50, 80, 120, 160, 200, 260, 400];
  final dailyStreak = 0.obs;

  /// F8 Time-attack: điểm cao nhất từng đạt (biệt lập, không phải highScore
  /// campaign theo id).
  final timeAttackBest = 0.obs;

  /// I18: vẽ thêm symbol theo màu lên mỗi gem — hỗ trợ người mù màu.
  final colorblindMode = false.obs;

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
    unlockedLevel.value = StorageService.to.getInt(
      StorageKeys.unlockedLevel,
      def: 1,
    );
    claimedChestMask.value = StorageService.to.getInt(
      StorageKeys.claimedChests,
    );
    dailyStreak.value = StorageService.to.getInt(StorageKeys.dailyStreak);
    timeAttackBest.value = StorageService.to.getInt(StorageKeys.timeAttackBest);
    _recomputeTotalStars();
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
    coins.value += starRoadRewards[index];
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
    final reward = dailyRewards[(dailyStreak.value - 1) % dailyRewards.length];
    coins.value += reward;
    StorageService.to.setInt(StorageKeys.coins, coins.value);
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
    _freeUndoUsedThisLevel = false;
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
    _freeUndoUsedThisLevel = false;
  }

  void addScore(int points) => score.value += points;

  /// Ghi nhận 1 lần nổ nhóm: tăng combo, cộng điểm đã nhân hệ số.
  /// Trả về điểm thực cộng (để UI hiện popup).
  int registerPop(int baseScore) {
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
      ended.value = true;
      return;
    }
    starsEarned.value = _computeStars();
    ended.value = true;
    if (starsEarned.value > 0) {
      _unlockNext();
      _saveBestScore();
      _grantCoins();
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
    if (score.value < target) return 0;
    if (score.value < target * 1.3) return 1;
    if (score.value < target * 1.7) return 2;
    return 3;
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
    final reward = starsEarned.value * 20;
    coins.value += reward;
    StorageService.to.setInt(StorageKeys.coins, coins.value);
  }

  static const bombPrice = 60;
  static const shufflePrice = 40;
  static const undoPrice = 30;
  static const rainbowPrice = 80;

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
    // I5: lần undo đầu tiên mỗi màn miễn phí, không đụng undoCount.
    if (!_freeUndoUsedThisLevel) {
      if (!activeGame!.undo()) return;
      _freeUndoUsedThisLevel = true;
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

  Future<void> resetProgress() async {
    final store = StorageService.to;
    await store.remove(StorageKeys.unlockedLevel);
    await store.remove(StorageKeys.coins);
    await store.remove(StorageKeys.bombCount);
    await store.remove(StorageKeys.shuffleCount);
    await store.remove(StorageKeys.undoCount);
    await store.remove(StorageKeys.rainbowCount);
    await store.remove(StorageKeys.claimedChests);
    await store.remove(StorageKeys.lastClaimDay);
    await store.remove(StorageKeys.dailyStreak);
    await store.remove(StorageKeys.maxEpochDaySeen);
    await store.remove(StorageKeys.timeAttackBest);
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

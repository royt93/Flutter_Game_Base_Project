import 'package:get/get.dart';

import '../../core/storage_service.dart';
import '../../data/levels.dart';
import '../../game/pop_star_game.dart';

/// Điều khiển 1 ván Pop Star Blast: level đang chơi, điểm, sao, xu, booster.
/// Không còn side-mode / lives / ghost replay — chỉ 1 mode campaign duy nhất.
class GameController extends GetxController {
  final coins = 0.obs;
  final score = 0.obs;
  final Rx<PopLevel?> currentLevelRx = Rx<PopLevel?>(null);
  final starsEarned = 0.obs;
  final ended = false.obs;
  final cleared = false.obs;

  final bombCount = 0.obs;
  final shuffleCount = 0.obs;
  final undoCount = 0.obs;

  /// Combo: nổ liên tiếp trong cửa sổ thời gian → hệ số điểm tăng dần.
  final comboCount = 0.obs;
  final comboMultiplier = 1.0.obs;
  static const double comboWindow = 3.0; // giây giữa 2 lần nổ để giữ combo
  static const double comboMax = 5.0;

  /// Set bởi [PopStarGame.onLoad] khi bàn được dựng — dùng để booster gọi
  /// thẳng vào game (bomb/shuffle/undo đều thao tác trực tiếp trên grid).
  PopStarGame? activeGame;

  PopLevel get currentLevel => currentLevelRx.value!;

  /// Màn cao nhất đã mở khoá. Observable để LevelSelect refresh ngay khi thắng
  /// (getter đọc-thẳng-storage cũ không reactive → grid không cập nhật lúc quay
  /// lại màn chọn level).
  final unlockedLevel = 1.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    coins.value = StorageService.to.getInt(StorageKeys.coins);
    bombCount.value = StorageService.to.getInt(StorageKeys.bombCount, def: 3);
    shuffleCount.value = StorageService.to.getInt(
      StorageKeys.shuffleCount,
      def: 1,
    );
    undoCount.value = StorageService.to.getInt(StorageKeys.undoCount, def: 1);
    unlockedLevel.value = StorageService.to.getInt(
      StorageKeys.unlockedLevel,
      def: 1,
    );
  }

  void startLevel(int levelId) {
    currentLevelRx.value = kLevels[levelId - 1];
    score.value = 0;
    starsEarned.value = 0;
    ended.value = false;
    cleared.value = false;
    resetCombo();
    activeGame = null;
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
    starsEarned.value = _computeStars();
    ended.value = true;
    if (starsEarned.value > 0) {
      _unlockNext();
      _saveBestScore();
      _grantCoins();
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
    if (undoCount.value <= 0 || activeGame == null) return;
    if (!activeGame!.undo()) return;
    undoCount.value--;
    StorageService.to.setInt(StorageKeys.undoCount, undoCount.value);
  }

  Future<void> resetProgress() async {
    final store = StorageService.to;
    await store.remove(StorageKeys.unlockedLevel);
    await store.remove(StorageKeys.coins);
    await store.remove(StorageKeys.bombCount);
    await store.remove(StorageKeys.shuffleCount);
    await store.remove(StorageKeys.undoCount);
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

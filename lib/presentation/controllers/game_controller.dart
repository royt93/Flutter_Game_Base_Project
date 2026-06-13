import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/levels.dart';
import '../../logic/gem_data.dart';

/// Quản lý state ván chơi + tiến trình (GetX).
class GameController extends GetxController {
  final RxInt score = 0.obs;
  final RxInt movesLeft = 0.obs;
  final RxInt targetScore = 0.obs;
  final RxInt comboCount = 0.obs;
  final RxInt currentLevel = 1.obs;

  // --- Mục tiêu màn chơi ---
  final RxInt collected = 0.obs;
  final RxInt jellyCleared = 0.obs;
  final RxInt jellyTotal = 0.obs;

  /// Level cao nhất đã mở khóa.
  final RxInt unlockedLevel = 1.obs;

  /// High score & số sao (0-3) theo từng level.
  final RxMap<int, int> highScores = <int, int>{}.obs;
  final RxMap<int, int> stars = <int, int>{}.obs;

  // --- Kinh tế & booster ---
  final RxInt coins = 0.obs;
  final RxInt boosterHammer = 0.obs;
  final RxInt boosterMoves = 0.obs; // +5 lượt

  /// Số sao đạt được ở ván vừa kết thúc (cho dialog celebration).
  int lastStars = 0;
  int lastCoinReward = 0;

  bool _resolved = false;
  late SharedPreferences _prefs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    unlockedLevel.value = _prefs.getInt('unlockedLevel') ?? 1;
    coins.value = _prefs.getInt('coins') ?? 50; // tặng 50 xu khởi đầu
    boosterHammer.value = _prefs.getInt('b_hammer') ?? 2;
    boosterMoves.value = _prefs.getInt('b_moves') ?? 2;
    for (final lv in kLevels) {
      final hs = _prefs.getInt('hs_${lv.index}');
      if (hs != null) highScores[lv.index] = hs;
      final st = _prefs.getInt('star_${lv.index}');
      if (st != null) stars[lv.index] = st;
    }
  }

  LevelConfig get level => kLevels[currentLevel.value - 1];

  void startLevel(int index) {
    currentLevel.value = index;
    final cfg = kLevels[index - 1];
    score.value = 0;
    comboCount.value = 0;
    movesLeft.value = cfg.moves;
    targetScore.value = cfg.targetScore;
    collected.value = 0;
    jellyCleared.value = 0;
    jellyTotal.value = 0;
    _resolved = false;
  }

  void addScore(int gemsCleared, int combo) {
    comboCount.value = combo;
    final multiplier = 1 + (combo - 1) * 0.5;
    score.value += (gemsCleared * 10 * multiplier).round();
  }

  void registerClear(GemColor color, bool wasJelly) {
    if (level.objective == ObjectiveType.collect &&
        color == level.collectColor) {
      collected.value++;
    }
    if (wasJelly) jellyCleared.value++;
  }

  void useMove() {
    if (movesLeft.value > 0) movesLeft.value--;
  }

  bool get hasWon {
    switch (level.objective) {
      case ObjectiveType.score:
        return score.value >= targetScore.value;
      case ObjectiveType.collect:
        return collected.value >= level.collectTarget;
      case ObjectiveType.clearJelly:
        return jellyTotal.value > 0 && jellyCleared.value >= jellyTotal.value;
    }
  }

  bool get isOutOfMoves => movesLeft.value <= 0;

  double get objectiveProgress {
    switch (level.objective) {
      case ObjectiveType.score:
        return targetScore.value == 0
            ? 0
            : (score.value / targetScore.value).clamp(0.0, 1.0);
      case ObjectiveType.collect:
        return level.collectTarget == 0
            ? 0
            : (collected.value / level.collectTarget).clamp(0.0, 1.0);
      case ObjectiveType.clearJelly:
        return jellyTotal.value == 0
            ? 0
            : (jellyCleared.value / jellyTotal.value).clamp(0.0, 1.0);
    }
  }

  /// Tính số sao (1-3) khi thắng dựa trên hiệu suất.
  int computeStars() {
    if (level.objective == ObjectiveType.score) {
      final r = targetScore.value == 0 ? 1.0 : score.value / targetScore.value;
      if (r >= 1.8) return 3;
      if (r >= 1.35) return 2;
      return 1;
    }
    // collect/jelly: còn càng nhiều lượt càng nhiều sao
    final cfg = level;
    final r = cfg.moves == 0 ? 0.0 : movesLeft.value / cfg.moves;
    if (r >= 0.45) return 3;
    if (r >= 0.2) return 2;
    return 1;
  }

  String? checkEnd() {
    if (_resolved) return null;
    if (hasWon) {
      _resolved = true;
      lastStars = computeStars();
      lastCoinReward = 10 + lastStars * 10; // 20/30/40 xu
      _saveProgress(win: true);
      return 'win';
    }
    if (isOutOfMoves) {
      _resolved = true;
      lastStars = 0;
      lastCoinReward = 0;
      _saveProgress(win: false);
      return 'lose';
    }
    return null;
  }

  // --- Booster ---
  bool useHammer() {
    if (boosterHammer.value <= 0) return false;
    boosterHammer.value--;
    _prefs.setInt('b_hammer', boosterHammer.value);
    return true;
  }

  /// +5 lượt. Trả về true nếu còn booster.
  bool useMovesBooster() {
    if (boosterMoves.value <= 0) return false;
    boosterMoves.value--;
    _prefs.setInt('b_moves', boosterMoves.value);
    movesLeft.value += 5;
    return true;
  }

  /// Mua booster bằng xu. Trả về true nếu đủ xu.
  bool buyHammer({int price = 30}) => _buy('b_hammer', boosterHammer, price);
  bool buyMoves({int price = 25}) => _buy('b_moves', boosterMoves, price);

  bool _buy(String key, RxInt count, int price) {
    if (coins.value < price) return false;
    coins.value -= price;
    count.value++;
    _prefs.setInt('coins', coins.value);
    _prefs.setInt(key, count.value);
    return true;
  }

  Future<void> resetProgress() async {
    unlockedLevel.value = 1;
    highScores.clear();
    stars.clear();
    await _prefs.setInt('unlockedLevel', 1);
    for (final lv in kLevels) {
      await _prefs.remove('hs_${lv.index}');
      await _prefs.remove('star_${lv.index}');
    }
  }

  Future<void> _saveProgress({required bool win}) async {
    final lv = currentLevel.value;
    final prev = highScores[lv] ?? 0;
    if (score.value > prev) {
      highScores[lv] = score.value;
      await _prefs.setInt('hs_$lv', score.value);
    }
    if (win) {
      // sao tốt nhất
      final prevStar = stars[lv] ?? 0;
      if (lastStars > prevStar) {
        stars[lv] = lastStars;
        await _prefs.setInt('star_$lv', lastStars);
      }
      // thưởng xu
      coins.value += lastCoinReward;
      await _prefs.setInt('coins', coins.value);
      if (lv >= unlockedLevel.value && lv < kLevels.length) {
        unlockedLevel.value = lv + 1;
        await _prefs.setInt('unlockedLevel', unlockedLevel.value);
      }
    }
  }
}

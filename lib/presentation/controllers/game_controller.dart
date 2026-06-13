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
  final RxInt collected = 0.obs; // số gem màu mục tiêu đã thu (collect)
  final RxInt jellyCleared = 0.obs; // số jelly đã phá (clearJelly)
  final RxInt jellyTotal = 0.obs; // tổng jelly (game set khi onLoad)

  /// Level cao nhất đã mở khóa (lưu local).
  final RxInt unlockedLevel = 1.obs;

  /// High score theo từng level.
  final RxMap<int, int> highScores = <int, int>{}.obs;

  bool _resolved = false; // tránh hiện dialog 2 lần / ván

  late SharedPreferences _prefs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    unlockedLevel.value = _prefs.getInt('unlockedLevel') ?? 1;
    for (final lv in kLevels) {
      final hs = _prefs.getInt('hs_${lv.index}');
      if (hs != null) highScores[lv.index] = hs;
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
    // điểm = số gem * 10 * hệ số combo
    final multiplier = 1 + (combo - 1) * 0.5;
    score.value += (gemsCleared * 10 * multiplier).round();
  }

  /// Game gọi mỗi khi 1 gem bị xoá → cập nhật tiến độ mục tiêu.
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

  /// Tiến độ mục tiêu 0..1 (cho thanh tiến độ HUD).
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

  /// Gọi sau khi board ổn định (không còn cascade). Trả về:
  /// 'win', 'lose' hoặc null (chơi tiếp).
  String? checkEnd() {
    if (_resolved) return null;
    if (hasWon) {
      _resolved = true;
      _saveProgress(win: true);
      return 'win';
    }
    if (isOutOfMoves) {
      _resolved = true;
      _saveProgress(win: false);
      return 'lose';
    }
    return null;
  }

  /// Xoá toàn bộ tiến độ (về level 1, xoá high score).
  Future<void> resetProgress() async {
    unlockedLevel.value = 1;
    highScores.clear();
    await _prefs.setInt('unlockedLevel', 1);
    for (final lv in kLevels) {
      await _prefs.remove('hs_${lv.index}');
    }
  }

  Future<void> _saveProgress({required bool win}) async {
    final lv = currentLevel.value;
    final prev = highScores[lv] ?? 0;
    if (score.value > prev) {
      highScores[lv] = score.value;
      await _prefs.setInt('hs_$lv', score.value);
    }
    if (win && lv >= unlockedLevel.value && lv < kLevels.length) {
      unlockedLevel.value = lv + 1;
      await _prefs.setInt('unlockedLevel', unlockedLevel.value);
    }
  }
}

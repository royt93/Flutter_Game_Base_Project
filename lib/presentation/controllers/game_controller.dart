import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
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

  // Time Attack: thời gian còn lại (giây).
  final RxInt timeLeft = 0.obs;

  // Drop Down: số ingredient đã đưa xuống đáy.
  final RxInt dropped = 0.obs;

  // Obstacle (ice/chain/stone): tiến trình dọn sạch.
  final RxInt obstacleCleared = 0.obs;
  final RxInt obstacleTotal = 0.obs;

  // --- Daily reward ---
  final RxInt dailyStreak = 0.obs;

  // --- Lives / energy ---
  static const int maxLives = 5;
  static const int regenSeconds = 15 * 60; // hồi 1 mạng mỗi 15 phút
  final RxInt lives = maxLives.obs;

  /// Đồng hồ hệ thống — tách ra để test inject được thời điểm.
  DateTime Function() clock = DateTime.now;

  /// Level cao nhất đã mở khóa.
  final RxInt unlockedLevel = 1.obs;

  /// High score & số sao (0-3) theo từng level.
  final RxMap<int, int> highScores = <int, int>{}.obs;
  final RxMap<int, int> stars = <int, int>{}.obs;

  // --- Kinh tế & booster ---
  final RxInt coins = 0.obs;
  final RxInt boosterHammer = 0.obs; // đập 1 gem
  final RxInt boosterMoves = 0.obs; // +10 lượt
  final RxInt boosterSwap = 0.obs; // đổi 2 gem bất kỳ
  final RxInt boosterBomb = 0.obs; // nổ 3x3
  final RxInt boosterColor = 0.obs; // xoá 1 màu
  // Booster độc quyền (theme lá bài)
  final RxInt boosterJoker = 0.obs; // biến 1 gem thành Rainbow
  final RxInt boosterLightning = 0.obs; // sét phá nhiều gem cùng màu
  final RxInt boosterRoyal = 0.obs; // Royal Flush: nổ cả bàn
  final RxInt boosterGravity = 0.obs; // đảo trọng lực (đảo cột)

  /// Số sao đạt được ở ván vừa kết thúc (cho dialog celebration).
  int lastStars = 0;
  int lastCoinReward = 0;

  bool _resolved = false;
  final StorageService _store = StorageService.to;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void _load() {
    unlockedLevel.value = _store.getInt(StorageKeys.unlockedLevel, def: 1);
    coins.value = _store.getInt(StorageKeys.coins, def: 50); // tặng 50 xu
    boosterHammer.value = _store.getInt(StorageKeys.bHammer, def: 2);
    boosterMoves.value = _store.getInt(StorageKeys.bMoves, def: 2);
    boosterSwap.value = _store.getInt(StorageKeys.bSwap, def: 1);
    boosterBomb.value = _store.getInt(StorageKeys.bBomb, def: 1);
    boosterColor.value = _store.getInt(StorageKeys.bColor, def: 0);
    boosterJoker.value = _store.getInt(StorageKeys.bJoker, def: 1);
    boosterLightning.value = _store.getInt(StorageKeys.bLightning, def: 1);
    boosterRoyal.value = _store.getInt(StorageKeys.bRoyal, def: 0);
    boosterGravity.value = _store.getInt(StorageKeys.bGravity, def: 1);
    for (final lv in kLevels) {
      final hs = _store.getInt(StorageKeys.highScore(lv.index), def: -1);
      if (hs >= 0) highScores[lv.index] = hs;
      final st = _store.getInt(StorageKeys.star(lv.index), def: -1);
      if (st >= 0) stars[lv.index] = st;
    }
    dailyStreak.value = _store.getInt(StorageKeys.dailyStreak, def: 0);
    lives.value = _store.getInt(StorageKeys.lives, def: maxLives);
    refillLives();
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
    timeLeft.value = cfg.timeLimit;
    dropped.value = 0;
    obstacleCleared.value = 0;
    obstacleTotal.value = 0;
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

  /// Drop Down: 1 ingredient vừa chạm đáy bàn.
  void registerDrop() => dropped.value++;

  /// Obstacle: vừa dọn được [amount] lớp obstacle.
  void registerObstacleClear([int amount = 1]) {
    obstacleCleared.value += amount;
  }

  /// Time Attack: trôi qua [seconds] giây.
  void tickTime([int seconds = 1]) {
    if (timeLeft.value > 0) {
      timeLeft.value = (timeLeft.value - seconds).clamp(0, 1 << 30);
    }
  }

  /// Time Attack: thưởng thêm giây (combo lớn).
  void addTime(int seconds) {
    if (level.objective == ObjectiveType.timeAttack) {
      timeLeft.value += seconds;
    }
  }

  void useMove() {
    if (movesLeft.value > 0) movesLeft.value--;
  }

  bool get hasWon {
    switch (level.objective) {
      case ObjectiveType.score:
      case ObjectiveType.timeAttack:
        return score.value >= targetScore.value;
      case ObjectiveType.collect:
        return collected.value >= level.collectTarget;
      case ObjectiveType.clearJelly:
        return jellyTotal.value > 0 && jellyCleared.value >= jellyTotal.value;
      case ObjectiveType.dropDown:
        return dropped.value >= level.dropTarget;
      case ObjectiveType.clearObstacle:
        return obstacleTotal.value > 0 &&
            obstacleCleared.value >= obstacleTotal.value;
    }
  }

  /// Time Attack tính theo thời gian; các mode khác tính theo lượt.
  bool get isOutOfMoves {
    if (level.objective == ObjectiveType.timeAttack) return false;
    return movesLeft.value <= 0;
  }

  bool get isOutOfTime =>
      level.objective == ObjectiveType.timeAttack && timeLeft.value <= 0;

  double get objectiveProgress {
    switch (level.objective) {
      case ObjectiveType.score:
      case ObjectiveType.timeAttack:
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
      case ObjectiveType.dropDown:
        return level.dropTarget == 0
            ? 0
            : (dropped.value / level.dropTarget).clamp(0.0, 1.0);
      case ObjectiveType.clearObstacle:
        return obstacleTotal.value == 0
            ? 0
            : (obstacleCleared.value / obstacleTotal.value).clamp(0.0, 1.0);
    }
  }

  /// Tính số sao (1-3) khi thắng dựa trên hiệu suất.
  int computeStars() {
    // score & timeAttack: theo tỉ lệ vượt điểm mục tiêu
    if (level.objective == ObjectiveType.score ||
        level.objective == ObjectiveType.timeAttack) {
      final r = targetScore.value == 0 ? 1.0 : score.value / targetScore.value;
      if (r >= 1.8) return 3;
      if (r >= 1.35) return 2;
      return 1;
    }
    // collect/jelly/drop/obstacle: còn càng nhiều lượt càng nhiều sao
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
    if (isOutOfMoves || isOutOfTime) {
      _resolved = true;
      lastStars = 0;
      lastCoinReward = 0;
      _saveProgress(win: false);
      return 'lose';
    }
    return null;
  }

  // --- Booster ---
  bool useHammer() => _useBooster(StorageKeys.bHammer, boosterHammer);

  /// +10 lượt. Trả về true nếu còn booster.
  bool useMovesBooster() {
    if (!_useBooster(StorageKeys.bMoves, boosterMoves)) return false;
    movesLeft.value += 10;
    return true;
  }

  bool useSwap() => _useBooster(StorageKeys.bSwap, boosterSwap);
  bool useBomb() => _useBooster(StorageKeys.bBomb, boosterBomb);
  bool useColor() => _useBooster(StorageKeys.bColor, boosterColor);
  bool useJoker() => _useBooster(StorageKeys.bJoker, boosterJoker);
  bool useLightning() => _useBooster(StorageKeys.bLightning, boosterLightning);
  bool useRoyal() => _useBooster(StorageKeys.bRoyal, boosterRoyal);
  bool useGravity() => _useBooster(StorageKeys.bGravity, boosterGravity);

  bool _useBooster(String key, RxInt count) {
    if (count.value <= 0) return false;
    count.value--;
    _store.setInt(key, count.value);
    return true;
  }

  /// Mua booster bằng xu. Trả về true nếu đủ xu.
  bool buyHammer({int price = 30}) => _buy(StorageKeys.bHammer, boosterHammer, price);
  bool buyMoves({int price = 40}) => _buy(StorageKeys.bMoves, boosterMoves, price);
  bool buySwap({int price = 40}) => _buy(StorageKeys.bSwap, boosterSwap, price);
  bool buyBomb({int price = 50}) => _buy(StorageKeys.bBomb, boosterBomb, price);
  bool buyColor({int price = 80}) => _buy(StorageKeys.bColor, boosterColor, price);
  bool buyJoker({int price = 60}) => _buy(StorageKeys.bJoker, boosterJoker, price);
  bool buyLightning({int price = 60}) =>
      _buy(StorageKeys.bLightning, boosterLightning, price);
  bool buyRoyal({int price = 120}) => _buy(StorageKeys.bRoyal, boosterRoyal, price);
  bool buyGravity({int price = 50}) =>
      _buy(StorageKeys.bGravity, boosterGravity, price);

  bool _buy(String key, RxInt count, int price) {
    if (coins.value < price) return false;
    coins.value -= price;
    count.value++;
    _store.setInt(StorageKeys.coins, coins.value);
    _store.setInt(key, count.value);
    return true;
  }

  Future<void> resetProgress() async {
    debugPrint('roy93~ resetProgress START unlocked=${unlockedLevel.value} '
        'highScores=${highScores.length} stars=${stars.length} coins=${coins.value}');
    unlockedLevel.value = 1;
    highScores.clear();
    stars.clear();
    await _store.setInt(StorageKeys.unlockedLevel, 1);
    for (final lv in kLevels) {
      await _store.remove(StorageKeys.highScore(lv.index));
      await _store.remove(StorageKeys.star(lv.index));
    }
    debugPrint('roy93~ resetProgress DONE unlocked=${unlockedLevel.value} '
        'highScores=${highScores.length} stars=${stars.length}');
  }

  // --------------------------------------------------------------------------
  // Daily reward (thưởng đăng nhập hằng ngày)
  // --------------------------------------------------------------------------
  int get _todayEpochDay {
    final n = clock();
    return DateTime(n.year, n.month, n.day).millisecondsSinceEpoch ~/ 86400000;
  }

  /// Chưa nhận quà hôm nay?
  bool get canClaimDaily =>
      _store.getInt(StorageKeys.dailyLastClaim, def: -1) != _todayEpochDay;

  /// Xu thưởng cho ngày thứ [day] trong chuỗi (1-based), chu kỳ 7 ngày:
  /// 20, 35, 50, 65, 80, 95, 110 rồi lặp lại.
  int dailyRewardFor(int day) {
    final d = ((day - 1) % 7) + 1; // 1..7
    return 20 + (d - 1) * 15;
  }

  /// Nhận quà hằng ngày. Trả về số xu nhận (0 nếu đã nhận hôm nay).
  int claimDaily() {
    if (!canClaimDaily) return 0;
    final today = _todayEpochDay;
    final last = _store.getInt(StorageKeys.dailyLastClaim, def: -1);
    // liên tục (hôm qua) → +1; gãy hoặc lần đầu → reset về 1
    dailyStreak.value = (last == today - 1) ? dailyStreak.value + 1 : 1;
    final reward = dailyRewardFor(dailyStreak.value);
    coins.value += reward;
    _store.setInt(StorageKeys.coins, coins.value);
    _store.setInt(StorageKeys.dailyStreak, dailyStreak.value);
    _store.setInt(StorageKeys.dailyLastClaim, today);
    return reward;
  }

  // --------------------------------------------------------------------------
  // Lives / energy (mạng hồi theo thời gian)
  // --------------------------------------------------------------------------
  static const int _regenMs = regenSeconds * 1000;

  bool get hasLife => lives.value > 0;

  /// Hồi mạng theo thời gian đã trôi qua kể từ mốc [livesRegenAt].
  void refillLives() {
    if (lives.value >= maxLives) return;
    final now = clock().millisecondsSinceEpoch;
    var regenAt = _store.getInt(StorageKeys.livesRegenAt, def: 0);
    if (regenAt == 0) {
      // trạng thái thiếu mốc (vd lần đầu cài < max) → đặt mốc hồi từ giờ
      regenAt = now + _regenMs;
      _store.setInt(StorageKeys.livesRegenAt, regenAt);
      return;
    }
    if (now < regenAt) return;
    final elapsed = now - regenAt;
    final gained = 1 + elapsed ~/ _regenMs;
    lives.value = (lives.value + gained).clamp(0, maxLives);
    if (lives.value >= maxLives) {
      _store.remove(StorageKeys.livesRegenAt);
    } else {
      final remainder = elapsed % _regenMs;
      _store.setInt(StorageKeys.livesRegenAt, now - remainder + _regenMs);
    }
    _store.setInt(StorageKeys.lives, lives.value);
  }

  /// Mua đầy mạng bằng xu. Trả về false nếu đã đầy hoặc thiếu xu.
  bool buyRefillLives({int price = 60}) {
    if (lives.value >= maxLives) return false;
    if (coins.value < price) return false;
    coins.value -= price;
    lives.value = maxLives;
    _store.remove(StorageKeys.livesRegenAt);
    _store.setInt(StorageKeys.coins, coins.value);
    _store.setInt(StorageKeys.lives, lives.value);
    return true;
  }

  /// Trừ 1 mạng (khi thua). Trả về false nếu đã hết mạng.
  bool consumeLife() {
    if (lives.value <= 0) return false;
    final wasMax = lives.value >= maxLives;
    lives.value--;
    if (wasMax) {
      // vừa rời mức tối đa → bắt đầu đếm hồi
      _store.setInt(
          StorageKeys.livesRegenAt, clock().millisecondsSinceEpoch + _regenMs);
    }
    _store.setInt(StorageKeys.lives, lives.value);
    return true;
  }

  /// Thời gian còn lại tới khi hồi 1 mạng (Duration.zero nếu đầy/không chờ).
  Duration get timeToNextLife {
    if (lives.value >= maxLives) return Duration.zero;
    final regenAt = _store.getInt(StorageKeys.livesRegenAt, def: 0);
    if (regenAt == 0) return Duration.zero;
    final ms = regenAt - clock().millisecondsSinceEpoch;
    return ms <= 0 ? Duration.zero : Duration(milliseconds: ms);
  }

  Future<void> _saveProgress({required bool win}) async {
    final lv = currentLevel.value;
    final prev = highScores[lv] ?? 0;
    if (score.value > prev) {
      highScores[lv] = score.value;
      await _store.setInt(StorageKeys.highScore(lv), score.value);
    }
    if (win) {
      final prevStar = stars[lv] ?? 0;
      if (lastStars > prevStar) {
        stars[lv] = lastStars;
        await _store.setInt(StorageKeys.star(lv), lastStars);
      }
      coins.value += lastCoinReward;
      await _store.setInt(StorageKeys.coins, coins.value);
      if (lv >= unlockedLevel.value && lv < kLevels.length) {
        unlockedLevel.value = lv + 1;
        await _store.setInt(StorageKeys.unlockedLevel, unlockedLevel.value);
      }
    }
  }
}

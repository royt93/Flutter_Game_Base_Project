import 'dart:async';

import 'package:get/get.dart';
import '../../core/debug_log.dart';
import '../../core/storage_service.dart';
import '../../data/achievements.dart';
import '../../data/battle_pass.dart';
import '../../data/levels.dart';
import '../../data/season.dart';
import '../../data/story.dart';
import '../../data/temple.dart';
import '../../logic/gem_data.dart';
import '../../logic/rhythm_clock.dart';
import 'achievement_controller.dart';
import 'battle_pass_controller.dart';
import 'season_controller.dart';
import 'temple_controller.dart';

/// Quản lý state ván chơi + tiến trình (GetX).
class GameController extends GetxController {
  final RxInt score = 0.obs;
  final RxInt movesLeft = 0.obs;
  final RxInt targetScore = 0.obs;
  final RxInt comboCount = 0.obs;
  final RxInt runMaxCombo = 0.obs; // combo cao nhất trong VÁN hiện tại (cho quest)
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

  // --- Endless mode (Wave 6) ---
  final RxBool isEndless = false.obs;
  final RxInt endlessStage = 1.obs; // tăng theo điểm → khó hơn + đổi màu
  final RxInt endlessHigh = 0.obs; // high score riêng của Endless
  LevelConfig? _endlessCfg; // cấu hình màn endless (không thuộc kLevels)

  // --- Boss neon (Wave 8) ---
  final RxBool isBoss = false.obs;
  final RxInt bossHp = 0.obs;
  final RxInt bossMaxHp = 0.obs;
  final RxInt bossStage = 1.obs; // chọn từ Home (1..n) → máu + né tăng
  final RxInt bossWeakColor = 0.obs; // index màu điểm yếu (đổi theo phase)
  LevelConfig? _bossCfg;
  int _bossHitsSinceRetaliate = 0;
  /// Đã clear ÍT NHẤT 1 gem đúng màu điểm yếu trong nhịp resolve hiện tại?
  /// Bật bởi [registerClear], tiêu thụ (×2 sát thương) trong [_bossDamage].
  bool _weakHitPending = false;

  // --- Trọng lực động (Wave 8) ---
  final RxBool isGravity = false.obs;
  final RxInt gravityDir = 0.obs; // 0 = xuống (mặc định), 1 = lên (đã lật)
  LevelConfig? _gravityCfg;
  int _gravityMoveCount = 0;

  // --- Rhythm mode (Wave 8) — ghép theo nhịp ---
  final RxBool isRhythm = false.obs;
  LevelConfig? _rhythmCfg;
  final RhythmClock rhythm = RhythmClock(bpm: kRhythmBpm);
  final RxInt rhythmBeat = 0.obs; // tăng mỗi mốc beat → đập HUD
  final RxInt groove = 0.obs; // chuỗi đúng nhịp (0..[kGrooveMax])
  final RxInt lastBeatJudge = 0.obs; // 0 chưa đánh, 1 đúng nhịp, -1 lệch nhịp
  bool _rhythmBonusPending = false;

  /// Trần groove (đúng nhịp liên tiếp) → hệ số thưởng điểm tối đa.
  static const int kGrooveMax = 8;

  /// Ngưỡng combo để gây sát thương GẤP ĐÔI (đánh đúng "phase yếu").
  static const int bossWeakCombo = 4;

  // --- Daily reward ---
  final RxInt dailyStreak = 0.obs;

  // --- Win streak + thống kê (Wave 5) ---
  final RxInt winStreak = 0.obs; // thắng liên tiếp hiện tại
  final RxInt bestWinStreak = 0.obs; // kỷ lục streak
  final RxInt totalWins = 0.obs; // tổng số màn thắng
  final RxInt bestCombo = 0.obs; // combo cao nhất từng đạt
  final RxInt coinsEarnedTotal = 0.obs; // tổng xu kiếm (lifetime)

  /// Bonus xu từ win-streak ở ván vừa thắng (cho dialog).
  int lastStreakBonus = 0;

  /// Tổng sao đã đạt (mọi màn) — dùng cho thành tựu.
  int get totalStars =>
      stars.values.fold(0, (sum, s) => sum + s);

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
  final RxInt shards = 0.obs; // Wave 7: mảnh neon để xây "Đền Neon"

  /// Shard nhận ở ván vừa thắng (cho dialog). Endless không cho shard.
  int lastShardReward = 0;
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

  /// Pre-game booster (chọn trước khi vào màn) — đọc 1 lần ở GameScreenController.
  bool pendingMovesBoost = false;
  bool pendingArmHammer = false;

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
    winStreak.value = _store.getInt(StorageKeys.winStreak, def: 0);
    bestWinStreak.value = _store.getInt(StorageKeys.bestWinStreak, def: 0);
    totalWins.value = _store.getInt(StorageKeys.totalWins, def: 0);
    bestCombo.value = _store.getInt(StorageKeys.bestCombo, def: 0);
    coinsEarnedTotal.value = _store.getInt(StorageKeys.coinsEarned, def: 0);
    endlessHigh.value = _store.getInt(StorageKeys.endlessHigh, def: 0);
    shards.value = _store.getInt(StorageKeys.shards, def: 0);
    refillLives();
  }

  LevelConfig get level =>
      _bossCfg ??
      _endlessCfg ??
      _gravityCfg ??
      _rhythmCfg ??
      kLevels[currentLevel.value - 1];

  /// Đặt cờ chế độ ĐỘC QUYỀN (đúng 1 mode bật, hoặc tất cả false = màn thường)
  /// + xoá cfg các mode không bật. Gom 1 chỗ → 5 hàm start* khỏi lặp 8 dòng cờ.
  void _enterMode({
    bool endless = false,
    bool boss = false,
    bool gravity = false,
    bool rhythm = false,
  }) {
    isEndless.value = endless;
    isBoss.value = boss;
    isGravity.value = gravity;
    isRhythm.value = rhythm;
    if (!endless) _endlessCfg = null;
    if (!boss) _bossCfg = null;
    if (!gravity) _gravityCfg = null;
    if (!rhythm) _rhythmCfg = null;
  }

  /// Reset state CHUNG của 1 ván mới (mọi mode dùng) → khỏi lặp 12 dòng/hàm.
  void _resetRunState({required int moves, int target = 0, int time = 0}) {
    score.value = 0;
    comboCount.value = 0;
    runMaxCombo.value = 0;
    movesLeft.value = moves;
    targetScore.value = target;
    collected.value = 0;
    jellyCleared.value = 0;
    jellyTotal.value = 0;
    timeLeft.value = time;
    dropped.value = 0;
    obstacleCleared.value = 0;
    obstacleTotal.value = 0;
    _resolved = false;
  }

  void startLevel(int index) {
    _enterMode(); // tất cả false = màn thường
    currentLevel.value = index;
    final cfg = kLevels[index - 1];
    _resetRunState(
        moves: cfg.moves, target: cfg.targetScore, time: cfg.timeLimit);
  }

  /// Bắt đầu chế độ Endless (thử thách tăng dần).
  void startEndless() {
    _endlessCfg = buildEndlessLevel();
    _enterMode(endless: true);
    endlessStage.value = 1;
    _resetRunState(moves: _endlessCfg!.moves);
  }

  /// Bắt đầu chế độ Trọng lực động (chế độ riêng). Bàn tự lật mỗi N lượt.
  void startGravity() {
    _gravityCfg = buildGravityLevel();
    _enterMode(gravity: true);
    gravityDir.value = 0;
    _gravityMoveCount = 0;
    _resetRunState(
        moves: _gravityCfg!.moves, target: _gravityCfg!.targetScore);
  }

  /// Engine gọi sau mỗi lượt ở chế độ Trọng lực động: trả true mỗi
  /// [kGravityFlipEvery] lượt → engine lật bàn. Cập nhật hướng hiển thị.
  bool consumeGravityFlip() {
    if (!isGravity.value) return false;
    _gravityMoveCount++;
    if (_gravityMoveCount % kGravityFlipEvery == 0) {
      gravityDir.value = gravityDir.value == 0 ? 1 : 0;
      return true;
    }
    return false;
  }

  /// Bắt đầu chế độ Nhịp điệu (chế độ riêng). Ghép đúng nhịp → groove + thưởng điểm.
  void startRhythm() {
    _rhythmCfg = buildRhythmLevel();
    _enterMode(rhythm: true);
    rhythm.reset();
    rhythmBeat.value = 0;
    groove.value = 0;
    lastBeatJudge.value = 0;
    _rhythmBonusPending = false;
    _resetRunState(
        moves: _rhythmCfg!.moves, target: _rhythmCfg!.targetScore);
  }

  /// Engine gọi mỗi frame ở chế độ Rhythm: tiến đồng hồ nhịp, đập HUD mỗi beat.
  void tickRhythm(double dt) {
    if (!isRhythm.value) return;
    if (rhythm.tick(dt)) rhythmBeat.value = rhythm.beatCount;
  }

  /// Engine gọi lúc người chơi thực hiện nước đi HỢP LỆ: phán định đúng/lệch
  /// nhịp. Đúng nhịp → groove++ + bật cờ thưởng điểm (tiêu thụ ở [addScore]);
  /// lệch nhịp → groove-- + tắt thưởng.
  void judgeRhythmBeat() {
    if (!isRhythm.value) return;
    if (rhythm.onBeat) {
      groove.value = (groove.value + 1).clamp(0, kGrooveMax);
      lastBeatJudge.value = 1;
      _rhythmBonusPending = true;
    } else {
      groove.value = (groove.value - 1).clamp(0, kGrooveMax);
      lastBeatJudge.value = -1;
      _rhythmBonusPending = false;
    }
  }

  /// Bắt đầu trận Boss neon (chế độ riêng). [stage] tăng máu + đổi điểm yếu.
  void startBoss(int stage) {
    _bossCfg = buildBossLevel();
    _enterMode(boss: true);
    bossStage.value = stage.clamp(1, 99);
    bossMaxHp.value = kBossBaseHp + (bossStage.value - 1) * 700;
    bossHp.value = bossMaxHp.value;
    bossWeakColor.value = (stage - 1) % level.colorCount;
    _bossHitsSinceRetaliate = 0;
    _resetRunState(moves: _bossCfg!.moves);
  }

  /// Sát thương lên boss: tỉ lệ số gem × hệ số combo. Đánh TRÚNG màu điểm yếu
  /// ([_weakHitPending]) HOẶC combo ≥ [bossWeakCombo] → GẤP ĐÔI (cộng dồn được
  /// → ×4 nếu vừa trúng màu yếu vừa combo lớn). Đổi điểm yếu khi máu xuống nửa.
  void _bossDamage(int gemsCleared, int combo) {
    var dmg = gemsCleared * 12 + combo * 8;
    if (_weakHitPending) dmg *= 2; // trúng màu điểm yếu → thưởng sát thương
    if (combo >= bossWeakCombo) dmg *= 2;
    _weakHitPending = false; // tiêu thụ cờ cho nhịp kế
    bossHp.value = (bossHp.value - dmg).clamp(0, bossMaxHp.value);
    // phase 2 (máu < 50%) → đổi điểm yếu 1 lần (xác định theo phase, không nhấp nháy)
    final phase2 = bossHp.value <= bossMaxHp.value ~/ 2;
    bossWeakColor.value =
        ((bossStage.value - 1) + (phase2 ? 1 : 0)) % level.colorCount;
  }

  void addScore(int gemsCleared, int combo) {
    comboCount.value = combo;
    if (combo > runMaxCombo.value) runMaxCombo.value = combo;
    final multiplier = 1 + (combo - 1) * 0.5;
    var gained = (gemsCleared * 10 * multiplier).round();
    // Rhythm: ghép đúng nhịp → thưởng điểm theo groove (×1.5 .. ×2.5).
    if (isRhythm.value && _rhythmBonusPending) {
      final grooveMult = 1.5 + groove.value / kGrooveMax;
      gained = (gained * grooveMult).round();
      _rhythmBonusPending = false;
    }
    score.value += gained;
    if (isBoss.value) _bossDamage(gemsCleared, combo);
    if (combo > bestCombo.value) {
      bestCombo.value = combo;
      unawaited(_store.setInt(StorageKeys.bestCombo, combo));
    }
    if (isEndless.value) _endlessTick(gemsCleared);
  }

  /// Endless: cập nhật stage theo điểm, lưu high score, hoàn lượt khi ghép lớn.
  /// Độ khó tăng dần = lượt hoàn ÍT đi khi stage cao → chơi lâu sẽ cạn lượt.
  void _endlessTick(int gemsCleared) {
    final newStage = 1 + score.value ~/ kEndlessStageScore;
    if (newStage > endlessStage.value) endlessStage.value = newStage;
    if (score.value > endlessHigh.value) {
      endlessHigh.value = score.value;
      unawaited(_store.setInt(StorageKeys.endlessHigh, endlessHigh.value));
    }
    int refund = 0;
    if (gemsCleared >= 5) {
      refund = endlessStage.value <= 2 ? 2 : 1;
    } else if (gemsCleared >= 4) {
      refund = endlessStage.value <= 4 ? 1 : 0;
    }
    if (refund > 0) movesLeft.value += refund;
  }

  void registerClear(GemColor color, bool wasJelly) {
    if (level.objective == ObjectiveType.collect &&
        color == level.collectColor) {
      collected.value++;
    }
    if (wasJelly) jellyCleared.value++;
    // Boss: ghi nhận đã đánh trúng màu điểm yếu trong nhịp này → ×2 sát thương.
    if (isBoss.value && color.index == bossWeakColor.value) {
      _weakHitPending = true;
    }
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

  /// "Khoá" giai điệu (1..5) để AudioManager dịch tông: theo world của màn
  /// thường, hoặc theo stage ở chế độ phụ → mỗi bối cảnh một màu âm.
  int get melodyKey {
    if (isBoss.value) return bossStage.value;
    if (isEndless.value) return endlessStage.value;
    if (isGravity.value) return 2;
    return (1 + (currentLevel.value - 1) ~/ 20).clamp(1, 5);
  }

  void useMove() {
    if (movesLeft.value > 0) movesLeft.value--;
    // Boss phản đòn: mỗi 4 lượt rút thêm 1 lượt (áp lực tăng theo stage).
    if (isBoss.value && bossHp.value > 0) {
      _bossHitsSinceRetaliate++;
      final every = bossStage.value >= 3 ? 3 : 4;
      if (_bossHitsSinceRetaliate >= every) {
        _bossHitsSinceRetaliate = 0;
        if (movesLeft.value > 0) movesLeft.value--;
      }
    }
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
      case ObjectiveType.endless:
        return false; // Endless không có "win"
      case ObjectiveType.boss:
        return bossMaxHp.value > 0 && bossHp.value <= 0; // hạ gục boss
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
      case ObjectiveType.endless:
        // tiến trình tới stage kế tiếp
        return ((score.value % kEndlessStageScore) / kEndlessStageScore)
            .clamp(0.0, 1.0);
      case ObjectiveType.boss:
        // tiến trình = máu boss đã trừ
        return bossMaxHp.value == 0
            ? 0
            : (1 - bossHp.value / bossMaxHp.value).clamp(0.0, 1.0);
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

  /// Cap số bậc streak được thưởng + xu mỗi bậc.
  static const int _streakCap = 6;
  static const int _streakStep = 5;

  String? checkEnd() {
    if (_resolved) return null;
    // Endless: không có "win"; thua khi hết lượt. KHÔNG đụng win-streak/level.
    if (isEndless.value) {
      if (movesLeft.value <= 0) {
        _resolved = true;
        lastStars = 0;
        lastCoinReward = 0;
        lastStreakBonus = 0;
        lastShardReward = 0;
        if (score.value > endlessHigh.value) {
          endlessHigh.value = score.value;
          unawaited(_store.setInt(StorageKeys.endlessHigh, endlessHigh.value));
        }
        return 'lose';
      }
      return null;
    }
    // Boss: chế độ riêng — thắng khi hạ máu boss, thua khi hết lượt. Thưởng
    // xu/shard theo stage, KHÔNG đụng win-streak/level-unlock.
    if (isBoss.value) {
      if (hasWon) {
        _resolved = true;
        lastStars = computeStars();
        lastStreakBonus = 0;
        lastCoinReward = 40 + bossStage.value * 20 + lastStars * 10;
        lastShardReward = 2 + bossStage.value;
        addCoins(lastCoinReward);
        addShards(lastShardReward);
        return 'win';
      }
      if (movesLeft.value <= 0) {
        _resolved = true;
        lastStars = 0;
        lastCoinReward = 0;
        lastStreakBonus = 0;
        lastShardReward = 0;
        return 'lose';
      }
      return null;
    }
    // Rhythm: chế độ riêng — thắng khi đạt điểm mục tiêu, thua khi hết lượt.
    // Thưởng xu/shard theo sao + groove, KHÔNG đụng win-streak/level-unlock.
    if (isRhythm.value) {
      if (score.value >= targetScore.value) {
        _resolved = true;
        lastStars = computeStars();
        lastStreakBonus = 0;
        lastCoinReward = 20 + lastStars * 10 + groove.value * 3;
        lastShardReward = 1 + lastStars;
        addCoins(lastCoinReward);
        addShards(lastShardReward);
        return 'win';
      }
      if (movesLeft.value <= 0) {
        _resolved = true;
        lastStars = 0;
        lastCoinReward = 0;
        lastStreakBonus = 0;
        lastShardReward = 0;
        return 'lose';
      }
      return null;
    }
    if (hasWon) {
      _resolved = true;
      lastStars = computeStars();
      // win streak: tăng chuỗi + thưởng bonus theo chuỗi (từ bậc 2)
      winStreak.value++;
      if (winStreak.value > bestWinStreak.value) {
        bestWinStreak.value = winStreak.value;
        unawaited(_store.setInt(StorageKeys.bestWinStreak, bestWinStreak.value));
      }
      lastStreakBonus = winStreak.value >= 2
          ? winStreak.value.clamp(0, _streakCap) * _streakStep
          : 0;
      lastCoinReward = 10 + lastStars * 10 + lastStreakBonus; // 20/30/40 + bonus
      totalWins.value++;
      unawaited(_store.setInt(StorageKeys.winStreak, winStreak.value));
      unawaited(_store.setInt(StorageKeys.totalWins, totalWins.value));
      unawaited(_saveProgress(win: true));
      return 'win';
    }
    if (isOutOfMoves || isOutOfTime) {
      _resolved = true;
      lastStars = 0;
      lastCoinReward = 0;
      lastStreakBonus = 0;
      lastShardReward = 0;
      winStreak.value = 0;
      unawaited(_store.setInt(StorageKeys.winStreak, 0));
      unawaited(_saveProgress(win: false));
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
    unawaited(_store.setInt(key, count.value));
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

  /// Trần xu an toàn: SharedPreferences trên Android/iOS lưu int 32-bit
  /// (max ~2.14 tỷ). Vượt ngưỡng → lưu xuống đĩa thành số âm. Clamp dưới ngưỡng.
  static const int maxCoins = 2000000000;

  /// Gán xu (đã clamp [0, maxCoins]) + persist. Mọi thay đổi xu đi qua đây để
  /// tránh overflow & gom 1 chỗ ghi đĩa.
  void _setCoins(int value) {
    coins.value = value.clamp(0, maxCoins);
    unawaited(_store.setInt(StorageKeys.coins, coins.value));
  }

  /// Cộng xu (thưởng thành tựu / vòng quay…) + persist.
  void addCoins(int amount) {
    if (amount <= 0) return;
    _setCoins(coins.value + amount);
  }

  /// Gán shard (clamp [0, maxCoins]) + persist. Mọi thay đổi shard đi qua đây.
  void _setShards(int value) {
    shards.value = value.clamp(0, maxCoins);
    unawaited(_store.setInt(StorageKeys.shards, shards.value));
  }

  /// Cộng shard (thắng level / thưởng) + persist.
  void addShards(int amount) {
    if (amount <= 0) return;
    _setShards(shards.value + amount);
  }

  /// Tiêu shard để xây đền. Trả về false nếu không đủ.
  bool spendShards(int amount) {
    if (amount <= 0 || shards.value < amount) return false;
    _setShards(shards.value - amount);
    return true;
  }

  /// Tặng booster (vòng quay / pre-game) + persist.
  void _grant(String key, RxInt count, int n) {
    count.value += n;
    unawaited(_store.setInt(key, count.value));
  }

  void grantHammer([int n = 1]) => _grant(StorageKeys.bHammer, boosterHammer, n);
  void grantMovesBooster([int n = 1]) =>
      _grant(StorageKeys.bMoves, boosterMoves, n);
  void grantBomb([int n = 1]) => _grant(StorageKeys.bBomb, boosterBomb, n);
  void grantSwap([int n = 1]) => _grant(StorageKeys.bSwap, boosterSwap, n);

  /// Epoch-day hôm nay (công khai cho Lucky Wheel…).
  int get todayEpochDay => _todayEpochDay;

  bool _buy(String key, RxInt count, int price) {
    if (coins.value < price) return false;
    // Cộng booster TRƯỚC rồi mới trừ xu: nếu app bị kill giữa 2 lượt ghi đĩa,
    // người chơi mất ít rủi ro hơn (giữ booster) thay vì mất xu trắng.
    count.value++;
    unawaited(_store.setInt(key, count.value));
    _setCoins(coins.value - price);
    return true;
  }

  Future<void> resetProgress() async {
    dlog('resetProgress START unlocked=${unlockedLevel.value} '
        'highScores=${highScores.length} stars=${stars.length} coins=${coins.value}');

    // 1) Xoá MỌI key tiến trình trên đĩa (giữ lại cài đặt ngôn ngữ localeCode).
    //    Trước đây bỏ sót: coins, daily, wheel, lives, booster, tutorial,
    //    viewMode → "reset" nhưng xu/booster/mạng vẫn còn.
    final scalarKeys = <String>[
      StorageKeys.unlockedLevel,
      StorageKeys.coins,
      StorageKeys.shards,
      StorageKeys.dailyLastClaim,
      StorageKeys.dailyStreak,
      StorageKeys.lives,
      StorageKeys.livesRegenAt,
      StorageKeys.winStreak,
      StorageKeys.bestWinStreak,
      StorageKeys.totalWins,
      StorageKeys.bestCombo,
      StorageKeys.coinsEarned,
      StorageKeys.wheelLastSpin,
      StorageKeys.tutorialSeen,
      StorageKeys.viewMode,
      StorageKeys.endlessHigh,
      StorageKeys.bpXp,
      StorageKeys.bpLevel,
      StorageKeys.questDay,
      StorageKeys.seasonPoints,
      StorageKeys.seasonIdx,
      StorageKeys.bHammer,
      StorageKeys.bMoves,
      StorageKeys.bSwap,
      StorageKeys.bBomb,
      StorageKeys.bColor,
      StorageKeys.bJoker,
      StorageKeys.bLightning,
      StorageKeys.bRoyal,
      StorageKeys.bGravity,
    ];
    for (final k in scalarKeys) {
      await _store.remove(k);
    }
    for (final lv in kLevels) {
      await _store.remove(StorageKeys.highScore(lv.index));
      await _store.remove(StorageKeys.star(lv.index));
    }
    for (final n in kTempleNodes) {
      await _store.remove(StorageKeys.templeTier(n.id));
    }
    for (int i = 0; i < kPassTiers.length; i++) {
      await _store.remove(StorageKeys.bpClaimed(i));
    }
    for (int i = 0; i < 3; i++) {
      await _store.remove(StorageKeys.questProgress(i));
      await _store.remove(StorageKeys.questCredited(i));
    }
    final sIdx = seasonIndex(_todayEpochDay);
    for (int m = 0; m < kSeasonMilestones.length; m++) {
      await _store.remove(StorageKeys.seasonClaimed(sIdx, m));
    }
    for (final a in kAchievements) {
      await _store.remove(StorageKeys.achievementClaimed(a.id));
    }
    for (final b in kStory) {
      await _store.remove(StorageKeys.storySeen(b.id));
    }

    // 2) Xoá map in-memory rồi nạp lại GIÁ TRỊ MẶC ĐỊNH từ đĩa (đã trống) — đưa
    //    coins/booster/lives… về đúng như lần cài đầu thay vì giữ giá trị cũ.
    highScores.clear();
    stars.clear();
    _load();

    // 3) Reset state in-memory của các controller meta (permanent → không tự
    //    mất khi xoá đĩa). Bỏ bước này thì RAM giữ "đã nhận" → restart đọc đĩa
    //    trống ⇒ NHẬN LẠI thưởng Battle Pass / Season / Achievement / Temple.
    BattlePassController.maybe?.resetState();
    SeasonController.maybe?.resetState();
    AchievementController.maybe?.resetState();
    TempleController.maybe?.resetState();

    dlog('resetProgress DONE unlocked=${unlockedLevel.value} '
        'highScores=${highScores.length} stars=${stars.length} coins=${coins.value}');
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
    // Ghi mốc "đã nhận hôm nay" TRƯỚC khi cộng xu: nếu kill giữa chừng, tránh
    // exploit nhận thưởng nhiều lần (xấu nhất là mất 1 lượt thưởng, không lặp).
    unawaited(_store.setInt(StorageKeys.dailyLastClaim, today));
    unawaited(_store.setInt(StorageKeys.dailyStreak, dailyStreak.value));
    _setCoins(coins.value + reward);
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
      unawaited(_store.setInt(StorageKeys.livesRegenAt, regenAt));
      return;
    }
    if (now < regenAt) return;
    final elapsed = now - regenAt;
    final gained = 1 + elapsed ~/ _regenMs;
    lives.value = (lives.value + gained).clamp(0, maxLives);
    if (lives.value >= maxLives) {
      unawaited(_store.remove(StorageKeys.livesRegenAt));
    } else {
      final remainder = elapsed % _regenMs;
      unawaited(
          _store.setInt(StorageKeys.livesRegenAt, now - remainder + _regenMs));
    }
    unawaited(_store.setInt(StorageKeys.lives, lives.value));
  }

  /// Mua đầy mạng bằng xu. Trả về false nếu đã đầy hoặc thiếu xu.
  bool buyRefillLives({int price = 60}) {
    if (lives.value >= maxLives) return false;
    if (coins.value < price) return false;
    lives.value = maxLives;
    unawaited(_store.remove(StorageKeys.livesRegenAt));
    unawaited(_store.setInt(StorageKeys.lives, lives.value));
    _setCoins(coins.value - price);
    return true;
  }

  /// Trừ 1 mạng (khi thua). Trả về false nếu đã hết mạng.
  bool consumeLife() {
    if (lives.value <= 0) return false;
    final wasMax = lives.value >= maxLives;
    lives.value--;
    if (wasMax) {
      // vừa rời mức tối đa → bắt đầu đếm hồi
      unawaited(_store.setInt(
          StorageKeys.livesRegenAt, clock().millisecondsSinceEpoch + _regenMs));
    }
    unawaited(_store.setInt(StorageKeys.lives, lives.value));
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
      coins.value = (coins.value + lastCoinReward).clamp(0, maxCoins);
      coinsEarnedTotal.value =
          (coinsEarnedTotal.value + lastCoinReward).clamp(0, maxCoins);
      await _store.setInt(StorageKeys.coins, coins.value);
      await _store.setInt(StorageKeys.coinsEarned, coinsEarnedTotal.value);
      // Wave 7: thưởng Shard xây Đền Neon (1 + số sao). Endless không vào đây.
      lastShardReward = 1 + lastStars;
      addShards(lastShardReward);
      if (lv >= unlockedLevel.value && lv < kLevels.length) {
        unlockedLevel.value = lv + 1;
        await _store.setInt(StorageKeys.unlockedLevel, unlockedLevel.value);
      }
    }
  }
}

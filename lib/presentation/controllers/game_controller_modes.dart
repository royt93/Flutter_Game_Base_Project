part of 'game_controller.dart';

/// Khởi động & logic các CHẾ ĐỘ chơi (màn thường + Endless / Gravity / Rhythm /
/// Daily / Boss) + seed bàn + khoá giai điệu.
extension GameControllerModes on GameController {
  void startLevel(int index) {
    _enterMode(); // tất cả false = màn thường
    currentLevel.value = index;
    final cfg = kLevels[index - 1];
    // Wave 16 DDA/Pity: đọc số thua LIÊN TIẾP màn này → trợ giúp ẩn. Thua nhiều
    // (≥kPityMovesFails) → +lượt khởi đầu ẩn (engine đọc `pity` cho lucky/special).
    pity.value = _store.getInt(StorageKeys.pityFails(index), def: 0);
    final movesBonus = pity.value >= GameController.kPityMovesFails
        ? GameController.kPityMovesBonus
        : 0;
    _resetRunState(
      moves: cfg.moves + movesBonus,
      target: cfg.targetScore,
      time: cfg.timeLimit,
    );
  }

  /// Bắt đầu chế độ Endless (thử thách tăng dần).
  // ---------------------------------------------------------------------------
  // Wave 20.4 — Zen Mode: không thua, tích điểm tự do
  // ---------------------------------------------------------------------------

  /// Bắt đầu Rush Mode (Tốc chiến) — vô hạn lượt, 2 phút ban đầu.
  /// Mỗi match thêm thời gian: match-3 = +1s, match-4 = +2s... (cap 5 phút).
  void startRush() {
    _enterMode(rush: true);
    _resetRunState(
      moves: 999, // vô hạn — HUD hiển thị "∞"
      target: 1 << 28, // không kết thúc theo điểm
      time: GameController.kRushInitialSeconds,
    );
  }

  /// Bắt đầu Zen Mode — bàn 8×8, lượt vô hạn (999), KHÔNG kết thúc tự động.
  /// Người chơi thoát bằng nút X → `endZenSession()` lưu kỷ lục.
  void startZen() {
    _zenCfg =
        buildZenLevel(); // phải set trước _enterMode để level getter dùng đúng cfg
    _enterMode(zen: true);
    _resetRunState(
      moves: 999,
      target: 1 << 28, // unreachable — Zen không kết thúc tự động
    );
  }

  /// Gọi khi người chơi thoát Zen Mode qua nút X: lưu high score + thưởng xu nhỏ.
  void endZenSession() {
    if (!isZen.value) return;
    if (score.value > zenHigh.value) {
      zenHigh.value = score.value;
      unawaited(_store.setInt(StorageKeys.zenHigh, zenHigh.value));
    }
    // Thưởng xu theo điểm (nhỏ — Zen dễ farm, không giới hạn)
    final reward = discountSideModeReward((score.value ~/ 1000).clamp(5, 50));
    addCoins(reward);
    lastCoinReward = reward;
    lastStars = 0;
  }

  void startEndless() {
    _endlessCfg = buildEndlessLevel();
    _enterMode(endless: true);
    endlessStage.value = 1;
    endlessEvent.value = '';
    _endlessScoreX2Remaining = 0;
    _endlessGemRainPending = false;
    _endlessLastEventCount = 0;
    _resetRunState(moves: _endlessCfg!.moves);
  }

  /// Bắt đầu chế độ Trọng lực động (chế độ riêng). Bàn tự lật mỗi N lượt.
  void startGravity() {
    _gravityCfg = buildGravityLevel();
    _enterMode(gravity: true);
    gravityDir.value = 0;
    _gravityMoveCount = 0;
    _resetRunState(moves: _gravityCfg!.moves, target: _gravityCfg!.targetScore);
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
    rhythm.bpm = rhythmBpmFor(0);
    rhythm.window = rhythmWindowFor(0);
    rhythm.reset();
    rhythmBeat.value = 0;
    groove.value = 0;
    lastBeatJudge.value = 0;
    rhythmJudge.value = 0;
    rhythmBpm.value = rhythm.bpm;
    _rhythmBonusPending = false;
    _resetRunState(moves: _rhythmCfg!.moves, target: _rhythmCfg!.targetScore);
  }

  /// Engine gọi mỗi frame ở chế độ Rhythm: tiến đồng hồ nhịp, đập HUD mỗi beat.
  /// W21: cập nhật BPM + window theo groove hiện tại (dynamic difficulty).
  void tickRhythm(double dt) {
    if (!isRhythm.value) return;
    // Đồng bộ BPM + window theo groove (chỉ cập nhật khi thực sự thay đổi).
    final newBpm = rhythmBpmFor(groove.value);
    if (rhythm.bpm != newBpm) {
      rhythm.bpm = newBpm;
      rhythm.window = rhythmWindowFor(groove.value);
    }
    rhythmBpm.value = rhythm.bpm; // luôn sync (kể cả khi không thay đổi)
    if (rhythm.tick(dt)) rhythmBeat.value = rhythm.beatCount;
  }

  /// Engine gọi lúc người chơi thực hiện nước đi HỢP LỆ: phán định đúng/lệch
  /// nhịp. W21: phân loại chi tiết PERFECT/GOOD/LATE/MISS qua [rhythmJudge].
  void judgeRhythmBeat() {
    if (!isRhythm.value) return;
    final dist = rhythm.distanceToBeat;
    final judge = rhythmJudgeFor(dist, rhythm.window);
    rhythmJudge.value = judge; // 2=PERFECT, 1=GOOD, -1=LATE, -2=MISS
    // lastBeatJudge giữ tương thích: 1 = hit (PERFECT hoặc GOOD), -1 = miss
    lastBeatJudge.value = judge >= 1 ? 1 : -1;
    if (judge >= 1) {
      groove.value = (groove.value + 1).clamp(0, GameController.kGrooveMax);
      _rhythmBonusPending = true;
    } else {
      groove.value = (groove.value - 1).clamp(0, GameController.kGrooveMax);
      _rhythmBonusPending = false;
    }
  }

  /// Bắt đầu chế độ Color Rush (chế độ riêng): màu "nóng" đổi mỗi
  /// [kColorRushChangeEvery] lượt; clear gem màu nóng → điểm bội. Đạt điểm mục
  /// tiêu trong số lượt. KHÔNG đụng mạng/win-streak/level-unlock (side mode).
  void startColorRush() {
    _colorRushCfg = buildColorRushLevel();
    _enterMode(colorRush: true);
    _colorRushMoveCount = 0;
    colorRushHot.value = 0; // bắt đầu ở màu đầu (cyan) — tất định, test được
    colorRushStreak.value = 0;
    _colorRushHotClearedThisMove = false;
    _resetRunState(
      moves: _colorRushCfg!.moves,
      target: _colorRushCfg!.targetScore,
    );
  }

  /// Engine gọi sau MỖI nước đi hợp lệ ở Color Rush: cứ
  /// [kColorRushChangeEvery] lượt thì xoay màu nóng sang màu kế (tất định).
  /// W17.4: cập nhật streak trước khi đổi màu.
  void tickColorRush() {
    if (!isColorRush.value) return;
    _colorRushMoveCount++;
    if (_colorRushHotClearedThisMove) {
      colorRushStreak.value = (colorRushStreak.value + 1).clamp(
        0,
        kColorRushMaxStreak,
      );
    } else {
      colorRushStreak.value = 0;
    }
    _colorRushHotClearedThisMove = false;
    if (_colorRushMoveCount % kColorRushChangeEvery == 0) {
      colorRushHot.value = (colorRushHot.value + 1) % level.colorCount;
      colorRushStreak.value = 0; // màu mới → chuỗi mới
    }
  }

  /// Color Rush: thưởng điểm bội cho [gems] gem màu nóng vừa clear.
  /// W17.4: streak multiplier ×1→×2→×3.
  void colorRushBonus(int gems) {
    if (!isColorRush.value || gems <= 0) return;
    _colorRushHotClearedThisMove = true;
    final mult = (colorRushStreak.value + 1).clamp(1, kColorRushMaxStreak);
    score.value += gems * kColorRushBonusPerGem * mult;
  }

  /// Bắt đầu chế độ Soda (chế độ riêng): clear gem làm mực nước dâng, đẩy chai
  /// nổi lên đỉnh. Đưa đủ [LevelConfig.sodaTarget] chai → thắng trong số lượt.
  /// KHÔNG đụng mạng/win-streak/level-unlock (side mode).
  void startSoda() {
    _sodaCfg = buildSodaLevel();
    _enterMode(soda: true);
    _sodaMoveCount = 0;
    sodaNozzlePulse.value = 0;
    _resetRunState(moves: _sodaCfg!.moves);
  }

  /// Bắt đầu chế độ Sinh tồn (Survival — Wave 15): đồng hồ đếm ngược, combo ≥4 →
  /// +giây; HẾT GIỜ → kết thúc, điểm = thành tích (kỷ lục riêng). Tái dùng đồng
  /// hồ timeAttack. KHÔNG đụng mạng/win-streak/level-unlock (side mode).
  void startSurvival() {
    _survivalCfg = buildSurvivalLevel();
    _enterMode(survival: true);
    _resetRunState(
      moves: _survivalCfg!.moves,
      target: _survivalCfg!.targetScore,
      time: _survivalCfg!.timeLimit,
    );
  }

  /// Bắt đầu chế độ Mê cung neon (Labyrinth — Wave 15): đưa đủ tinh thể qua mê
  /// cung tường xuống đáy. Tái dùng cơ chế dropDown + layout. KHÔNG đụng mạng/
  /// win-streak/level-unlock (side mode).
  void startLabyrinth() {
    _labyrinthCfg = buildLabyrinthLevel();
    _enterMode(labyrinth: true);
    _resetRunState(moves: _labyrinthCfg!.moves);
  }

  /// Soda: mỗi gem clear làm mực nước dâng 1 đơn vị; mỗi [kSodaFillPerBottle]
  /// đơn vị → 1 chai nổi lên đỉnh. Gọi từ registerClear (tính cả cascade).
  void registerSodaFill([int gems = 1]) {
    if (!isSoda.value || gems <= 0) return;
    sodaFill.value += gems;
    final target = level.sodaTarget;
    sodaCollected.value = (sodaFill.value ~/ kSodaFillPerBottle).clamp(
      0,
      target,
    );
  }

  /// Soda: tiến độ mực nước 0..1 (cho overlay nước dâng).
  double get sodaProgress {
    final max = level.sodaTarget * kSodaFillPerBottle;
    return max == 0 ? 0 : (sodaFill.value / max).clamp(0.0, 1.0);
  }

  /// W17.4: Engine gọi sau MỖI lượt khi [isSoda] — nozzle phun thêm fill định kỳ.
  void tickSoda() {
    if (!isSoda.value) return;
    _sodaMoveCount++;
    if (_sodaMoveCount % kSodaNozzleEvery == 0) {
      registerSodaFill(kSodaNozzleBurst);
      sodaNozzlePulse.value++;
    }
  }

  /// Seed bàn cho engine: Daily dùng `epochDay` (mọi người CÙNG bàn); Cấu đố dùng
  /// seed cố định của cấu đố (W19.2 — bàn tất định để học/tối ưu); còn lại null
  /// (engine tự ngẫu nhiên). Versus truyền seed riêng.
  int? get boardSeed {
    if (isPuzzle.value) return _puzzleDef?.seed;
    if (isDaily.value) return _dailySeed;
    return null;
  }

  /// Bắt đầu 1 Cấu đố (W19.2): bàn seed cố định, KHÔNG refill (engine đọc isPuzzle),
  /// mục tiêu điểm trong ngân sách lượt. KHÔNG tốn mạng/đụng campaign (side mode).
  void startPuzzle(PuzzleDef def) {
    _puzzleDef = def;
    _puzzleCfg = buildPuzzleLevel(def);
    _enterMode(puzzle: true);
    _resetRunState(moves: def.maxMoves, target: def.target);
  }

  /// Đã HOÀN THÀNH (thắng) Thử thách ngày HÔM NAY chưa (đã nhận thưởng).
  bool get dailyChallengeDoneToday =>
      _store.getInt(StorageKeys.dailyChLastDone, def: -1) == _effectiveDay;

  /// Mutator hôm nay (tất định, tính từ effectiveDay). Dùng ở Home card không
  /// cần startDaily() — giá trị cùng với mutators áp khi bắt đầu ván.
  List<DailyMutator> get todayMutators => dailyMutatorsFor(todayEpochDay);

  /// Bắt đầu Thử thách hằng ngày: 1 màn seed theo NGÀY → mọi người cùng bàn +
  /// cùng mục tiêu. Chơi lại bao nhiêu lần cũng được nhưng chỉ THƯỞNG 1 lần/ngày.
  void startDaily() {
    _dailySeed = _effectiveDay;
    // W17.3: tính mutator tất định rồi bake vào config (noSpecial/doubleCombo trong
    // LevelConfig; only4Colors/lowMoves/bonusMoves thay đổi colorCount/moves).
    final mutators = dailyMutatorsFor(_dailySeed);
    _dailyCfg = buildDailyLevel(_dailySeed, mutators: mutators);
    _enterMode(daily: true);
    _resetRunState(moves: _dailyCfg!.moves, target: _dailyCfg!.targetScore);
  }

  /// Bắt đầu trận Boss neon (chế độ riêng). [stage] tăng máu + đổi điểm yếu.
  void startBoss(int stage, {double hpScale = 1.0, int miniBossWorld = 0}) {
    _bossCfg = buildBossLevel();
    _enterMode(boss: true);
    _miniBossWorld = miniBossWorld; // W23.2 — sau _enterMode (reset về 0)
    bossStage.value = stage.clamp(1, 99);
    // W22.5 — hpScale < 1 cho mini-boss (HP thấp hơn boss thường cùng stage).
    bossMaxHp.value = ((kBossBaseHp + (bossStage.value - 1) * 700) * hpScale)
        .round();
    bossHp.value = bossMaxHp.value;
    bossWeakColor.value = (stage - 1) % level.colorCount;
    _bossHitsSinceRetaliate = 0;
    _lastBossPhase = 0; // W23 — reset theo dõi đổi phase
    _resetRunState(moves: _bossCfg!.moves);
  }

  /// Sát thương lên boss: tỉ lệ số gem × hệ số combo. Đánh TRÚNG màu điểm yếu
  /// ([_weakHitPending]) HOẶC combo ≥ [bossWeakCombo] → GẤP ĐÔI (cộng dồn được
  /// → ×4 nếu vừa trúng màu yếu vừa combo lớn). Đổi điểm yếu khi máu xuống nửa.
  void _bossDamage(int gemsCleared, int combo) {
    var dmg = gemsCleared * 12 + combo * 8;
    if (_weakHitPending) dmg *= 2; // trúng màu điểm yếu → thưởng sát thương
    if (combo >= GameController.bossWeakCombo) dmg *= 2;
    _weakHitPending = false; // tiêu thụ cờ cho nhịp kế
    bossHp.value = (bossHp.value - dmg).clamp(0, bossMaxHp.value);
    // W23 — boss LÊN phase mới → bắn signal cho HUD flash "PHASE N!".
    if (bossPhase > _lastBossPhase) {
      _lastBossPhase = bossPhase;
      bossPhaseUpSignal.value++;
    }
    // phase 2 (máu < 50%) → đổi điểm yếu 1 lần (xác định theo phase, không nhấp nháy)
    final phase2 = bossHp.value <= bossMaxHp.value ~/ 2;
    bossWeakColor.value =
        ((bossStage.value - 1) + (phase2 ? 1 : 0)) % level.colorCount;
  }

  /// Endless: cập nhật stage theo điểm, lưu high score, hoàn lượt khi ghép lớn.
  /// Độ khó tăng dần = lượt hoàn ÍT đi khi stage cao → chơi lâu sẽ cạn lượt.
  void _endlessTick(int gemsCleared) {
    final newStage = 1 + score.value ~/ kEndlessStageScore;
    if (newStage > endlessStage.value) {
      endlessStage.value = newStage;
      // W17.4: kiểm tra ngưỡng event
      final eventsExpected = newStage ~/ kEndlessEventEveryStage;
      if (eventsExpected > _endlessLastEventCount) {
        _endlessLastEventCount = eventsExpected;
        _triggerEndlessEvent(_endlessLastEventCount);
      }
    }
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

  void _triggerEndlessEvent(int eventCount) {
    final type = (eventCount - 1) % 3; // 0=moves, 1=scoreX2, 2=gems
    switch (type) {
      case 0:
        movesLeft.value += kEndlessEventMovesBonus;
        endlessEvent.value = 'moves';
      case 1:
        _endlessScoreX2Remaining = kEndlessEventScoreBoostMoves;
        endlessEvent.value = 'scoreX2';
      case _:
        _endlessGemRainPending = true;
        endlessEvent.value = 'gems';
    }
  }

  /// Engine gọi để lấy và consume cờ gem rain (one-shot: tự reset sau khi đọc).
  bool consumeEndlessGemRain() {
    if (!_endlessGemRainPending) return false;
    _endlessGemRainPending = false;
    return true;
  }

  /// "Khoá" giai điệu (1..5) để AudioManager dịch tông: theo world của màn
  /// thường, hoặc theo stage ở chế độ phụ → mỗi bối cảnh một màu âm.
  int get melodyKey {
    if (isBoss.value) return bossStage.value;
    if (isEndless.value) return endlessStage.value;
    if (isGravity.value) return 2;
    if (isColorRush.value) return 4;
    return (1 + (currentLevel.value - 1) ~/ 20).clamp(1, 5);
  }

  // ---------------------------------------------------------------------------
  // Wave 20.3 — Ghost Replay
  // ---------------------------------------------------------------------------

  /// Ghi nhận 1 nước đi (được gọi từ engine khi swap hợp lệ ở màn campaign).
  void recordMove(int r1, int c1, int r2, int c2) {
    if (isSideMode || isGhostMode.value) return;
    if (_moveLog.length >= 150) return; // cap
    _moveLog.add('$r1$c1$r2$c2'); // format: "r1c1r2c2" (4 chars, coord 0-7)
  }

  /// Trả về nước đi ghost kế tiếp (r1,c1,r2,c2) hoặc null nếu hết / không ở ghost mode.
  (int, int, int, int)? nextGhostMove() {
    if (!isGhostMode.value) return null;
    final step = ghostStep.value;
    if (step >= _ghostMoves.length) return null;
    final s = _ghostMoves[step];
    if (s.length != 4) return null;
    return (int.parse(s[0]), int.parse(s[1]), int.parse(s[2]), int.parse(s[3]));
  }

  /// Advance ghost step khi người chơi thực hiện 1 nước đi (bất kể đúng/sai ghost).
  void advanceGhost() {
    if (!isGhostMode.value) return;
    final next = ghostStep.value + 1;
    if (next <= _ghostMoves.length) ghostStep.value = next;
  }

  /// Bắt đầu màn [level] ở chế độ Ghost Replay.
  ///
  /// **Design intent**: Ghost mode là màn CAMPAIGN thật với ghost hint overlay —
  /// KHÔNG phải side mode. Win/lose hoạt động bình thường: thắng → unlock màn
  /// kế + win-streak; thua → trừ mạng. Ghost chỉ là visual guide (pulsing ring
  /// trên 2 gem ghost sẽ swap). isGhostMode = true ngăn ghi đè ghost data mới
  /// (recordMove returns early khi isGhostMode) để bảo toàn ghost gốc.
  void startGhostMode(int level) {
    startLevel(level);
    final store = _store;
    final movesStr = store.getString(StorageKeys.ghostMoves(level)) ?? '';
    _ghostMoves = movesStr.isEmpty
        ? []
        : [
            for (int i = 0; i + 4 <= movesStr.length; i += 4)
              movesStr.substring(i, i + 4),
          ];
    ghostScore.value = store.getInt(StorageKeys.ghostScore(level));
    ghostStep.value = 0;
    isGhostMode.value = true;
  }

  /// Flush ghost: lưu moves khi win với score mới hơn.
  Future<void> _flushGhostIfBetter(int level, int finishScore) async {
    if (isSideMode || isGhostMode.value) return;
    final existing = _store.getInt(StorageKeys.ghostScore(level));
    if (finishScore > existing && _moveLog.isNotEmpty) {
      await _store.setString(StorageKeys.ghostMoves(level), _moveLog.join());
      await _store.setInt(StorageKeys.ghostScore(level), finishScore);
    }
    _moveLog.clear();
  }

  /// Có ghost data cho màn [level] không?
  bool hasGhost(int level) =>
      (_store.getString(StorageKeys.ghostMoves(level)) ?? '').isNotEmpty;
}

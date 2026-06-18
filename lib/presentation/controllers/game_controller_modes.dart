part of 'game_controller.dart';

/// Khởi động & logic các CHẾ ĐỘ chơi (màn thường + Endless / Gravity / Rhythm /
/// Daily / Boss) + seed bàn + khoá giai điệu.
extension GameControllerModes on GameController {
  void startLevel(int index) {
    _enterMode(); // tất cả false = màn thường
    currentLevel.value = index;
    final cfg = kLevels[index - 1];
    _resetRunState(
      moves: cfg.moves,
      target: cfg.targetScore,
      time: cfg.timeLimit,
    );
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
    rhythm.reset();
    rhythmBeat.value = 0;
    groove.value = 0;
    lastBeatJudge.value = 0;
    _rhythmBonusPending = false;
    _resetRunState(moves: _rhythmCfg!.moves, target: _rhythmCfg!.targetScore);
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
      groove.value = (groove.value + 1).clamp(0, GameController.kGrooveMax);
      lastBeatJudge.value = 1;
      _rhythmBonusPending = true;
    } else {
      groove.value = (groove.value - 1).clamp(0, GameController.kGrooveMax);
      lastBeatJudge.value = -1;
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
    _resetRunState(
      moves: _colorRushCfg!.moves,
      target: _colorRushCfg!.targetScore,
    );
  }

  /// Engine gọi sau MỖI nước đi hợp lệ ở Color Rush: cứ
  /// [kColorRushChangeEvery] lượt thì xoay màu nóng sang màu kế (tất định).
  void tickColorRush() {
    if (!isColorRush.value) return;
    _colorRushMoveCount++;
    if (_colorRushMoveCount % kColorRushChangeEvery == 0) {
      colorRushHot.value = (colorRushHot.value + 1) % level.colorCount;
    }
  }

  /// Color Rush: thưởng điểm bội cho [gems] gem màu nóng vừa clear (cộng thẳng,
  /// không qua hệ số combo).
  void colorRushBonus(int gems) {
    if (!isColorRush.value || gems <= 0) return;
    score.value += gems * kColorRushBonusPerGem;
  }

  /// Seed bàn cho engine: Thử thách ngày dùng `epochDay` (mọi người CÙNG bàn);
  /// các chế độ khác trả null (engine tự ngẫu nhiên). Versus truyền seed riêng.
  int? get boardSeed => isDaily.value ? _dailySeed : null;

  /// Đã HOÀN THÀNH (thắng) Thử thách ngày HÔM NAY chưa (đã nhận thưởng).
  bool get dailyChallengeDoneToday =>
      _store.getInt(StorageKeys.dailyChLastDone, def: -1) == _effectiveDay;

  /// Bắt đầu Thử thách hằng ngày: 1 màn seed theo NGÀY → mọi người cùng bàn +
  /// cùng mục tiêu. Chơi lại bao nhiêu lần cũng được nhưng chỉ THƯỞNG 1 lần/ngày.
  void startDaily() {
    _dailySeed = _effectiveDay;
    _dailyCfg = buildDailyLevel(_dailySeed);
    _enterMode(daily: true);
    _resetRunState(moves: _dailyCfg!.moves, target: _dailyCfg!.targetScore);
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
    if (combo >= GameController.bossWeakCombo) dmg *= 2;
    _weakHitPending = false; // tiêu thụ cờ cho nhịp kế
    bossHp.value = (bossHp.value - dmg).clamp(0, bossMaxHp.value);
    // phase 2 (máu < 50%) → đổi điểm yếu 1 lần (xác định theo phase, không nhấp nháy)
    final phase2 = bossHp.value <= bossMaxHp.value ~/ 2;
    bossWeakColor.value =
        ((bossStage.value - 1) + (phase2 ? 1 : 0)) % level.colorCount;
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

  /// "Khoá" giai điệu (1..5) để AudioManager dịch tông: theo world của màn
  /// thường, hoặc theo stage ở chế độ phụ → mỗi bối cảnh một màu âm.
  int get melodyKey {
    if (isBoss.value) return bossStage.value;
    if (isEndless.value) return endlessStage.value;
    if (isGravity.value) return 2;
    if (isColorRush.value) return 4;
    return (1 + (currentLevel.value - 1) ~/ 20).clamp(1, 5);
  }
}

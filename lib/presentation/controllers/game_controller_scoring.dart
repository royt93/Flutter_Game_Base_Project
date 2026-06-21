part of 'game_controller.dart';

/// Tính điểm, ghi nhận tiến trình mục tiêu, điều kiện thắng/thua + kết toán ván.
extension GameControllerScoring on GameController {
  void addScore(int gemsCleared, int combo) {
    comboCount.value = combo;
    if (combo > runMaxCombo.value) runMaxCombo.value = combo;
    // W17.3 doubleCombo mutator: phần bonus từ combo nhân đôi (×1.0 thay vì ×0.5).
    final comboBonusMult = level.doubleCombo ? 1.0 : 0.5;
    final multiplier = 1 + (combo - 1) * comboBonusMult;
    var gained = (gemsCleared * 10 * multiplier).round();
    // Rhythm: ghép đúng nhịp → thưởng điểm theo groove (×1.5 .. ×2.5).
    if (isRhythm.value && _rhythmBonusPending) {
      final grooveMult = 1.5 + groove.value / GameController.kGrooveMax;
      gained = (gained * grooveMult).round();
      _rhythmBonusPending = false;
    }
    // W17.4 Endless scoreX2 event: nhân đôi điểm trong kEndlessEventScoreBoostMoves lượt.
    if (isEndless.value && _endlessScoreX2Remaining > 0) {
      gained *= 2;
      _endlessScoreX2Remaining--;
      if (_endlessScoreX2Remaining == 0) endlessEvent.value = '';
    }
    score.value += gained;
    if (isBoss.value) _bossDamage(gemsCleared, combo);
    if (combo > bestCombo.value && !isVersus.value) {
      bestCombo.value = combo;
      unawaited(_store.setInt(StorageKeys.bestCombo, combo));
    }
    if (isEndless.value) _endlessTick(gemsCleared);
  }

  void registerClear(GemColor color, bool wasJelly) {
    if (level.objective == ObjectiveType.collect &&
        color == level.collectColor) {
      collected.value++;
    }
    // Order (Wave 10): mỗi gem clear trúng màu của 1 mục tiêu con chưa đủ → +1.
    if (level.objective == ObjectiveType.order) {
      final orders = level.orders;
      for (var i = 0; i < orders.length && i < orderProgress.length; i++) {
        if (color == orders[i].color && orderProgress[i] < orders[i].target) {
          orderProgress[i] = orderProgress[i] + 1;
        }
      }
    }
    if (wasJelly) jellyCleared.value++;
    // Soda (Wave 14): mỗi gem clear làm mực nước dâng → đẩy chai nổi lên.
    if (isSoda.value) registerSodaFill(1);
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

  void useMove() {
    if (isVersus.value) return; // versus: lượt vô hạn (đồng hồ quyết định)
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
      case ObjectiveType.order:
        final orders = level.orders;
        if (orders.isEmpty || orderProgress.length != orders.length) {
          return false;
        }
        for (var i = 0; i < orders.length; i++) {
          if (orderProgress[i] < orders[i].target) return false;
        }
        return true;
      case ObjectiveType.endless:
        return false; // Endless không có "win"
      case ObjectiveType.boss:
        return bossMaxHp.value > 0 && bossHp.value <= 0; // hạ gục boss
      case ObjectiveType.soda:
        return level.sodaTarget > 0 && sodaCollected.value >= level.sodaTarget;
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
      case ObjectiveType.order:
        final orders = level.orders;
        if (orders.isEmpty || orderProgress.length != orders.length) return 0;
        var done = 0, total = 0;
        for (var i = 0; i < orders.length; i++) {
          done += orderProgress[i].clamp(0, orders[i].target);
          total += orders[i].target;
        }
        return total == 0 ? 0 : (done / total).clamp(0.0, 1.0);
      case ObjectiveType.endless:
        // tiến trình tới stage kế tiếp
        return ((score.value % kEndlessStageScore) / kEndlessStageScore).clamp(
          0.0,
          1.0,
        );
      case ObjectiveType.boss:
        // tiến trình = máu boss đã trừ
        return bossMaxHp.value == 0
            ? 0
            : (1 - bossHp.value / bossMaxHp.value).clamp(0.0, 1.0);
      case ObjectiveType.soda:
        return sodaProgress; // mực nước 0..1
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
    // versus: không tự kết thúc, đồng hồ ngoài quyết định
    if (isVersus.value) return null;
    // Cấu đố (W19.2): thắng khi đạt điểm; thua khi hết lượt (bàn hữu hạn no-refill).
    // Sao theo HIỆU SUẤT (lượt dư). KHÔNG đụng win-streak/level/mạng (side mode).
    if (isPuzzle.value) {
      final def = currentPuzzle;
      if (score.value >= targetScore.value) {
        _resolved = true;
        lastStars = puzzleStarsFor(movesLeft.value, def?.maxMoves ?? level.moves);
        lastStreakBonus = 0;
        lastCoinReward = discountSideModeReward(20 + lastStars * 15);
        addCoins(lastCoinReward);
        if (def != null) PuzzleController.maybe?.recordWin(def.id, lastStars);
        return 'win';
      }
      if (movesLeft.value <= 0) {
        _resolved = true;
        lastStars = 0;
        lastCoinReward = 0;
        lastStreakBonus = 0;
        return 'lose';
      }
      return null;
    }
    // Zen: không có "win" và KHÔNG "thua" — chơi mãi mãi. Người chơi tự thoát.
    if (isZen.value) return null;
    // Endless: không có "win"; thua khi hết lượt. KHÔNG đụng win-streak/level.
    if (isEndless.value) {
      if (movesLeft.value <= 0) {
        _resolved = true;
        lastStars = 0;
        lastStreakBonus = 0;
        // Wave 12: thưởng xu theo STAGE đạt được (endgame loop) — chống farm
        // bằng diminishing returns chung. Stage cao = thưởng nhiều, khích lệ phá
        // kỷ lục thay vì "chơi cho vui mà không được gì".
        lastCoinReward = discountSideModeReward(endlessStage.value * 8);
        addCoins(lastCoinReward);
        if (score.value > endlessHigh.value) {
          endlessHigh.value = score.value;
          unawaited(_store.setInt(StorageKeys.endlessHigh, endlessHigh.value));
        }
        return 'lose';
      }
      return null;
    }
    // Boss: chế độ riêng — thắng khi hạ máu boss, thua khi hết lượt. Thưởng xu
    // theo stage (đã gộp phần shard cũ ×10), KHÔNG đụng win-streak/level-unlock.
    if (isBoss.value) {
      if (hasWon) {
        _resolved = true;
        lastStars = computeStars();
        lastStreakBonus = 0;
        // Wave 12: chống farm — giảm dần sau vài trận/ngày.
        lastCoinReward = discountSideModeReward(
          40 +
              bossStage.value * 20 +
              lastStars * 10 +
              (2 + bossStage.value) * 10, // gộp shard cũ (2+stage) → xu
        );
        addCoins(lastCoinReward);
        return 'win';
      }
      if (movesLeft.value <= 0) {
        _resolved = true;
        lastStars = 0;
        lastCoinReward = 0;
        lastStreakBonus = 0;
        return 'lose';
      }
      return null;
    }
    // Rhythm: chế độ riêng — thắng khi đạt điểm mục tiêu, thua khi hết lượt.
    // Thưởng xu theo sao + groove (đã gộp shard cũ ×10), KHÔNG đụng win-streak.
    if (isRhythm.value) {
      if (score.value >= targetScore.value) {
        _resolved = true;
        lastStars = computeStars();
        lastStreakBonus = 0;
        // Wave 12: chống farm — giảm dần sau vài trận/ngày.
        lastCoinReward = discountSideModeReward(
          20 +
              lastStars * 10 +
              groove.value * 3 +
              (1 + lastStars) * 10, // gộp shard cũ (1+sao) → xu
        );
        addCoins(lastCoinReward);
        return 'win';
      }
      if (movesLeft.value <= 0) {
        _resolved = true;
        lastStars = 0;
        lastCoinReward = 0;
        lastStreakBonus = 0;
        return 'lose';
      }
      return null;
    }
    // Trọng lực động: chế độ riêng — thắng khi đạt điểm mục tiêu, thua khi hết
    // lượt. Thưởng xu theo sao, KHÔNG đụng win-streak/level-unlock/mạng (như
    // Boss/Rhythm). Trước đây thiếu nhánh này → gravity rơi vào nhánh màn
    // thường (winStreak++, _saveProgress, unlock màn kế = currentLevel tồn đọng).
    if (isGravity.value) {
      if (hasWon) {
        _resolved = true;
        lastStars = computeStars();
        lastStreakBonus = 0;
        // Wave 12: bump 50→75 (3★) cho ngang màn thường + chống farm (giảm dần).
        lastCoinReward = discountSideModeReward(30 + lastStars * 15);
        addCoins(lastCoinReward);
        return 'win';
      }
      if (movesLeft.value <= 0) {
        _resolved = true;
        lastStars = 0;
        lastCoinReward = 0;
        lastStreakBonus = 0;
        return 'lose';
      }
      return null;
    }
    // Color Rush: chế độ riêng — thắng khi đạt điểm mục tiêu, thua khi hết lượt.
    // Thưởng xu theo sao, KHÔNG đụng win-streak/level-unlock/mạng (side mode).
    if (isColorRush.value) {
      if (hasWon) {
        _resolved = true;
        lastStars = computeStars();
        lastStreakBonus = 0;
        // Wave 12: bump 50→75 (3★) cho ngang màn thường + chống farm (giảm dần).
        lastCoinReward = discountSideModeReward(30 + lastStars * 15);
        addCoins(lastCoinReward);
        return 'win';
      }
      if (movesLeft.value <= 0) {
        _resolved = true;
        lastStars = 0;
        lastCoinReward = 0;
        lastStreakBonus = 0;
        return 'lose';
      }
      return null;
    }
    // Soda (Wave 14): chế độ riêng — thắng khi đủ chai nổi lên đỉnh, thua khi
    // hết lượt. Thưởng xu theo sao, KHÔNG đụng win-streak/level-unlock/mạng.
    if (isSoda.value) {
      if (hasWon) {
        _resolved = true;
        lastStars = computeStars();
        lastStreakBonus = 0;
        lastCoinReward = discountSideModeReward(30 + lastStars * 15);
        addCoins(lastCoinReward);
        return 'win';
      }
      if (movesLeft.value <= 0) {
        _resolved = true;
        lastStars = 0;
        lastCoinReward = 0;
        lastStreakBonus = 0;
        return 'lose';
      }
      return null;
    }
    // Sinh tồn (Survival — Wave 17.1 "Triều dâng"): KHÔNG có "win" — sống tới khi
    // NƯỚC CHẠM ĐỈNH (engine set `tideOverflow`); điểm = thành tích (kỷ lục riêng).
    // Thưởng xu theo điểm (chống farm). Như Endless nhưng kết thúc theo triều.
    if (isSurvival.value) {
      if (tideOverflow.value) {
        _resolved = true;
        lastStars = 0;
        lastStreakBonus = 0;
        lastCoinReward = discountSideModeReward((score.value ~/ 400) * 5);
        addCoins(lastCoinReward);
        if (score.value > survivalHigh.value) {
          survivalHigh.value = score.value;
          unawaited(_store.setInt(StorageKeys.survivalHigh, survivalHigh.value));
        }
        return 'lose'; // panel kết thúc (không có "next")
      }
      return null;
    }
    // Mê cung neon (Labyrinth — Wave 15): thắng khi đưa đủ tinh thể xuống đáy,
    // thua khi hết lượt. Thưởng xu theo sao, side-mode isolation.
    if (isLabyrinth.value) {
      if (hasWon) {
        _resolved = true;
        lastStars = computeStars();
        lastStreakBonus = 0;
        lastCoinReward = discountSideModeReward(30 + lastStars * 15);
        addCoins(lastCoinReward);
        return 'win';
      }
      if (movesLeft.value <= 0) {
        _resolved = true;
        lastStars = 0;
        lastCoinReward = 0;
        lastStreakBonus = 0;
        return 'lose';
      }
      return null;
    }
    // Thử thách hằng ngày: thắng khi đạt mục tiêu, thua khi hết lượt. Thưởng
    // xu/shard + cộng streak CHỈ 1 lần/ngày (chơi lại không farm được). KHÔNG
    // đụng win-streak/level-unlock.
    if (isDaily.value) {
      if (hasWon) {
        _resolved = true;
        lastStars = computeStars();
        lastStreakBonus = 0;
        if (!dailyChallengeDoneToday) {
          final last = _store.getInt(StorageKeys.dailyChLastDone, def: -1);
          // liền mạch (hôm qua đã hoàn thành) → +1; gãy/lần đầu → reset về 1
          dailyChStreak.value = (last == _effectiveDay - 1)
              ? dailyChStreak.value + 1
              : 1;
          // Ghi mốc "đã hoàn thành hôm nay" TRƯỚC khi thưởng (kill giữa chừng →
          // xấu nhất mất 1 lượt thưởng, KHÔNG farm lặp).
          unawaited(_store.setInt(StorageKeys.dailyChLastDone, _effectiveDay));
          unawaited(
            _store.setInt(StorageKeys.dailyChStreak, dailyChStreak.value),
          );
          if (dailyChStreak.value > dailyChBestStreak.value) {
            dailyChBestStreak.value = dailyChStreak.value;
            unawaited(
              _store.setInt(
                StorageKeys.dailyChBestStreak,
                dailyChBestStreak.value,
              ),
            );
          }
          // thưởng hậu hĩnh hơn màn thường (1 lần/ngày): theo sao + streak (cap 7)
          // + phần shard cũ (3+sao) đã gộp ×10 vào xu.
          lastCoinReward =
              60 +
              lastStars * 20 +
              dailyChStreak.value.clamp(1, 7) * 10 +
              (3 + lastStars) * 10;
          addCoins(lastCoinReward);
        } else {
          // đã nhận hôm nay → chơi lại chỉ để luyện, không thưởng nữa
          lastCoinReward = 0;
        }
        return 'win';
      }
      if (movesLeft.value <= 0) {
        _resolved = true;
        lastStars = 0;
        lastCoinReward = 0;
        lastStreakBonus = 0;
        return 'lose';
      }
      return null;
    }
    if (hasWon) {
      _resolved = true;
      lastStars = computeStars();
      // Wave 14: first-clear = chưa có sao cho màn này TRƯỚC khi _saveProgress ghi
      // (thắng lại màn đã qua → false → meta Album/Heo/Giải đấu không cộng).
      lastFirstClear = (stars[currentLevel.value] ?? 0) == 0;
      // Wave 16 DDA: thắng → reset số thua liên tiếp màn này (hết trợ giúp ẩn).
      unawaited(_store.setInt(StorageKeys.pityFails(currentLevel.value), 0));
      // win streak: tăng chuỗi + thưởng bonus theo chuỗi (từ bậc 2)
      winStreak.value++;
      if (winStreak.value > bestWinStreak.value) {
        bestWinStreak.value = winStreak.value;
        unawaited(
          _store.setInt(StorageKeys.bestWinStreak, bestWinStreak.value),
        );
      }
      lastStreakBonus = winStreak.value >= 2
          ? winStreak.value.clamp(0, GameController._streakCap) *
                GameController._streakStep
          : 0;
      // Tính ĐỦ phần thưởng ĐỒNG BỘ tại đây (gồm phần shard cũ (1+sao)×10 đã gộp
      // vào xu) → onGameEnd/BattlePass đọc lastCoinReward NGAY sau khi return 'win'
      // thấy giá trị đầy đủ. Trước đây phần (1+sao)×10 cộng trong _saveProgress sau
      // 1 await (chỉ khi có high-score mới) → quest "earnCoins" đếm thiếu.
      lastCoinReward =
          10 + lastStars * 10 + lastStreakBonus + (1 + lastStars) * 10;
      totalWins.value++;
      unawaited(_store.setInt(StorageKeys.winStreak, winStreak.value));
      unawaited(_store.setInt(StorageKeys.totalWins, totalWins.value));
      unawaited(_saveProgress(win: true));
      return 'win';
    }
    // Thua: hết lượt / hết giờ / HOẶC 1 quả bom đếm ngược nổ (Wave 10).
    if (isOutOfMoves || isOutOfTime || bombExploded.value) {
      _resolved = true;
      lastStars = 0;
      lastCoinReward = 0;
      lastStreakBonus = 0;
      winStreak.value = 0;
      unawaited(_store.setInt(StorageKeys.winStreak, 0));
      // Wave 16 DDA: thua → tăng số thua liên tiếp màn này → trợ giúp ẩn lần sau.
      // Audit-fix: CLAMP ở kPityMovesFails (ngưỡng trợ giúp cao nhất) → trợ giúp
      // bão hoà, không phình số + không thưởng thêm cho "cố thua farm" quá ngưỡng.
      final f = _store.getInt(StorageKeys.pityFails(currentLevel.value), def: 0);
      final next = (f + 1).clamp(0, GameController.kPityMovesFails);
      unawaited(_store.setInt(StorageKeys.pityFails(currentLevel.value), next));
      unawaited(_saveProgress(win: false));
      return 'lose';
    }
    return null;
  }
}

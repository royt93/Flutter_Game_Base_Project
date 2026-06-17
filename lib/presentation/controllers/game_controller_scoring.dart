part of 'game_controller.dart';

/// Tính điểm, ghi nhận tiến trình mục tiêu, điều kiện thắng/thua + kết toán ván.
extension GameControllerScoring on GameController {
  void addScore(int gemsCleared, int combo) {
    comboCount.value = combo;
    if (combo > runMaxCombo.value) runMaxCombo.value = combo;
    final multiplier = 1 + (combo - 1) * 0.5;
    var gained = (gemsCleared * 10 * multiplier).round();
    // Rhythm: ghép đúng nhịp → thưởng điểm theo groove (×1.5 .. ×2.5).
    if (isRhythm.value && _rhythmBonusPending) {
      final grooveMult = 1.5 + groove.value / GameController.kGrooveMax;
      gained = (gained * grooveMult).round();
      _rhythmBonusPending = false;
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
    // Endless: không có "win"; thua khi hết lượt. KHÔNG đụng win-streak/level.
    if (isEndless.value) {
      if (movesLeft.value <= 0) {
        _resolved = true;
        lastStars = 0;
        lastCoinReward = 0;
        lastStreakBonus = 0;
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
        lastCoinReward =
            40 +
            bossStage.value * 20 +
            lastStars * 10 +
            (2 + bossStage.value) * 10; // gộp shard cũ (2+stage) → xu
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
        lastCoinReward =
            20 +
            lastStars * 10 +
            groove.value * 3 +
            (1 + lastStars) * 10; // gộp shard cũ (1+sao) → xu
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
      lastCoinReward =
          10 + lastStars * 10 + lastStreakBonus; // 20/30/40 + bonus
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
      unawaited(_saveProgress(win: false));
      return 'lose';
    }
    return null;
  }
}

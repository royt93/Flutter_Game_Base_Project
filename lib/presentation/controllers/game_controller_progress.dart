part of 'game_controller.dart';

/// Lưu tiến trình màn thường (high score / sao / xu / unlock) + reset toàn bộ.
extension GameControllerProgress on GameController {
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
      // lastCoinReward đã được tính ĐỦ (gồm phần shard cũ (1+sao)×10) ngay trong
      // checkEnd (đồng bộ) → ở đây chỉ persist, KHÔNG cộng lại (tránh đếm 2 lần).
      // Ghi đĩa TRƯỚC rồi mới cập nhật state RAM: nếu app bị kill giữa chừng,
      // RAM và đĩa không lệch nhau (tránh mất xu/unlock đã hiển thị).
      final newCoins =
          (coins.value + lastCoinReward).clamp(0, GameController.maxCoins);
      final newEarned = (coinsEarnedTotal.value + lastCoinReward)
          .clamp(0, GameController.maxCoins);
      await _store.setInt(StorageKeys.coins, newCoins);
      await _store.setInt(StorageKeys.coinsEarned, newEarned);
      coins.value = newCoins;
      coinsEarnedTotal.value = newEarned;
      if (lv >= unlockedLevel.value && lv < kLevels.length) {
        final newUnlock = lv + 1;
        await _store.setInt(StorageKeys.unlockedLevel, newUnlock);
        unlockedLevel.value = newUnlock;
      }
    }
  }

  Future<void> resetProgress() async {
    dlog(
      'resetProgress START unlocked=${unlockedLevel.value} '
      'highScores=${highScores.length} stars=${stars.length} coins=${coins.value}',
    );

    // 1) Xoá MỌI key tiến trình trên đĩa (giữ lại cài đặt ngôn ngữ localeCode).
    //    Trước đây bỏ sót: coins, daily, wheel, lives, booster, tutorial,
    //    viewMode → "reset" nhưng xu/booster/mạng vẫn còn.
    final scalarKeys = <String>[
      StorageKeys.unlockedLevel,
      StorageKeys.coins,
      StorageKeys.shards,
      StorageKeys.dailyLastClaim,
      StorageKeys.dailyStreak,
      StorageKeys.maxDay,
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
      StorageKeys.survivalHigh,
      StorageKeys.sideModeDay,
      StorageKeys.sideModeWins,
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
      StorageKeys.upgHammer, // W18.3
      StorageKeys.upgMoves,
      StorageKeys.selectedSkin,
      StorageKeys.selectedTheme,
      StorageKeys.collectionPoints,
      StorageKeys.collectionSetClaimed, // W18.2
      StorageKeys.equippedTitle, // W18.2
      StorageKeys.piggySaved,
      StorageKeys.tournamentWeek,
      StorageKeys.tournamentPoints,
      StorageKeys.tournamentClaimedWeek,
      StorageKeys.leagueMigrated, // W18.1
    ];
    for (final k in scalarKeys) {
      await _store.remove(k);
    }
    for (final it in kCollectionItems) {
      await _store.remove(StorageKeys.collectionClaimed(it.id));
    }
    for (final s in kGemSkins) {
      await _store.remove(StorageKeys.ownedSkin(s.id));
    }
    for (final t in kBoardThemes) {
      await _store.remove(StorageKeys.ownedTheme(t.id));
    }
    for (final lv in kLevels) {
      await _store.remove(StorageKeys.highScore(lv.index));
      await _store.remove(StorageKeys.star(lv.index));
      await _store.remove(StorageKeys.pityFails(lv.index)); // Wave 16: reset pity
    }
    pity.value = 0;
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
    // W19.1 — xoá kỷ lục chế độ phụ (giá trị + bậc mốc + lượt chơi).
    for (final spec in kSideModeRecords) {
      await _store.remove(StorageKeys.recValue(spec.key));
      await _store.remove(StorageKeys.recTier(spec.key));
      await _store.remove(StorageKeys.recPlays(spec.key));
    }
    // W19.2 — xoá tiến trình Cấu đố (sao + mở khoá).
    for (final p in kPuzzles) {
      await _store.remove(StorageKeys.puzzleStars(p.id));
    }
    await _store.remove(StorageKeys.puzzleUnlocked);

    // 2) Xoá map in-memory rồi nạp lại GIÁ TRỊ MẶC ĐỊNH từ đĩa (đã trống) — đưa
    //    coins/booster/lives… về đúng như lần cài đầu thay vì giữ giá trị cũ.
    highScores.clear();
    stars.clear();
    _load();

    // 3) Reset state in-memory của các controller meta (permanent → không tự
    //    mất khi xoá đĩa). Bỏ bước này thì RAM giữ "đã nhận" → restart đọc đĩa
    //    trống ⇒ NHẬN LẠI thưởng Battle Pass / Season / Achievement / Temple.
    BattlePassController.maybe?.resetState();
    SeasonLeagueController.maybe?.resetState(); // W18.1 (gộp Mùa + Giải đấu)
    AchievementController.maybe?.resetState();
    TempleController.maybe?.resetState();
    CollectionController.maybe?.resetState();
    PiggyController.maybe?.resetState();
    SideModeRecordController.maybe?.resetState();
    PuzzleController.maybe?.resetState();

    dlog(
      'resetProgress DONE unlocked=${unlockedLevel.value} '
      'highScores=${highScores.length} stars=${stars.length} coins=${coins.value}',
    );
  }
}

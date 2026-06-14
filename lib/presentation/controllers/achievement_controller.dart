import 'dart:async';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
import '../../data/achievements.dart';
import 'game_controller.dart';

/// Theo dõi tiến trình thành tựu + cho nhận thưởng xu (offline).
class AchievementController extends GetxController {
  final GameController g;
  AchievementController(this.g);

  final StorageService _store = StorageService.to;

  /// id thành tựu đã nhận thưởng (reactive cho UI/badge).
  final RxSet<String> claimed = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    for (final a in kAchievements) {
      if (_store.getInt(StorageKeys.achievementClaimed(a.id)) == 1) {
        claimed.add(a.id);
      }
    }
  }

  /// Giá trị hiện tại của chỉ số thành tựu đang theo dõi.
  int currentValue(AchStat s) {
    switch (s) {
      case AchStat.totalWins:
        return g.totalWins.value;
      case AchStat.totalStars:
        return g.totalStars;
      case AchStat.bestCombo:
        return g.bestCombo.value;
      case AchStat.bestWinStreak:
        return g.bestWinStreak.value;
      case AchStat.unlockedLevel:
        return g.unlockedLevel.value;
      case AchStat.coinsEarned:
        return g.coinsEarnedTotal.value;
    }
  }

  bool isUnlocked(Achievement a) => currentValue(a.stat) >= a.threshold;
  bool isClaimed(Achievement a) => claimed.contains(a.id);
  bool canClaim(Achievement a) => isUnlocked(a) && !isClaimed(a);

  /// Có thành tựu nào đã đạt mà chưa nhận (cho badge Home)?
  bool get hasUnclaimed => kAchievements.any(canClaim);

  double progress(Achievement a) =>
      (currentValue(a.stat) / a.threshold).clamp(0.0, 1.0);

  /// Nhận thưởng. Trả về xu nhận (0 nếu không đủ điều kiện).
  int claim(Achievement a) {
    if (!canClaim(a)) return 0;
    // Ghi cờ "đã nhận" TRƯỚC khi cộng xu → chặn nhận thưởng 2 lần.
    claimed.add(a.id);
    unawaited(_store.setInt(StorageKeys.achievementClaimed(a.id), 1));
    g.addCoins(a.reward);
    return a.reward;
  }
}

import 'package:get/get.dart';

import '../../core/storage_service.dart';
import 'game_controller.dart';

/// Pure logic function check if Raid is active for a given epochDay (e.g. Fri, Sat, Sun).
bool isRaidActiveForEpochDay(int epochDay) {
  // Epoch day 0 was Thursday (1970-01-01).
  // (epochDay + 3) % 7 gives: 0: Mon, 1: Tue, 2: Wed, 3: Thu, 4: Fri, 5: Sat, 6: Sun
  final dayOfWeek = (epochDay + 3) % 7;
  return dayOfWeek >= 4; // Friday, Saturday, Sunday
}

/// Tier thưởng tổng sát thương cuối tuần.
class RaidRewardTier {
  const RaidRewardTier({
    required this.requiredDamage,
    required this.coinReward,
  });

  final int requiredDamage;
  final int coinReward;
}

const List<RaidRewardTier> kRaidRewardTiers = [
  RaidRewardTier(requiredDamage: 50, coinReward: 200),
  RaidRewardTier(requiredDamage: 150, coinReward: 500),
  RaidRewardTier(requiredDamage: 300, coinReward: 1200),
];

/// Controller cô lập cho Boss Raid Event (I61).
class RaidBossController extends GetxController {
  static const int maxDailyAttempts = 3;

  final attemptsRemaining = maxDailyAttempts.obs;
  final totalDamageThisEvent = 0.obs;
  final currentEventWeek = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _loadAndRollover();
  }

  int _todayEpochDay() => DateTime.now().millisecondsSinceEpoch ~/ 86400000;
  int _currentWeek() => _todayEpochDay() ~/ 7;

  void _loadAndRollover() {
    final today = _todayEpochDay();
    final week = _currentWeek();

    final savedWeek = StorageService.to.getInt(StorageKeys.raidBossEventWeek);
    if (savedWeek != week) {
      // Sang tuần mới -> reset damage & attempts
      totalDamageThisEvent.value = 0;
      currentEventWeek.value = week;
      StorageService.to.setInt(StorageKeys.raidBossEventWeek, week);
      StorageService.to.setInt(StorageKeys.raidBossTotalDamage, 0);
      StorageService.to.setInt(StorageKeys.raidBossAttemptsUsed, 0);
      StorageService.to.setInt(StorageKeys.raidBossLastAttemptDay, today);
      attemptsRemaining.value = maxDailyAttempts;
    } else {
      currentEventWeek.value = week;
      totalDamageThisEvent.value = StorageService.to.getInt(
        StorageKeys.raidBossTotalDamage,
      );

      final lastDay = StorageService.to.getInt(
        StorageKeys.raidBossLastAttemptDay,
      );
      if (lastDay != today) {
        // Sang ngày mới trong tuần -> reset 3 lượt/ngày
        StorageService.to.setInt(StorageKeys.raidBossLastAttemptDay, today);
        StorageService.to.setInt(StorageKeys.raidBossAttemptsUsed, 0);
        attemptsRemaining.value = maxDailyAttempts;
      } else {
        final used = StorageService.to.getInt(
          StorageKeys.raidBossAttemptsUsed,
        );
        attemptsRemaining.value = (maxDailyAttempts - used).clamp(0, maxDailyAttempts);
      }
    }
  }

  bool get isRaidActive => isRaidActiveForEpochDay(_todayEpochDay());

  bool canStartRaid() => isRaidActive && attemptsRemaining.value > 0;

  void consumeAttempt() {
    if (attemptsRemaining.value <= 0) return;
    attemptsRemaining.value--;
    final used = maxDailyAttempts - attemptsRemaining.value;
    StorageService.to.setInt(StorageKeys.raidBossAttemptsUsed, used);
  }

  void recordDamage(int damage) {
    if (damage <= 0) return;
    totalDamageThisEvent.value += damage;
    StorageService.to.setInt(
      StorageKeys.raidBossTotalDamage,
      totalDamageThisEvent.value,
    );
  }

  bool canClaimWeeklyReward() {
    final week = _currentWeek();
    final claimedWeek = StorageService.to.getInt(
      StorageKeys.raidBossRewardClaimedWeek,
    );
    if (claimedWeek == week) return false;
    return totalDamageThisEvent.value >= kRaidRewardTiers.first.requiredDamage;
  }

  int claimWeeklyReward(GameController gameCtrl) {
    if (!canClaimWeeklyReward()) return 0;
    final week = _currentWeek();
    StorageService.to.setInt(StorageKeys.raidBossRewardClaimedWeek, week);

    var totalCoins = 0;
    for (final tier in kRaidRewardTiers) {
      if (totalDamageThisEvent.value >= tier.requiredDamage) {
        totalCoins += tier.coinReward;
      }
    }

    if (totalCoins > 0) {
      gameCtrl.coins.value += totalCoins;
      StorageService.to.setInt(StorageKeys.coins, gameCtrl.coins.value);
    }
    return totalCoins;
  }
}

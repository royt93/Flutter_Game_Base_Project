import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

class LevelProgressionScreen extends StatefulWidget {
  const LevelProgressionScreen({super.key});

  @override
  State<LevelProgressionScreen> createState() => _LevelProgressionScreenState();
}

class _LevelProgressionScreenState extends State<LevelProgressionScreen> {
  static const _sfxVictory = 'audio/demo_sfx.mp3';

  late final EnergyService _energy;
  late final PlayerProgressionService _progression;
  late final OfflineProgressionService _offline;
  late final EconomyWallet _wallet;
  final _haptics = HapticChoreographer();

  String _status = 'Play stages to spend energy and earn XP + coins!';

  @override
  void initState() {
    super.initState();
    if (StorageService.maybe == null) {
      Get.put(StorageService(null), permanent: true);
    }
    _energy =
        EnergyService.maybe ??
        Get.put(
          EnergyService(
            maxEnergy: 5,
            refillInterval: const Duration(minutes: 10),
          ),
          permanent: true,
        );
    _progression =
        PlayerProgressionService.maybe ??
        Get.put(
          PlayerProgressionService(
            storage: StorageService.to,
            levelCurve: const [
              LevelDefinition(level: 1, xpToNext: 100),
              LevelDefinition(level: 2, xpToNext: 200),
              LevelDefinition(level: 3, xpToNext: 400),
              LevelDefinition(level: 4, xpToNext: 800),
              LevelDefinition(level: 5, xpToNext: 0),
            ],
          ),
          permanent: true,
        );
    _offline =
        OfflineProgressionService.maybe ??
        Get.put(OfflineProgressionService(), permanent: true);
    _wallet =
        EconomyWallet.maybe ??
        Get.put(EconomyWallet(storage: StorageService.to), permanent: true);
  }

  Future<void> _playStage() async {
    final success = _energy.consumeEnergy(1);
    if (!success) {
      _haptics.play(HapticPattern.error);
      if (!mounted) return;
      setState(() {
        _status = 'Not enough energy! Wait for refill or use infinite lives.';
      });
      return;
    }

    final prevLevel = _progression.snapshot.value.level;
    final xpResult = await _progression.grantXp(
      amount: 50,
      transactionId: 'stage_${DateTime.now().microsecondsSinceEpoch}',
    );
    await _wallet.earn(
      currency: 'coins',
      amount: 25,
      transactionId: 'stage_coin_${DateTime.now().microsecondsSinceEpoch}',
    );

    _haptics.play(HapticPattern.reward);
    AudioManager.maybe?.playSfx(_sfxVictory, duck: true);

    final currentLevel =
        xpResult.value?.level ?? _progression.snapshot.value.level;
    final levelUpMsg =
        currentLevel > prevLevel ? ' LEVEL UP to Lv.$currentLevel!' : '';

    if (!mounted) return;
    setState(() {
      _status = 'Stage cleared! +50 XP, +25 coins.$levelUpMsg';
    });
  }

  Future<void> _grantInfiniteEnergy() async {
    await _energy.grantInfiniteLives(const Duration(minutes: 15));
    _haptics.play(HapticPattern.reward);
    if (!mounted) return;
    setState(() {
      _status = 'Granted 15 minutes of infinite energy!';
    });
  }

  Future<void> _claimOfflineEarnings() async {
    final earned = await _offline.claim(2.0);
    final coins = earned.toInt();
    if (coins > 0) {
      await _wallet.earn(
        currency: 'coins',
        amount: coins,
        transactionId: 'offline_${DateTime.now().microsecondsSinceEpoch}',
      );
      _haptics.play(HapticPattern.reward);
      if (!mounted) return;
      setState(() {
        _status = 'Claimed $coins offline coins!';
      });
    } else {
      if (!mounted) return;
      setState(() {
        _status = 'No offline earnings accumulated yet (rate: 2 coins/sec).';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'level_progression'.tr, onBack: Get.back),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NeonTheme.s16,
                  vertical: NeonTheme.s8,
                ),
                child: PanelCard(
                  child: Text(_status, style: TextStyle(color: NeonTheme.ink)),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NeonTheme.s16,
                    vertical: NeonTheme.s8,
                  ),
                  children: [
                    // Energy section
                    PanelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Energy & Lives',
                            style: TextStyle(
                              color: NeonTheme.ink,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          EnergyBar(
                            currentEnergy: _energy.currentEnergy,
                            maxEnergy: _energy.maxEnergy,
                            timeUntilNextEnergy: _energy.timeUntilNextEnergy,
                            hasInfiniteLives: _energy.hasInfiniteLives,
                            direction: Axis.horizontal,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: CommonButton(
                                  label: 'Play Stage (-1 Energy)',
                                  onTap: _playStage,
                                ),
                              ),
                              const SizedBox(width: NeonTheme.s8),
                              Expanded(
                                child: CommonButton(
                                  label: 'Infinite Lives',
                                  variant: CommonButtonVariant.secondary,
                                  onTap: _grantInfiniteEnergy,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: NeonTheme.s16),
                    // Progression section
                    Obx(() {
                      final snap = _progression.snapshot.value;
                      final progress =
                          snap.isMaxLevel
                              ? 1.0
                              : (snap.xpIntoLevel / snap.xpToNextLevel).clamp(
                                0.0,
                                1.0,
                              );
                      final coins = _wallet.balanceOf('coins');
                      return PanelCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Level ${snap.level}',
                                  style: TextStyle(
                                    color: NeonTheme.ink,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  'Coins: $coins',
                                  style: TextStyle(
                                    color: NeonTheme.gold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: NeonTheme.s8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 12,
                                backgroundColor: NeonTheme.cardAlt,
                                valueColor: AlwaysStoppedAnimation(
                                  NeonTheme.lime,
                                ),
                              ),
                            ),
                            const SizedBox(height: NeonTheme.s8),
                            Text(
                              snap.isMaxLevel
                                  ? 'Max Level Reached!'
                                  : 'XP: ${snap.xpIntoLevel} / ${snap.xpToNextLevel} (Total XP: ${snap.totalXpEarned})',
                              style: TextStyle(
                                color: NeonTheme.inkSoft,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: NeonTheme.s16),
                    // Offline earnings section
                    PanelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Idle Offline Production',
                            style: TextStyle(
                              color: NeonTheme.ink,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: NeonTheme.s8),
                          Text(
                            'Production rate: 2.0 coins/sec\nCap: 8 hours maximum away time.',
                            style: TextStyle(color: NeonTheme.inkSoft),
                          ),
                          const SizedBox(height: 12),
                          CommonButton(
                            label: 'Claim Offline Earnings',
                            onTap: _claimOfflineEarnings,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

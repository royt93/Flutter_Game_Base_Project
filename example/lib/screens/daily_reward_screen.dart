import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:roy_casual_kit/roy_casual_kit.dart';

class DailyRewardScreen extends StatefulWidget {
  const DailyRewardScreen({super.key});

  @override
  State<DailyRewardScreen> createState() => _DailyRewardScreenState();
}

class _DailyRewardScreenState extends State<DailyRewardScreen> {
  static const _questId = 'daily_reward_tap_3';
  static const _questTarget = 3;
  static const _loginRewardCoins = 50;
  static const _questRewardGems = 5;

  late final DailyLoginService _dailyLogin;
  late final DailyQuestService _quests;
  late final EconomyWallet _wallet;
  String _status = 'Claim today reward or finish quest.';

  @override
  void initState() {
    super.initState();
    if (StorageService.maybe == null) {
      Get.put(StorageService(null), permanent: true);
    }
    _dailyLogin =
        DailyLoginService.maybe ??
        Get.put(DailyLoginService(), permanent: true);
    _quests =
        DailyQuestService.maybe ??
        Get.put(DailyQuestService(), permanent: true);
    _wallet =
        EconomyWallet.maybe ??
        Get.put(EconomyWallet(storage: StorageService.to), permanent: true);
    _quests.register(_questId, _questTarget);
  }

  Future<void> _claimLoginReward() async {
    if (!_dailyLogin.canClaimToday()) return;
    final result = _dailyLogin.claimToday();
    final walletResult = await _wallet.earn(
      currency: 'coins',
      amount: _loginRewardCoins,
      transactionId: 'daily_login_${todayEpochDayClamped()}',
    );
    if (!mounted) return;
    setState(() {
      _status = walletResult.isSuccess
          ? 'Day ${result.streakDay} claimed: +$_loginRewardCoins coins.'
          : 'Reward save failed.';
    });
  }

  void _playQuestStep() {
    if (_quests.isClaimed(_questId)) return;
    _quests.incrementProgress(_questId, 1);
    setState(() {
      _status = _quests.isCompleted(_questId)
          ? 'Quest complete. Claim +$_questRewardGems gems.'
          : 'Quest progress: ${_quests.progressOf(_questId)}/$_questTarget.';
    });
  }

  Future<void> _claimQuest(String questId) async {
    if (!_quests.claim(questId)) return;
    final result = await _wallet.earn(
      currency: 'gems',
      amount: _questRewardGems,
      transactionId: 'daily_quest_$questId',
    );
    if (!mounted) return;
    setState(() {
      _status = result.isSuccess
          ? 'Quest reward claimed: +$_questRewardGems gems.'
          : 'Quest reward save failed.';
    });
  }

  List<QuestViewModel> get _questRows => [
    QuestViewModel(
      id: _questId,
      label: 'Tap training x$_questTarget',
      progress: _quests.progressOf(_questId),
      target: _questTarget,
      claimed: _quests.isClaimed(_questId),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'Daily Rewards', onBack: Get.back),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(NeonTheme.s16),
                  children: [
                    PanelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Wallet: coins ${_wallet.balanceOf('coins')} | gems ${_wallet.balanceOf('gems')}',
                            style: TextStyle(
                              color: NeonTheme.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: NeonTheme.s8),
                          Text(
                            _status,
                            style: TextStyle(color: NeonTheme.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: NeonTheme.s16),
                    PanelCard(
                      child: DailyLoginCalendarWidget(
                        currentStreakDay: _dailyLogin.currentStreakDay,
                        claimedDaysInCycle: _dailyLogin.claimedDaysInCycle,
                        canClaimToday: _dailyLogin.canClaimToday(),
                        claimLabel: 'Claim +$_loginRewardCoins coins',
                        onClaim: _claimLoginReward,
                      ),
                    ),
                    const SizedBox(height: NeonTheme.s16),
                    PanelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CommonButton(
                            label: 'Play training tap',
                            variant: CommonButtonVariant.secondary,
                            onTap: _quests.isClaimed(_questId)
                                ? null
                                : _playQuestStep,
                          ),
                          const SizedBox(height: NeonTheme.s16),
                          QuestBoardPanel(
                            quests: _questRows,
                            claimLabel: 'Claim +$_questRewardGems gems',
                            onClaim: _claimQuest,
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

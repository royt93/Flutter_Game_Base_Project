import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/clan_engine.dart';
import '../../core/neon_theme.dart';
import '../controllers/clan_controller.dart';
import '../controllers/game_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';

/// Clan/Friends offline (Wave 23) — bảng đóng góp tuần + mục tiêu + thưởng.
class ClanScreen extends StatelessWidget {
  const ClanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = Get.find<GameController>();
    final cl = Get.isRegistered<ClanController>()
        ? Get.find<ClanController>()
        : Get.put(ClanController(g));
    const accent = NeonTheme.cyan;
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'clan_title'.tr,
                color: accent,
                actions: [CoinChip(g)],
              ),
              Expanded(
                child: Obx(() {
                  cl.contributionRx.value;
                  cl.rewardWeekRx.value;
                  final roster = cl.roster();
                  final total = clanTotal(roster);
                  return ListView(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    children: [
                      _goalCard(cl, total, accent),
                      const SizedBox(height: NeonTheme.s8),
                      for (var i = 0; i < roster.length; i++)
                        _row(i + 1, roster[i], accent),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _goalCard(ClanController cl, int total, Color accent) {
    final ratio = (total / kClanWeeklyGoal).clamp(0.0, 1.0);
    final claimable = cl.weeklyRewardClaimable;
    final claimed = cl.weeklyRewardClaimed;
    return Container(
      padding: const EdgeInsets.all(NeonTheme.s16),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'clan_goal'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '$total / $kClanWeeklyGoal',
                style: TextStyle(color: accent, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: 12),
          if (claimed)
            Text(
              'daily_claimed'.tr,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            )
          else if (claimable)
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: cl.claimWeeklyReward,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: NeonTheme.lime.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: NeonTheme.lime, width: 1.4),
                  ),
                  child: Text(
                    '${'daily_claim'.tr} +$kClanWeeklyReward',
                    style: const TextStyle(
                      color: NeonTheme.lime,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(int rank, ClanMember m, Color accent) {
    final color = m.isPlayer ? accent : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: NeonTheme.s8),
      padding: const EdgeInsets.symmetric(
        horizontal: NeonTheme.s16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: m.isPlayer
            ? accent.withValues(alpha: 0.16)
            : NeonTheme.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: m.isPlayer ? accent : Colors.white12,
          width: m.isPlayer ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$rank',
              style: TextStyle(
                color: rank <= 3 ? accent : Colors.white54,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              m.isPlayer ? 'lb_player'.tr : m.name,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '${m.contribution}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

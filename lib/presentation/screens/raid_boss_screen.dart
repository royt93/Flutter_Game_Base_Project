import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../controllers/game_controller.dart';
import '../controllers/raid_boss_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_button.dart';
import '../widgets/neon_icon.dart';
import '../widgets/stroke_text.dart';

/// I61: Màn hình Boss Breakout Raid Event.
class RaidBossScreen extends StatelessWidget {
  const RaidBossScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final raidCtrl = Get.put(RaidBossController());
    final gameCtrl = Get.find<GameController>();

    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'raid_boss_title'.tr,
                color: NeonTheme.red,
                actions: [CoinChip(gameCtrl)],
              ),
              Expanded(
                child: Obx(() {
                  final isActive = raidCtrl.isRaidActive;
                  final attempts = raidCtrl.attemptsRemaining.value;
                  final damage = raidCtrl.totalDamageThisEvent.value;

                  return ListView(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(NeonTheme.s16),
                        decoration: BoxDecoration(
                          color: NeonTheme.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: NeonTheme.red.withValues(alpha: 0.4),
                          ),
                          boxShadow: NeonTheme.glow(NeonTheme.red),
                        ),
                        child: Column(
                          children: [
                            const NeonIcon(
                              Icons.whatshot_rounded,
                              color: NeonTheme.red,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            StrokeText(
                              'raid_boss_name'.tr,
                              fontSize: 22,
                              color: NeonTheme.red,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isActive
                                  ? 'raid_boss_event_active'.tr
                                  : 'raid_boss_event_inactive'.tr,
                              style: TextStyle(
                                color: isActive ? NeonTheme.teal : NeonTheme.inkSoft,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(NeonTheme.s16),
                        decoration: BoxDecoration(
                          color: NeonTheme.card,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  'raid_boss_attempts_left'.tr,
                                  style: TextStyle(
                                    color: NeonTheme.inkSoft,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$attempts / ${RaidBossController.maxDailyAttempts}',
                                  style: TextStyle(
                                    color: NeonTheme.ink,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  'raid_boss_total_damage'.tr,
                                  style: TextStyle(
                                    color: NeonTheme.inkSoft,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  fmtNum(damage),
                                  style: const TextStyle(
                                    color: NeonTheme.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(NeonTheme.s16),
                        decoration: BoxDecoration(
                          color: NeonTheme.card,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'raid_boss_reward_tiers'.tr,
                              style: TextStyle(
                                color: NeonTheme.ink,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            for (final tier in kRaidRewardTiers) ...[
                              Row(
                                children: [
                                  Icon(
                                    damage >= tier.requiredDamage
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: damage >= tier.requiredDamage
                                        ? NeonTheme.teal
                                        : NeonTheme.inkSoft,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'raid_boss_tier_req'.trParams({
                                        'dmg': '${tier.requiredDamage}',
                                      }),
                                      style: TextStyle(
                                        color: NeonTheme.ink,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    // X31: 21/22 ngôn ngữ từng thấy chữ "xu"
                                    // tiếng Việt ở đây. `coins_short` đã có
                                    // sẵn đủ 22 locale nên không cần key mới.
                                    '${tier.coinReward} ${'coins_short'.tr}',
                                    style: const TextStyle(
                                      color: NeonTheme.gold,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              if (tier != kRaidRewardTiers.last)
                                const Divider(height: 16),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (raidCtrl.canClaimWeeklyReward())
                        NeonButton(
                          label: 'raid_boss_claim_reward'.tr,
                          color: NeonTheme.gold,
                          onTap: () {
                            final claimed = raidCtrl.claimWeeklyReward(gameCtrl);
                            if (claimed > 0) {
                              Get.snackbar(
                                'raid_boss_title'.tr,
                                '+$claimed ${'coins_short'.tr}',
                              );
                            }
                          },
                        ),
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
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../controllers/game_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/coin_fly_overlay.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/pressable_scale.dart';

/// I6: mùa 28 ngày (free-track only), điểm mùa cộng khi thắng level campaign,
/// đạt mốc → nhận coin/booster. UI tái dùng cấu trúc F7 Star Road.
class SeasonScreen extends StatefulWidget {
  const SeasonScreen({super.key});

  @override
  State<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends State<SeasonScreen> {
  final _flying = <int>{};

  @override
  Widget build(BuildContext context) {
    final gameCtrl = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'Season Pass',
                color: NeonTheme.magenta,
                actions: [CoinChip(gameCtrl)],
              ),
              Expanded(
                child: Obx(
                  () => Stack(
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(NeonTheme.s16),
                        children: [
                          for (
                            var i = 0;
                            i < GameController.seasonMilestones.length;
                            i++
                          ) ...[
                            if (i > 0) const SizedBox(height: NeonTheme.s16),
                            _SeasonRow(
                              milestone: GameController.seasonMilestones[i],
                              reward: GameController.seasonRewards[i],
                              seasonPoints: gameCtrl.seasonPoints.value,
                              claimed: gameCtrl.isSeasonClaimed(i),
                              canClaim: gameCtrl.canClaimSeason(i),
                              onClaim: () {
                                if (gameCtrl.claimSeason(i)) {
                                  setState(() => _flying.add(i));
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                      for (final i in _flying)
                        CoinFlyOverlay(
                          key: ValueKey('season-fly-$i'),
                          onDone: () => setState(() => _flying.remove(i)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _rewardLabel(SpinReward reward) {
  switch (reward.type) {
    case 'bomb':
      return '${reward.amount}x bomb';
    case 'shuffle':
      return '${reward.amount}x shuffle';
    case 'undo':
      return '${reward.amount}x undo';
    default:
      return '${fmtNum(reward.amount)} coins';
  }
}

class _SeasonRow extends StatelessWidget {
  final int milestone;
  final SpinReward reward;
  final int seasonPoints;
  final bool claimed;
  final bool canClaim;
  final VoidCallback onClaim;

  const _SeasonRow({
    required this.milestone,
    required this.reward,
    required this.seasonPoints,
    required this.claimed,
    required this.canClaim,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final locked = seasonPoints < milestone && !claimed;
    final color = claimed
        ? NeonTheme.inkSoft
        : (canClaim ? NeonTheme.magenta : NeonTheme.purple);
    return Container(
      padding: const EdgeInsets.all(NeonTheme.s16),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2.5),
        boxShadow: NeonTheme.drop(),
      ),
      child: Row(
        children: [
          Icon(
            claimed
                ? Icons.check_circle_rounded
                : (locked ? Icons.lock_rounded : Icons.military_tech_rounded),
            color: color,
            size: 32,
          ),
          const SizedBox(width: NeonTheme.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$milestone points',
                  style: TextStyle(
                    color: NeonTheme.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: NeonTheme.s8),
                Text(
                  claimed
                      ? 'Claimed'
                      : '$seasonPoints / $milestone · reward ${_rewardLabel(reward)}',
                  style: TextStyle(
                    color: NeonTheme.inkSoft,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!claimed)
            PressableScale(
              onTap: canClaim ? onClaim : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: NeonTheme.s16,
                  vertical: NeonTheme.s8,
                ),
                decoration: BoxDecoration(
                  color: canClaim ? NeonTheme.magenta : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: canClaim ? NeonTheme.magenta : Colors.grey,
                    width: 2,
                  ),
                ),
                child: Text(
                  'CLAIM',
                  style: TextStyle(
                    color: canClaim ? Colors.white : NeonTheme.inkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

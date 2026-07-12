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

/// F7: tổng sao mọi màn đổ vào 1 "đường sao", đạt mốc → mở rương xu.
class StarRoadScreen extends StatefulWidget {
  const StarRoadScreen({super.key});

  @override
  State<StarRoadScreen> createState() => _StarRoadScreenState();
}

class _StarRoadScreenState extends State<StarRoadScreen> {
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
                title: 'Star Road',
                color: NeonTheme.gold,
                actions: [CoinChip(gameCtrl)],
              ),
              Expanded(
                child: Obx(
                  () => Stack(
                    children: [
                      ListView.separated(
                        padding: const EdgeInsets.all(NeonTheme.s16),
                        itemCount: GameController.starRoadMilestones.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: NeonTheme.s16),
                        itemBuilder: (context, i) => _ChestRow(
                          milestone: GameController.starRoadMilestones[i],
                          reward: GameController.starRoadRewards[i],
                          totalStars: gameCtrl.totalStars.value,
                          claimed: gameCtrl.isChestClaimed(i),
                          canClaim: gameCtrl.canClaimChest(i),
                          onClaim: () {
                            if (gameCtrl.claimChest(i)) {
                              setState(() => _flying.add(i));
                            }
                          },
                        ),
                      ),
                      for (final i in _flying)
                        CoinFlyOverlay(
                          key: ValueKey('chest-fly-$i'),
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

class _ChestRow extends StatelessWidget {
  final int milestone;
  final int reward;
  final int totalStars;
  final bool claimed;
  final bool canClaim;
  final VoidCallback onClaim;

  const _ChestRow({
    required this.milestone,
    required this.reward,
    required this.totalStars,
    required this.claimed,
    required this.canClaim,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final locked = totalStars < milestone && !claimed;
    final color = claimed
        ? NeonTheme.inkSoft
        : (canClaim ? NeonTheme.gold : NeonTheme.purple);
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
                : (locked ? Icons.lock_rounded : Icons.card_giftcard_rounded),
            color: color,
            size: 32,
          ),
          const SizedBox(width: NeonTheme.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$milestone stars',
                  style: const TextStyle(
                    color: NeonTheme.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  claimed
                      ? 'Claimed'
                      : '$totalStars / $milestone · reward ${fmtNum(reward)} coins',
                  style: const TextStyle(
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
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: canClaim ? NeonTheme.gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: canClaim ? NeonTheme.gold : Colors.grey,
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

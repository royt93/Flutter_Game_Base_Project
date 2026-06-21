import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/neon_theme.dart';
import 'package:neon_jewels/core/utils/format.dart';
import 'package:neon_jewels/data/challenge_cards.dart';
import 'package:neon_jewels/presentation/controllers/challenge_card_controller.dart';
import 'package:neon_jewels/presentation/widgets/neon_app_bar.dart';
import 'package:neon_jewels/presentation/widgets/neon_bg.dart';

/// Wave 20.3 — Màn Challenge Card (thử thách tuần).
class ChallengeCardScreen extends StatelessWidget {
  const ChallengeCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ChallengeCardController>();
    return Scaffold(
      backgroundColor: NeonTheme.bgDark,
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'cc_title'.tr),
              Expanded(
                child: Obx(() {
                  // M2 fix: đọc progress (RxList) để Obx rebuild khi week reset
                  ctrl.progress.length;
                  ctrl.claimed.length;
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: 3,
                    separatorBuilder: (context2, idx) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final card = ctrl.challenges[i];
                      final prog = ctrl.progress[i];
                      final done = prog >= card.target;
                      final isClaimed = ctrl.claimed[i];
                      return _ChallengeCardTile(
                        card: card,
                        progress: prog,
                        done: done,
                        claimed: isClaimed,
                        onClaim: () => ctrl.claimReward(i),
                      );
                    },
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

class _ChallengeCardTile extends StatelessWidget {
  final ChallengeCard card;
  final int progress;
  final bool done;
  final bool claimed;
  final VoidCallback onClaim;
  const _ChallengeCardTile({
    required this.card,
    required this.progress,
    required this.done,
    required this.claimed,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final color = claimed
        ? Colors.white24
        : done
            ? NeonTheme.lime
            : NeonTheme.cyan;
    final progressFrac = (progress / card.target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NeonTheme.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: claimed ? Colors.white12 : color.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: (!claimed && done)
            ? NeonTheme.glow(NeonTheme.lime, blur: 12)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconFor(card.type), color: color, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _titleFor(card),
                  style: TextStyle(
                    color: claimed ? Colors.white38 : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (done && !claimed)
                ElevatedButton(
                  onPressed: onClaim,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NeonTheme.lime,
                    foregroundColor: NeonTheme.bgDark,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('cc_claim'.tr),
                )
              else if (claimed)
                const Icon(Icons.check_circle_rounded,
                    color: NeonTheme.lime, size: 22),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressFrac,
              backgroundColor: Colors.white12,
              color: color,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$progress / ${card.target}',
                style: TextStyle(
                    color: claimed ? Colors.white24 : Colors.white54,
                    fontSize: 11),
              ),
              Text(
                '💰 +${fmtNum(card.reward)} ${'coins'.tr}',
                style: TextStyle(
                    color: claimed ? Colors.white24 : color, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(ChallengeType type) {
    switch (type) {
      case ChallengeType.winCampaign:
        return Icons.emoji_events_rounded;
      case ChallengeType.earnCoins:
        return Icons.monetization_on_rounded;
      case ChallengeType.playMode:
        return Icons.sports_esports_rounded;
    }
  }

  String _titleFor(ChallengeCard card) {
    switch (card.type) {
      case ChallengeType.winCampaign:
        return 'cc_win_campaign'.tr.replaceFirst('@n', card.target.toString());
      case ChallengeType.earnCoins:
        return 'cc_earn_coins'.tr
            .replaceFirst('@n', fmtNum(card.target));
      case ChallengeType.playMode:
        return 'cc_play_mode'.tr
            .replaceFirst('@n', card.target.toString())
            .replaceFirst('@m', card.modeKey.tr);
    }
  }
}

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'milestone_celebration_dialog.dart' show MilestoneReward;

/// A tier on a horizontal XP reward track (FEAT-150).
@immutable
class RewardTrackTier {
  const RewardTrackTier({
    required this.id,
    required this.requiredXp,
    required this.freeReward,
    this.premiumReward,
  });

  final String id;
  final int requiredXp;
  final MilestoneReward freeReward;
  final MilestoneReward? premiumReward;
}

enum RewardTrackLane { free, premium }

enum RewardTrackClaimState { locked, claimable, claimed }

RewardTrackClaimState rewardTrackClaimState({
  required RewardTrackTier tier,
  required int currentXp,
  required bool premiumEnabled,
  required Set<String> claimedFreeIds,
  required Set<String> claimedPremiumIds,
  required RewardTrackLane lane,
}) {
  if (lane == RewardTrackLane.premium &&
      (!premiumEnabled || tier.premiumReward == null)) {
    return RewardTrackClaimState.locked;
  }
  final claimId = '${tier.id}:${lane.name}';
  final claimed = lane == RewardTrackLane.free
      ? claimedFreeIds.contains(claimId)
      : claimedPremiumIds.contains(claimId);
  if (claimed) return RewardTrackClaimState.claimed;
  return currentXp >= tier.requiredXp
      ? RewardTrackClaimState.claimable
      : RewardTrackClaimState.locked;
}

/// Horizontally scrollable XP reward track with free and optional premium lanes.
///
/// XP, premium ownership, claimed IDs, and reward grants remain caller-owned.
class RewardTrackRoad extends StatelessWidget {
  RewardTrackRoad({
    super.key,
    required this.tiers,
    required this.currentXp,
    required this.onClaim,
    this.premiumEnabled = false,
    this.claimedFreeIds = const {},
    this.claimedPremiumIds = const {},
    this.title = 'Reward Track',
    this.premiumLabel = 'PREMIUM',
    this.freeLabel = 'FREE',
    this.semanticLabel,
  }) {
    if (currentXp < 0) {
      throw ArgumentError.value(currentXp, 'currentXp', 'must be non-negative');
    }
    if (title.trim().isEmpty ||
        premiumLabel.trim().isEmpty ||
        freeLabel.trim().isEmpty) {
      throw ArgumentError('title and lane labels must not be empty');
    }
    final ids = <String>{};
    var previousXp = -1;
    for (final tier in tiers) {
      if (tier.id.trim().isEmpty) {
        throw ArgumentError.value(tier.id, 'tier.id', 'must not be empty');
      }
      if (!ids.add(tier.id)) {
        throw ArgumentError.value(
          tier.id,
          'tiers',
          'duplicate tier id: ${tier.id}',
        );
      }
      if (tier.requiredXp < 0 || tier.requiredXp <= previousXp) {
        throw ArgumentError.value(
          tier.requiredXp,
          'tier.requiredXp',
          'must be non-negative and strictly increasing',
        );
      }
      previousXp = tier.requiredXp;
    }
  }

  final List<RewardTrackTier> tiers;
  final int currentXp;
  final bool premiumEnabled;
  final Set<String> claimedFreeIds;
  final Set<String> claimedPremiumIds;
  final void Function(String tierId, RewardTrackLane lane) onClaim;
  final String title;
  final String premiumLabel;
  final String freeLabel;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final semantics =
        semanticLabel ??
        '$title. $currentXp XP. ${tiers.length} reward tiers. Premium ${premiumEnabled ? "unlocked" : "locked"}.';
    return Semantics(
      key: const ValueKey('rewardTrackSemantics'),
      container: true,
      label: semantics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: NeonTheme.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$currentXp XP',
                style: TextStyle(
                  color: NeonTheme.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: NeonTheme.s8),
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(230),
            child: ListView.builder(
              key: const ValueKey('rewardTrackScroll'),
              scrollDirection: Axis.horizontal,
              itemCount: tiers.length,
              itemBuilder: (context, index) {
                final tier = tiers[index];
                return _TierColumn(
                  key: ValueKey('rewardTrackTier_${tier.id}'),
                  tier: tier,
                  currentXp: currentXp,
                  premiumEnabled: premiumEnabled,
                  claimedFreeIds: claimedFreeIds,
                  claimedPremiumIds: claimedPremiumIds,
                  freeLabel: freeLabel,
                  premiumLabel: premiumLabel,
                  onClaim: onClaim,
                  isLast: index == tiers.length - 1,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TierColumn extends StatelessWidget {
  const _TierColumn({
    super.key,
    required this.tier,
    required this.currentXp,
    required this.premiumEnabled,
    required this.claimedFreeIds,
    required this.claimedPremiumIds,
    required this.freeLabel,
    required this.premiumLabel,
    required this.onClaim,
    required this.isLast,
  });

  final RewardTrackTier tier;
  final int currentXp;
  final bool premiumEnabled;
  final Set<String> claimedFreeIds;
  final Set<String> claimedPremiumIds;
  final String freeLabel;
  final String premiumLabel;
  final void Function(String tierId, RewardTrackLane lane) onClaim;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final reached = currentXp >= tier.requiredXp;
    return SizedBox(
      width: 148,
      child: Column(
        children: [
          SizedBox(
            height: 26,
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: reached ? NeonTheme.cyan : NeonTheme.cardAlt,
                    border: Border.all(
                      color: reached ? NeonTheme.cyan : NeonTheme.muted,
                    ),
                  ),
                  child: Icon(
                    reached ? Icons.check_rounded : Icons.lock_rounded,
                    size: 14,
                    color: reached ? Colors.white : NeonTheme.inkSoft,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      height: 3,
                      color: reached ? NeonTheme.cyan : NeonTheme.muted,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${tier.requiredXp} XP',
            style: TextStyle(
              color: reached ? NeonTheme.cyan : NeonTheme.inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _RewardCell(
                    tierId: tier.id,
                    label: freeLabel,
                    reward: tier.freeReward,
                    status: rewardTrackClaimState(
                      tier: tier,
                      currentXp: currentXp,
                      premiumEnabled: premiumEnabled,
                      claimedFreeIds: claimedFreeIds,
                      claimedPremiumIds: claimedPremiumIds,
                      lane: RewardTrackLane.free,
                    ),
                    lane: RewardTrackLane.free,
                    onClaim: () => onClaim(tier.id, RewardTrackLane.free),
                  ),
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: _RewardCell(
                    tierId: tier.id,
                    label: premiumLabel,
                    reward: tier.premiumReward,
                    status: rewardTrackClaimState(
                      tier: tier,
                      currentXp: currentXp,
                      premiumEnabled: premiumEnabled,
                      claimedFreeIds: claimedFreeIds,
                      claimedPremiumIds: claimedPremiumIds,
                      lane: RewardTrackLane.premium,
                    ),
                    lane: RewardTrackLane.premium,
                    onClaim: () => onClaim(tier.id, RewardTrackLane.premium),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardCell extends StatelessWidget {
  const _RewardCell({
    required this.tierId,
    required this.label,
    required this.reward,
    required this.status,
    required this.lane,
    required this.onClaim,
  });

  final String tierId;
  final String label;
  final MilestoneReward? reward;
  final RewardTrackClaimState status;
  final RewardTrackLane lane;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final locked = status == RewardTrackClaimState.locked;
    final claimed = status == RewardTrackClaimState.claimed;
    final color = lane == RewardTrackLane.free
        ? NeonTheme.cyan
        : NeonTheme.gold;
    final title = reward?.label ?? 'No reward';
    final amount = reward?.amountLabel;
    return Container(
      key: ValueKey('rewardTrackCell_${lane.name}_${title}_$status'),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: locked ? NeonTheme.cardAlt : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: locked ? 0.2 : 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Icon(
                  locked
                      ? Icons.lock_rounded
                      : (reward?.icon ?? Icons.card_giftcard),
                  size: 18,
                  color: locked ? NeonTheme.inkSoft : color,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    locked ? 'Locked' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: NeonTheme.ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (amount != null && !locked)
            Text(
              amount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          if (status == RewardTrackClaimState.claimable)
            GestureDetector(
              key: ValueKey('rewardTrackClaim_${tierId}_${lane.name}_$title'),
              onTap: onClaim,
              child: Text(
                'Claim',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          if (claimed)
            Text(
              'Claimed',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: NeonTheme.inkSoft,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

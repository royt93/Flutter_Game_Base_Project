import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'milestone_celebration_dialog.dart' show MilestoneReward;

/// Presentation-only return-player offer with caller-supplied rewards and
/// eligibility/expiry state (FEAT-151).
class ComebackBundleCard extends StatelessWidget {
  ComebackBundleCard({
    super.key,
    required this.title,
    required this.body,
    required this.absenceLabel,
    required this.rewards,
    required this.onClaim,
    this.expiryLabel,
    this.isExpired = false,
    this.badgeLabel,
    this.claimLabel = 'Claim Bundle',
    this.onViewOffer,
    this.viewOfferLabel = 'View Offer',
    this.semanticLabel,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (body.trim().isEmpty) {
      throw ArgumentError.value(body, 'body', 'must not be empty');
    }
    if (absenceLabel.trim().isEmpty) {
      throw ArgumentError.value(
        absenceLabel,
        'absenceLabel',
        'must not be empty',
      );
    }
    if (claimLabel.trim().isEmpty || viewOfferLabel.trim().isEmpty) {
      throw ArgumentError('action labels must not be empty');
    }
    for (final reward in rewards) {
      if (reward.label.trim().isEmpty) {
        throw ArgumentError.value(
          reward.label,
          'rewards',
          'label must not be empty',
        );
      }
      if (reward.amountLabel != null && reward.amountLabel!.trim().isEmpty) {
        throw ArgumentError.value(
          reward.amountLabel,
          'rewards',
          'amountLabel must not be empty when provided',
        );
      }
    }
  }

  final String title;
  final String body;
  final String absenceLabel;
  final List<MilestoneReward> rewards;
  final VoidCallback onClaim;
  final String? expiryLabel;
  final bool isExpired;
  final String? badgeLabel;
  final String claimLabel;
  final VoidCallback? onViewOffer;
  final String viewOfferLabel;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final label =
        semanticLabel ??
        '$title. Welcome back after $absenceLabel. $body. ${rewards.length} rewards.'
            '${expiryLabel == null ? "" : " $expiryLabel."}'
            '${isExpired ? " Expired." : ""}';
    final accent = isExpired ? NeonTheme.muted : NeonTheme.gold;

    return Semantics(
      key: const ValueKey('comebackBundleSemantics'),
      container: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.all(NeonTheme.s16),
        decoration: BoxDecoration(
          color: NeonTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.55), width: 2),
          boxShadow: [
            ...NeonTheme.glow(accent, blur: 12, intensity: 0.2),
            ...NeonTheme.drop(y: 4, blur: 12),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 5,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: NeonTheme.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (badgeLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      badgeLabel!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Welcome back after $absenceLabel',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: NeonTheme.s8),
            Text(
              body,
              style: TextStyle(
                color: NeonTheme.inkSoft,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (rewards.isNotEmpty) ...[
              const SizedBox(height: NeonTheme.s8),
              Wrap(
                spacing: NeonTheme.s8,
                runSpacing: 6,
                children: rewards.map(_rewardChip).toList(),
              ),
            ],
            if (expiryLabel != null) ...[
              const SizedBox(height: NeonTheme.s8),
              Text(
                isExpired ? 'Expired' : expiryLabel!,
                key: const ValueKey('comebackBundleExpiryLabel'),
                style: TextStyle(
                  color: isExpired ? NeonTheme.red : NeonTheme.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            const SizedBox(height: NeonTheme.s16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: NeonTheme.s8,
              runSpacing: 8,
              children: [
                if (onViewOffer != null)
                  CommonButton(
                    key: const ValueKey('comebackBundleViewBtn'),
                    label: viewOfferLabel,
                    width: 120,
                    variant: CommonButtonVariant.secondary,
                    color: accent,
                    onTap: isExpired ? null : onViewOffer,
                  ),
                CommonButton(
                  key: const ValueKey('comebackBundleClaimBtn'),
                  label: isExpired ? 'Expired' : claimLabel,
                  width: 140,
                  color: accent,
                  onTap: isExpired ? null : onClaim,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rewardChip(MilestoneReward reward) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: (reward.color ?? NeonTheme.gold).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: (reward.color ?? NeonTheme.gold).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(reward.icon, size: 16, color: reward.color ?? NeonTheme.gold),
          const SizedBox(width: 4),
          Text(
            reward.amountLabel == null
                ? reward.label
                : '${reward.label} ${reward.amountLabel}',
            style: TextStyle(
              color: NeonTheme.ink,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

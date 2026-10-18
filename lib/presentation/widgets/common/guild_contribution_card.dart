import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/utils/format.dart';
import 'milestone_celebration_dialog.dart' show MilestoneReward;
import 'common_button.dart';

/// One community contribution milestone supplied by the caller.
@immutable
class GuildContributionMilestone {
  const GuildContributionMilestone({
    required this.id,
    required this.requiredContribution,
    required this.reward,
    this.isClaimed = false,
  });

  final String id;
  final int requiredContribution;
  final MilestoneReward reward;
  final bool isClaimed;

  bool isReached(int totalContribution) =>
      totalContribution >= requiredContribution;
}

/// Guild goal progress with member contribution and caller-owned actions.
class GuildContributionCard extends StatelessWidget {
  GuildContributionCard({
    super.key,
    required this.guildName,
    required this.goalTitle,
    required this.totalContribution,
    required this.goalContribution,
    required this.memberContribution,
    required this.milestones,
    required this.onContribute,
    required this.onClaimMilestone,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.contributeLabel = 'Contribute',
    this.title = 'Guild Goal',
  }) {
    if (guildName.trim().isEmpty ||
        goalTitle.trim().isEmpty ||
        title.trim().isEmpty) {
      throw ArgumentError('guildName, goalTitle and title must not be empty');
    }
    if (totalContribution < 0 ||
        memberContribution < 0 ||
        goalContribution <= 0) {
      throw ArgumentError(
        'contribution values must be non-negative and goal positive',
      );
    }
    if (contributeLabel.trim().isEmpty) {
      throw ArgumentError.value(
        contributeLabel,
        'contributeLabel',
        'must not be empty',
      );
    }
    final ids = <String>{};
    var previous = -1;
    for (final milestone in milestones) {
      if (milestone.id.trim().isEmpty || milestone.requiredContribution <= 0) {
        throw ArgumentError.value(
          milestone,
          'milestones',
          'id and positive threshold required',
        );
      }
      if (!ids.add(milestone.id)) {
        throw ArgumentError.value(
          milestone.id,
          'milestones',
          'duplicate milestone id',
        );
      }
      if (milestone.requiredContribution <= previous) {
        throw ArgumentError.value(
          milestone.requiredContribution,
          'milestones',
          'thresholds must be strictly increasing',
        );
      }
      previous = milestone.requiredContribution;
    }
  }

  final String guildName;
  final String goalTitle;
  final int totalContribution;
  final int goalContribution;
  final int memberContribution;
  final List<GuildContributionMilestone> milestones;
  final VoidCallback onContribute;
  final ValueChanged<String> onClaimMilestone;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function()? onRetry;
  final String contributeLabel;
  final String title;

  double get progress => (totalContribution / goalContribution).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final semantics =
        '$title for $guildName. $goalTitle. ${fmtNum(totalContribution)} of ${fmtNum(goalContribution)} contribution. You contributed ${fmtNum(memberContribution)}.';
    return Semantics(
      key: const ValueKey('guildContributionSemantics'),
      container: true,
      label: semantics,
      child: Container(
        padding: const EdgeInsets.all(NeonTheme.s16),
        decoration: BoxDecoration(
          color: NeonTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: NeonTheme.cyan.withValues(alpha: 0.35),
            width: 2,
          ),
          boxShadow: NeonTheme.drop(y: 4, blur: 12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: NeonTheme.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              guildName,
              style: TextStyle(
                color: NeonTheme.cyan,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: NeonTheme.s8),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (errorMessage != null)
              _errorView()
            else ...[
              Text(
                goalTitle,
                style: TextStyle(
                  color: NeonTheme.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 4,
                children: [
                  Text(
                    '${fmtNum(totalContribution)} / ${fmtNum(goalContribution)}',
                    key: const ValueKey('guildTotalContribution'),
                    style: TextStyle(
                      color: NeonTheme.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'You: ${fmtNum(memberContribution)}',
                    key: const ValueKey('guildMemberContribution'),
                    style: TextStyle(
                      color: NeonTheme.inkSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    color: NeonTheme.cyan,
                    backgroundColor: NeonTheme.cardAlt,
                  ),
                ),
              ),
              if (milestones.isNotEmpty) ...[
                const SizedBox(height: NeonTheme.s8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final milestone in milestones)
                      _milestoneChip(milestone),
                  ],
                ),
              ],
              const SizedBox(height: NeonTheme.s16),
              CommonButton(
                key: const ValueKey('guildContributeBtn'),
                label: contributeLabel,
                onTap: onContribute,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _milestoneChip(GuildContributionMilestone milestone) {
    final reached = milestone.isReached(totalContribution);
    final claimed = milestone.isClaimed;
    final color = reached ? NeonTheme.gold : NeonTheme.muted;
    final reward = milestone.reward;
    return GestureDetector(
      key: ValueKey('guildMilestone_${milestone.id}'),
      onTap: reached && !claimed ? () => onClaimMilestone(milestone.id) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Icon(
              claimed
                  ? Icons.check_circle_rounded
                  : reached
                  ? reward.icon
                  : Icons.lock_rounded,
              size: 15,
              color: color,
            ),
            Text(
              claimed
                  ? 'Claimed'
                  : '${fmtNum(milestone.requiredContribution)}: ${reward.label}',
              style: TextStyle(
                color: reached ? NeonTheme.ink : NeonTheme.inkSoft,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (!claimed && reached)
              Text(
                reward.amountLabel ?? '',
                style: TextStyle(
                  color: NeonTheme.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() => Column(
    children: [
      Text(
        errorMessage!,
        key: const ValueKey('guildContributionError'),
        textAlign: TextAlign.center,
        style: TextStyle(color: NeonTheme.red, fontWeight: FontWeight.w700),
      ),
      if (onRetry != null)
        GestureDetector(
          key: const ValueKey('guildContributionRetry'),
          onTap: onRetry,
          child: Text(
            'Retry',
            style: TextStyle(
              color: NeonTheme.cyan,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
    ],
  );
}

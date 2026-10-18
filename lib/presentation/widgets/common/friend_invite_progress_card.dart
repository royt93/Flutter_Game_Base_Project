import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'milestone_celebration_dialog.dart' show MilestoneReward;

/// Caller-owned view of a referral reward milestone.
@immutable
class FriendInviteMilestone {
  const FriendInviteMilestone({
    required this.id,
    required this.requiredInvites,
    required this.reward,
    this.isClaimed = false,
  });

  final String id;
  final int requiredInvites;
  final MilestoneReward reward;
  final bool isClaimed;

  bool isReached(int completedInvites) => completedInvites >= requiredInvites;
}

/// Referral progress card. Eligibility, invite attribution and reward grants
/// remain caller-owned; this widget only presents supplied state and callbacks.
class FriendInviteProgressCard extends StatelessWidget {
  FriendInviteProgressCard({
    super.key,
    required this.completedInvites,
    required this.inviteGoal,
    required this.milestones,
    required this.onInvite,
    required this.onClaimReward,
    this.inviteCode,
    this.onCopyInvite,
    this.title = 'Invite Friends',
    this.message = 'Invite friends and earn rewards together.',
    this.inviteLabel = 'Invite Friends',
    this.copyLabel = 'Copy Code',
    this.semanticLabel,
  }) {
    if (completedInvites < 0 || inviteGoal <= 0) {
      throw ArgumentError(
        'completedInvites must be non-negative and inviteGoal positive',
      );
    }
    if (title.trim().isEmpty || message.trim().isEmpty) {
      throw ArgumentError('title and message must not be empty');
    }
    if (inviteLabel.trim().isEmpty || copyLabel.trim().isEmpty) {
      throw ArgumentError('action labels must not be empty');
    }
    if (inviteCode != null && inviteCode!.trim().isEmpty) {
      throw ArgumentError.value(
        inviteCode,
        'inviteCode',
        'must not be empty when provided',
      );
    }
    final ids = <String>{};
    var previous = 0;
    for (final milestone in milestones) {
      if (milestone.id.trim().isEmpty || milestone.requiredInvites <= 0) {
        throw ArgumentError.value(
          milestone,
          'milestones',
          'id and positive invite target required',
        );
      }
      if (!ids.add(milestone.id)) {
        throw ArgumentError.value(
          milestone.id,
          'milestones',
          'duplicate milestone id',
        );
      }
      if (milestone.requiredInvites <= previous) {
        throw ArgumentError.value(
          milestone.requiredInvites,
          'milestones',
          'invite thresholds must be strictly increasing',
        );
      }
      previous = milestone.requiredInvites;
    }
  }

  final int completedInvites;
  final int inviteGoal;
  final List<FriendInviteMilestone> milestones;
  final VoidCallback onInvite;
  final ValueChanged<String> onClaimReward;
  final String? inviteCode;
  final VoidCallback? onCopyInvite;
  final String title;
  final String message;
  final String inviteLabel;
  final String copyLabel;
  final String? semanticLabel;

  double get progress => (completedInvites / inviteGoal).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final semantics =
        semanticLabel ??
        '$title. $completedInvites of $inviteGoal invites completed. ${milestones.length} reward milestones.';
    return Semantics(
      key: const ValueKey('friendInviteProgressSemantics'),
      container: true,
      label: semantics,
      child: Container(
        padding: const EdgeInsets.all(NeonTheme.s16),
        decoration: BoxDecoration(
          color: NeonTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: NeonTheme.purple.withValues(alpha: 0.35),
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
            const SizedBox(height: 3),
            Text(
              message,
              style: TextStyle(
                color: NeonTheme.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: NeonTheme.s8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 4,
              children: [
                Text(
                  '$completedInvites / $inviteGoal invited',
                  key: const ValueKey('friendInviteProgressCount'),
                  style: TextStyle(
                    color: NeonTheme.purple,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    color: NeonTheme.inkSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  color: NeonTheme.purple,
                  backgroundColor: NeonTheme.cardAlt,
                ),
              ),
            ),
            if (inviteCode != null) ...[
              const SizedBox(height: NeonTheme.s8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(
                    'Code: $inviteCode',
                    key: const ValueKey('friendInviteCode'),
                    style: TextStyle(
                      color: NeonTheme.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (onCopyInvite != null)
                    GestureDetector(
                      key: const ValueKey('friendInviteCopyBtn'),
                      onTap: onCopyInvite,
                      child: Text(
                        copyLabel,
                        style: TextStyle(
                          color: NeonTheme.cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (milestones.isNotEmpty) ...[
              const SizedBox(height: NeonTheme.s8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final m in milestones) _milestoneChip(m)],
              ),
            ],
            const SizedBox(height: NeonTheme.s16),
            CommonButton(
              key: const ValueKey('friendInviteActionBtn'),
              label: inviteLabel,
              color: NeonTheme.purple,
              onTap: onInvite,
            ),
          ],
        ),
      ),
    );
  }

  Widget _milestoneChip(FriendInviteMilestone milestone) {
    final reached = milestone.isReached(completedInvites);
    final claimed = milestone.isClaimed;
    final color = reached ? NeonTheme.gold : NeonTheme.muted;
    return GestureDetector(
      key: ValueKey('friendInviteMilestone_${milestone.id}'),
      onTap: reached && !claimed ? () => onClaimReward(milestone.id) : null,
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
                  ? milestone.reward.icon
                  : Icons.lock_rounded,
              size: 15,
              color: color,
            ),
            Text(
              claimed
                  ? 'Claimed'
                  : '${milestone.requiredInvites}: ${milestone.reward.label}',
              style: TextStyle(
                color: reached ? NeonTheme.ink : NeonTheme.inkSoft,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (!claimed && reached && milestone.reward.amountLabel != null)
              Text(
                milestone.reward.amountLabel!,
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
}

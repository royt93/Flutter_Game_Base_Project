import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/friend_invite_progress_card.dart';
import 'package:roy_casual_kit/presentation/widgets/common/milestone_celebration_dialog.dart';

import '../../support/golden_matrix.dart';

final _milestones = [
  FriendInviteMilestone(
    id: 'invite_1',
    requiredInvites: 1,
    reward: MilestoneReward(
      icon: Icons.diamond_rounded,
      label: 'Gems',
      amountLabel: 'x20',
    ),
  ),
  FriendInviteMilestone(
    id: 'invite_3',
    requiredInvites: 3,
    reward: MilestoneReward(
      icon: Icons.shield_rounded,
      label: 'Shield',
      amountLabel: 'x1',
    ),
  ),
];

void main() {
  testWidgets('FriendInviteProgressCard progress with code qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: FriendInviteProgressCard(
          completedInvites: 1,
          inviteGoal: 3,
          milestones: _milestones,
          inviteCode: 'ROY2026',
          onInvite: () {},
          onCopyInvite: () {},
          onClaimReward: (_) {},
        ),
      ),
      guidelines: const [],
    );
  });

  testWidgets(
    'FriendInviteProgressCard complete without code qua Golden Matrix',
    (tester) async {
      await runGoldenMatrix(
        tester,
        (context) => SingleChildScrollView(
          child: FriendInviteProgressCard(
            completedInvites: 3,
            inviteGoal: 3,
            milestones: [
              _milestones.first,
              FriendInviteMilestone(
                id: 'invite_3',
                requiredInvites: 3,
                reward: _milestones.last.reward,
                isClaimed: true,
              ),
            ],
            onInvite: () {},
            onClaimReward: (_) {},
          ),
        ),
        guidelines: const [],
      );
    },
  );
}

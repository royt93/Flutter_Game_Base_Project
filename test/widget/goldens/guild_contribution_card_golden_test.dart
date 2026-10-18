import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/guild_contribution_card.dart';
import 'package:roy_casual_kit/presentation/widgets/common/milestone_celebration_dialog.dart';

import '../../support/golden_matrix.dart';

final _milestones = [
  GuildContributionMilestone(
    id: 'm1',
    requiredContribution: 100,
    reward: MilestoneReward(
      icon: Icons.diamond_rounded,
      label: 'Gems',
      amountLabel: 'x50',
    ),
  ),
  GuildContributionMilestone(
    id: 'm2',
    requiredContribution: 500,
    reward: MilestoneReward(
      icon: Icons.shield_rounded,
      label: 'Shield',
      amountLabel: 'x2',
    ),
  ),
];

void main() {
  testWidgets(
    'GuildContributionCard progress with milestone qua Golden Matrix',
    (tester) async {
      await runGoldenMatrix(
        tester,
        (context) => SingleChildScrollView(
          child: GuildContributionCard(
            guildName: 'Star Seekers',
            goalTitle: 'Community Boss',
            totalContribution: 300,
            goalContribution: 1000,
            memberContribution: 125,
            milestones: _milestones,
            onContribute: () {},
            onClaimMilestone: (_) {},
          ),
        ),
        guidelines: const [],
      );
    },
  );

  testWidgets('GuildContributionCard complete goal qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: GuildContributionCard(
          guildName: 'Star Seekers',
          goalTitle: 'Community Boss Defeated',
          totalContribution: 1200,
          goalContribution: 1000,
          memberContribution: 500,
          milestones: [
            ..._milestones,
            GuildContributionMilestone(
              id: 'm3',
              requiredContribution: 1000,
              reward: MilestoneReward(
                icon: Icons.stars_rounded,
                label: 'Golden Badge',
              ),
            ),
          ],
          onContribute: () {},
          onClaimMilestone: (_) {},
        ),
      ),
      guidelines: const [],
    );
  });
}

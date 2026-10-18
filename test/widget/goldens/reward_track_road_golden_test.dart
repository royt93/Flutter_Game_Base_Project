import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/reward_track_road.dart';
import 'package:roy_casual_kit/presentation/widgets/common/milestone_celebration_dialog.dart';

import '../../support/golden_matrix.dart';

final _tiers = [
  for (var i = 1; i <= 5; i++)
    RewardTrackTier(
      id: 'tier_$i',
      requiredXp: i * 100,
      freeReward: MilestoneReward(
        icon: Icons.monetization_on_rounded,
        label: 'Coins',
        amountLabel: 'x${i * 100}',
      ),
      premiumReward: MilestoneReward(
        icon: Icons.diamond_rounded,
        label: 'Gems',
        amountLabel: 'x${i * 10}',
      ),
    ),
];

void main() {
  testWidgets('RewardTrackRoad premium locked qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) =>
          RewardTrackRoad(tiers: _tiers, currentXp: 250, onClaim: (_, _) {}),
      guidelines: const [],
    );
  });

  testWidgets(
    'RewardTrackRoad premium unlocked and late progress qua Golden Matrix',
    (tester) async {
      await runGoldenMatrix(
        tester,
        (context) => RewardTrackRoad(
          tiers: _tiers,
          currentXp: 450,
          premiumEnabled: true,
          claimedFreeIds: const {'tier_1:free'},
          onClaim: (_, _) {},
        ),
        guidelines: const [],
      );
    },
  );
}

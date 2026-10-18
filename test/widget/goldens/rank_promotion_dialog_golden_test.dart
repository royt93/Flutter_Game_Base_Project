import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

import '../../support/golden_matrix.dart';

void main() {
  testWidgets('RankPromotionDialog bronze to silver qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: RankPromotionDialog(
          fromTier: LeaderboardTier.bronze,
          toTier: LeaderboardTier.silver,
          onContinue: () {},
          onShare: () {},
        ),
      ),
      guidelines: const [],
    );
  });

  testWidgets(
    'RankPromotionDialog gold to diamond with rewards qua Golden Matrix',
    (tester) async {
      await runGoldenMatrix(
        tester,
        (context) => SingleChildScrollView(
          child: RankPromotionDialog(
            fromTier: LeaderboardTier.gold,
            toTier: LeaderboardTier.diamond,
            rewards: [
              MilestoneReward(
                icon: Icons.diamond_rounded,
                label: 'Diamonds',
                amountLabel: 'x500',
              ),
              MilestoneReward(
                icon: Icons.shield_rounded,
                label: 'Freeze Shield',
                amountLabel: 'x3',
              ),
            ],
            onContinue: () {},
          ),
        ),
        guidelines: const [],
      );
    },
  );
}

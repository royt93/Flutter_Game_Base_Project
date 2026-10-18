import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/vip_perk_progress_row.dart';

import '../../support/golden_matrix.dart';

void main() {
  testWidgets('VipPerkProgressRow regular progress qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: VipPerkProgressRow(
          currentTier: 3,
          currentPoints: 750,
          nextTierPoints: 1000,
          perks: const [
            VipPerk(icon: Icons.bolt_rounded, label: '+25% Coins'),
            VipPerk(icon: Icons.favorite_rounded, label: '+1 Max Life'),
            VipPerk(
              icon: Icons.shield_rounded,
              label: 'Free Shield',
              isUnlocked: false,
            ),
          ],
          onAction: () {},
        ),
      ),
      guidelines: const [],
    );
  });

  testWidgets('VipPerkProgressRow max tier qua Golden Matrix', (tester) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: VipPerkProgressRow(
          currentTier: 10,
          currentPoints: 50000,
          tierLabel: 'VIP Diamond',
          perks: const [
            VipPerk(icon: Icons.stars_rounded, label: 'All Perks Unlocked'),
          ],
        ),
      ),
      guidelines: const [],
    );
  });
}

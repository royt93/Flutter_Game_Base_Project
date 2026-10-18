import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/streak_shield_card.dart';

import '../../support/golden_matrix.dart';

void main() {
  testWidgets('StreakShieldCard with shield qua Golden Matrix', (tester) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: StreakShieldCard(
          streakDays: 14,
          shieldCount: 2,
          missedDateLabel: 'Yesterday',
          onUseShield: () {},
          onDismiss: () {},
        ),
      ),
      guidelines: const [],
    );
  });

  testWidgets('StreakShieldCard out of shields qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: StreakShieldCard(
          streakDays: 30,
          shieldCount: 0,
          missedDateLabel: 'Oct 17',
          onRepair: () {},
          onDismiss: () {},
        ),
      ),
      guidelines: const [],
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/prestige_confirmation_card.dart';

import '../../support/golden_matrix.dart';

void main() {
  testWidgets('PrestigeConfirmationCard qua toàn bộ ma trận Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: PrestigeConfirmationCard(
          currentLevel: 50,
          requiredPrestigeValue: 'Level 50',
          currentMultiplier: 1.0,
          nextMultiplier: 2.0,
          rewards: const [
            PrestigeReward(
              icon: Icons.bolt_rounded,
              label: 'Permanent Energy Boost',
              amount: '+50%',
            ),
            PrestigeReward(
              icon: Icons.auto_awesome_rounded,
              label: 'Prestige Trophy',
              amount: 'x1',
            ),
          ],
          onConfirm: () {},
          onCancel: () {},
        ),
      ),
      guidelines: const [],
    );
  });
}

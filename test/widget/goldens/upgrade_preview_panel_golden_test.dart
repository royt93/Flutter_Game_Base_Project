import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/upgrade_preview_panel.dart';

import '../../support/golden_matrix.dart';

const _stats = [
  UpgradeStatChange(
    label: 'Attack',
    currentValue: '25',
    nextValue: '32',
    icon: Icons.flash_on_rounded,
  ),
  UpgradeStatChange(
    label: 'Defense',
    currentValue: '10',
    nextValue: '14',
    icon: Icons.shield_rounded,
  ),
  UpgradeStatChange(
    label: 'Cooldown',
    currentValue: '8s',
    nextValue: '6s',
    icon: Icons.timer_rounded,
    isImprovement: true,
  ),
];

void main() {
  testWidgets('UpgradePreviewPanel affordable qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: UpgradePreviewPanel(
          title: 'Dragon Sword',
          currentLevel: 3,
          nextLevel: 4,
          statChanges: _stats,
          costs: const [
            UpgradeCost(
              label: 'Coins',
              currentAmount: 1200,
              requiredAmount: 750,
            ),
            UpgradeCost(
              label: 'Gems',
              currentAmount: 20,
              requiredAmount: 10,
              icon: Icons.diamond_rounded,
            ),
          ],
          onUpgrade: () {},
        ),
      ),
      guidelines: const [],
    );
  });

  testWidgets('UpgradePreviewPanel max level qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: UpgradePreviewPanel(
          title: 'Dragon Sword',
          currentLevel: 9,
          nextLevel: 10,
          statChanges: _stats,
          costs: const [
            UpgradeCost(label: 'Coins', currentAmount: 0, requiredAmount: 0),
          ],
          isMaxLevel: true,
          onUpgrade: () {},
        ),
      ),
      guidelines: const [],
    );
  });
}

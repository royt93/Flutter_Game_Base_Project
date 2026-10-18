import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/next_reward_teaser_chip.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance(
    'next_reward_teaser_chip_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);

  const states = <String, (String, String, double?, bool)>{
    'progress': ('Star Chest', '2 wins to go', 0.6, false),
    'noprogress': ('Star Chest', '2 wins to go', null, false),
    'ready': ('Star Chest', '2 wins to go', 1.0, true),
    'long': (
      'An Extraordinarily Long Reward Name That Will Not Fit',
      'Only a very large number of wins are left to go',
      0.3,
      false,
    ),
  };
  for (final entry in states.entries) {
    testWidgets('NextRewardTeaserChip ${entry.key} golden matrix', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await runGoldenMatrix(
        tester,
        (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: NextRewardTeaserChip(
            rewardLabel: entry.value.$1,
            remainingText: entry.value.$2,
            progress: entry.value.$3,
            ready: entry.value.$4,
            onTap: () {},
          ),
        ),
        goldenBaseName: 'next_reward_teaser_chip_${entry.key}',
      );
    });
  }
}

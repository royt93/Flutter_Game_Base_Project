import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/streak_milestone_strip.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

const _milestones = [
  StreakMilestone(days: 3, rewardLabel: '50 coins'),
  StreakMilestone(days: 7, rewardLabel: 'Mystery chest'),
  StreakMilestone(days: 14, rewardLabel: 'Rare skin'),
  StreakMilestone(days: 30, rewardLabel: 'Legendary hero'),
];

void main() {
  final previous = installGoldenTolerance(
    'streak_milestone_strip_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);

  const states = <String, (int, Set<int>)>{
    'none': (1, <int>{}),
    'claimable': (8, <int>{}),
    'mixed': (15, <int>{3}),
    'all': (40, <int>{3, 7, 14, 30}),
  };
  for (final entry in states.entries) {
    testWidgets('StreakMilestoneStrip ${entry.key} golden matrix', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await runGoldenMatrix(
        tester,
        (_) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: StreakMilestoneStrip(
            milestones: _milestones,
            currentStreak: entry.value.$1,
            claimedDays: entry.value.$2,
            onClaim: (_) {},
          ),
        ),
        goldenBaseName: 'streak_milestone_strip_${entry.key}',
      );
    });
  }
}

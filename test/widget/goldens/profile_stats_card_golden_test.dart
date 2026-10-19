import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/profile_stats_card.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

List<ProfileStat> stats(int count) => [
  for (var i = 0; i < count; i++)
    ProfileStat(label: 'Stat $i', valueText: '${i * 10}K', icon: Icons.star),
];

void main() {
  final previous = installGoldenTolerance(
    'profile_stats_card_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);
  const states = ['complete', 'minimal', 'four_stats', 'long_name'];
  for (final state in states) {
    testWidgets('ProfileStatsCard $state golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await runGoldenMatrix(
        tester,
        (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: ProfileStatsCard(
            name: state == 'long_name'
                ? 'An Extraordinarily Long Player Display Name'
                : 'Maya Rose',
            title: state == 'minimal' ? null : 'Explorer',
            avatar: const Icon(Icons.face),
            frameColor: Colors.amber,
            level: state == 'minimal'
                ? null
                : ProfileLevel(level: 12, currentXp: 60, xpForNextLevel: 100),
            stats: stats(
              state == 'minimal'
                  ? 0
                  : state == 'four_stats'
                  ? 4
                  : 2,
            ),
          ),
        ),
        goldenBaseName: 'profile_stats_card_$state',
      );
    });
  }
}

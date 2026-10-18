import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/quest_progress_pill.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance(
    'quest_progress_pill_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);

  const states = {
    'none': (0, 0),
    'partial': (2, 0),
    'claimable': (2, 2),
    'many': (12, 12),
    'complete': (3, 0),
  };
  for (final entry in states.entries) {
    testWidgets('QuestProgressPill ${entry.key} golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final many = entry.key == 'many';
      await runGoldenMatrix(
        tester,
        (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: QuestProgressPill(
            completed: entry.value.$1,
            total: many ? 15 : 3,
            claimableCount: entry.value.$2,
            onTap: () {},
          ),
        ),
        goldenBaseName: 'quest_progress_pill_${entry.key}',
      );
    });
  }
}

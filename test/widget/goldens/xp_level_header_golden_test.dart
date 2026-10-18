import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/xp_level_header.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance('xp_level_header_golden_test.dart');
  tearDownAll(() => goldenFileComparator = previous);

  const states = <String, (int, int?)>{
    'zero': (0, 100),
    'mid': (50, 100),
    'almost': (99, 100),
    'max': (0, null),
  };
  for (final entry in states.entries) {
    testWidgets('XpLevelHeader ${entry.key} golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await runGoldenMatrix(
        tester,
        (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: XpLevelHeader(
            level: entry.value.$2 == null ? 50 : 7,
            currentXp: entry.value.$1,
            xpForNextLevel: entry.value.$2,
            title: 'Explorer',
            onTap: () {},
          ),
        ),
        goldenBaseName: 'xp_level_header_${entry.key}',
      );
    });
  }
}

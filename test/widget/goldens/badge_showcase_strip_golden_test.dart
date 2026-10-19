import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/badge_showcase_strip.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

final _badges = [
  BadgeShowcaseItem(
    id: 'first',
    label: 'First Win',
    icon: Icons.emoji_events_rounded,
  ),
  BadgeShowcaseItem(
    id: 'streak',
    label: '7-Day Streak',
    icon: Icons.local_fire_department_rounded,
  ),
  BadgeShowcaseItem(
    id: 'collector',
    label: 'Collector',
    icon: Icons.stars_rounded,
  ),
];

void main() {
  final previous = installGoldenTolerance(
    'badge_showcase_strip_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);
  final states = <String, (List<BadgeShowcaseItem>, bool)>{
    'empty': (<BadgeShowcaseItem>[], false),
    'partial': (_badges, false),
    'full': (_badges, true),
    'readonly': (_badges, true),
  };
  for (final entry in states.entries) {
    testWidgets('BadgeShowcaseStrip ${entry.key} golden matrix', (
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
          child: BadgeShowcaseStrip(
            slotCount: 3,
            badges: entry.value.$1,
            readOnly: entry.key == 'readonly',
            onSlotTap: (_) {},
          ),
        ),
        goldenBaseName: 'badge_showcase_strip_${entry.key}',
      );
    });
  }
}

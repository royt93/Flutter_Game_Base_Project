import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance('wave27_widgets_golden_test.dart');
  tearDownAll(() => goldenFileComparator = previous);

  Widget build(String state) => switch (state) {
    'watchdog_empty' => MemoryWatchdogPanel(orphans: [], recentlyDisposed: []),
    'watchdog_orphans' => MemoryWatchdogPanel(
      orphans: [
        WatchdogRow(
          kindLabel: 'Controller',
          ownerText: 'DemoWidget',
          ageText: '12s',
        ),
        WatchdogRow(
          kindLabel: 'Subscription',
          ownerText: 'DemoService',
          ageText: '8s',
        ),
      ],
      recentlyDisposed: [],
    ),
    'watchdog_disposed' => MemoryWatchdogPanel(
      orphans: [],
      recentlyDisposed: [
        WatchdogRow(
          kindLabel: 'Overlay',
          ownerText: 'DemoOverlay',
          ageText: '3s',
        ),
      ],
    ),
    _ => AnnouncementPreviewCard(
      messageText: 'Level 7 complete. 250 coins earned.',
      localeLabel: 'English',
      categoryLabel: 'Reward',
      throttleText: '1.5 seconds per category',
      onPreview: () async {},
    ),
  };

  for (final state in [
    'watchdog_empty',
    'watchdog_orphans',
    'watchdog_disposed',
    'announcement',
  ]) {
    testWidgets('Wave 27 $state golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final variant in defaultGoldenMatrix()) {
        await tester.pumpWidget(const SizedBox.shrink());
        const target = ValueKey('wave27Golden');
        await runGoldenMatrix(
          tester,
          (_) => Padding(
            key: target,
            padding: const EdgeInsets.all(16),
            child: build(state),
          ),
          matrix: [variant],
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(target),
          matchesGoldenFile('goldens/wave27_${state}_${variant.name}.png'),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}

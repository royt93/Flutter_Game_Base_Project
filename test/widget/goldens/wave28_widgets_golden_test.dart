import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance('wave28_widgets_golden_test.dart');
  tearDownAll(() => goldenFileComparator = previous);

  Widget build(String state) => switch (state) {
    'queue_empty' => AnalyticsQueueStatusCard(
      snapshot: AnalyticsQueueSnapshot(
        pendingCount: 0,
        uploadedCount: 120,
        droppedCounts: const {},
      ),
      onFlush: () async {},
    ),
    'queue_consent_denied' => AnalyticsQueueStatusCard(
      snapshot: AnalyticsQueueSnapshot(
        pendingCount: 8,
        uploadedCount: 40,
        droppedCounts: {'Consent not granted': 3, 'Queue full': 1},
      ),
      consentGranted: false,
    ),
    'queue_pending' => AnalyticsQueueStatusCard(
      snapshot: AnalyticsQueueSnapshot(
        pendingCount: 12,
        uploadedCount: 88,
        droppedCounts: {'Rate limited': 4, 'Schema rejected': 2},
      ),
      onFlush: () async {},
    ),
    'restore_empty' => SaveRestorePreviewPanel(
      slots: const [],
      onConfirmRestore: () async {},
    ),
    'restore_slots' => SaveRestorePreviewPanel(
      slots: [
        RestoreSlotPreview(
          slotName: 'Hero Slot',
          lastPlayedText: 'Yesterday, 16:05',
          keyCount: 42,
        ),
        RestoreSlotPreview(
          slotName: 'Speed Run',
          lastPlayedText: 'Last week',
          keyCount: 19,
        ),
      ],
      appVersionText: '0.6.0',
      generatedAtText: 'Today, 10:30',
      onConfirmRestore: () async {},
    ),
    _ => SaveRestorePreviewPanel(
      slots: const [],
      onConfirmRestore: () async {},
    ),
  };

  for (final state in [
    'queue_empty',
    'queue_consent_denied',
    'queue_pending',
    'restore_empty',
    'restore_slots',
  ]) {
    testWidgets('Wave 28 $state golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final variant in defaultGoldenMatrix()) {
        await tester.pumpWidget(const SizedBox.shrink());
        const target = ValueKey('wave28Golden');
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
          matchesGoldenFile('goldens/wave28_${state}_${variant.name}.png'),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/consent_state_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance('wave24_widgets_golden_test.dart');
  tearDownAll(() => goldenFileComparator = previous);

  Widget build(String state) => switch (state) {
    'consent' || 'consent_unknown' => ConsentPreferencesPanel(
      items: [
        ConsentPreferenceItem(
          id: 'analytics',
          label: 'Analytics',
          description: 'Help improve the game.',
          status: ConsentStatus.unknown,
        ),
        ConsentPreferenceItem(
          id: 'personalization',
          label: 'Personalization',
          description: 'Tailor content to your play.',
          status: ConsentStatus.granted,
        ),
      ],
      onChanged: (_, _) async {},
    ),
    'consent_denied' => ConsentPreferencesPanel(
      items: [
        ConsentPreferenceItem(
          id: 'analytics',
          label: 'Analytics',
          description: 'Help improve the game.',
          status: ConsentStatus.denied,
        ),
        ConsentPreferenceItem(
          id: 'personalization',
          label: 'Personalization',
          description: 'Tailor content to your play.',
          status: ConsentStatus.granted,
        ),
      ],
      onChanged: (_, _) async {},
    ),
    'consent_busy' => ConsentPreferencesPanel(
      items: [
        ConsentPreferenceItem(
          id: 'analytics',
          label: 'Analytics',
          description: 'Help improve the game.',
          status: ConsentStatus.unknown,
        ),
        ConsentPreferenceItem(
          id: 'personalization',
          label: 'Personalization',
          description: 'Tailor content to your play.',
          status: ConsentStatus.granted,
        ),
      ],
      busy: true,
      onChanged: (_, _) async {},
    ),
    'sync_idle' => SyncStatusCard(status: SyncStatus.idle, onSync: () async {}),
    'syncing' => SyncStatusCard(
      status: SyncStatus.syncing,
      onSync: () async {},
    ),
    'sync_synced' => SyncStatusCard(
      status: SyncStatus.synced,
      lastSyncedText: 'Today, 10:30',
      onSync: () async {},
    ),
    'sync_failed' => SyncStatusCard(
      status: SyncStatus.failed,
      lastSyncedText: 'Yesterday, 16:05',
      onSync: () async {},
    ),
    'battery_off' => BatterySaverIndicator(active: false),
    'battery_low' => BatterySaverIndicator(active: true, batteryPercent: 12),
    _ => BatterySaverIndicator(active: true),
  };

  for (final state in [
    'consent',
    'consent_denied',
    'consent_busy',
    'sync_idle',
    'syncing',
    'sync_synced',
    'sync_failed',
    'battery_off',
    'battery_low',
    'battery_unknown',
  ]) {
    testWidgets('Wave 24 $state golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final variant in defaultGoldenMatrix()) {
        await tester.pumpWidget(const SizedBox.shrink());
        const target = ValueKey('wave24Golden');
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
          matchesGoldenFile('goldens/wave24_${state}_${variant.name}.png'),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}

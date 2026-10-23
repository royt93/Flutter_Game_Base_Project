import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance('wave29_widgets_golden_test.dart');
  tearDownAll(() => goldenFileComparator = previous);

  Widget build(String state) => switch (state) {
    'config_asset' => RemoteConfigHealthCard(
      source: RemoteConfigHealthSource.assetOnly,
      violationCount: 0,
    ),
    'config_remote' => RemoteConfigHealthCard(
      source: RemoteConfigHealthSource.remoteMerged,
      violationCount: 0,
      lastCheckedText: 'Today, 10:30',
    ),
    'config_failed' => RemoteConfigHealthCard(
      source: RemoteConfigHealthSource.remoteFailed,
      violationCount: 2,
      onRefresh: () async {},
    ),
    'reminder_disabled' => ReminderPreferencesPanel(
      intervalOptions: [
        ReminderIntervalOption(id: 'daily', label: 'Every day'),
        ReminderIntervalOption(id: 'weekly', label: 'Every week'),
      ],
      enabled: false,
      selectedId: 'daily',
      onChanged: (_, _) async {},
    ),
    'reminder_enabled' => ReminderPreferencesPanel(
      intervalOptions: [
        ReminderIntervalOption(id: 'daily', label: 'Every day'),
        ReminderIntervalOption(id: 'weekly', label: 'Every week'),
      ],
      enabled: true,
      selectedId: 'weekly',
      onChanged: (_, _) async {},
    ),
    'connectivity_offline' => ConnectivityStatusCard(
      state: ConnectivityCardState.offline,
      queuedCount: 4,
      onRetry: () async {},
    ),
    'connectivity_checking' => ConnectivityStatusCard(
      state: ConnectivityCardState.checking,
      queuedCount: 4,
    ),
    'connectivity_online' => ConnectivityStatusCard(
      state: ConnectivityCardState.online,
      queuedCount: 0,
    ),
    _ => ConnectivityStatusCard(
      state: ConnectivityCardState.degraded,
      queuedCount: 2,
      onRetry: () async {},
    ),
  };

  for (final state in [
    'config_asset',
    'config_remote',
    'config_failed',
    'reminder_disabled',
    'reminder_enabled',
    'connectivity_offline',
    'connectivity_checking',
    'connectivity_online',
    'connectivity_degraded',
  ]) {
    testWidgets('Wave 29 $state golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final variant in defaultGoldenMatrix()) {
        await tester.pumpWidget(const SizedBox.shrink());
        const target = ValueKey('wave29Golden');
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
          matchesGoldenFile('goldens/wave29_${state}_${variant.name}.png'),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}

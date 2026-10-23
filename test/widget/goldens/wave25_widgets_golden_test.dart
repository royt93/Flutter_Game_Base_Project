import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance('wave25_widgets_golden_test.dart');
  tearDownAll(() => goldenFileComparator = previous);

  Widget build(String state) => switch (state) {
    'kill_active' || 'kill_confirm' => RemoteKillSwitchPanel(
      items: [
        KillSwitchItem(
          id: 'shop',
          label: 'Event shop',
          killed: false,
          sourceLabel: 'Remote configuration',
        ),
        KillSwitchItem(
          id: 'event',
          label: 'Limited event',
          killed: true,
          sourceLabel: 'Last known good',
          localOverride: true,
        ),
      ],
      onKillLocally: (_) async {},
      onClearOverride: (_) async {},
    ),
    'kill_busy' => RemoteKillSwitchPanel(
      items: [
        KillSwitchItem(
          id: 'shop',
          label: 'Event shop',
          killed: false,
          sourceLabel: 'Remote configuration',
        ),
      ],
      busy: true,
      onKillLocally: (_) async {},
      onClearOverride: (_) async {},
    ),
    'platform_web' => PlatformCapabilityMatrix(
      platformLabel: 'Web',
      rows: [
        PlatformCapabilityRow(label: 'Haptics', supported: false),
        PlatformCapabilityRow(label: 'Shaders', supported: false),
        PlatformCapabilityRow(label: 'Notifications', supported: false),
        PlatformCapabilityRow(label: 'Background audio', supported: false),
      ],
    ),
    'platform_android' => PlatformCapabilityMatrix(
      platformLabel: 'Android',
      rows: [
        PlatformCapabilityRow(label: 'Haptics', supported: true),
        PlatformCapabilityRow(label: 'Shaders', supported: true),
        PlatformCapabilityRow(label: 'Notifications', supported: true),
        PlatformCapabilityRow(label: 'Background audio', supported: true),
      ],
    ),
    'link_dispatched' => DeepLinkResultCard(
      status: DeepLinkResultStatus.dispatched,
    ),
    'link_queued' => DeepLinkResultCard(status: DeepLinkResultStatus.queued),
    'link_duplicate' => DeepLinkResultCard(
      status: DeepLinkResultStatus.duplicate,
    ),
    'link_rejected' => DeepLinkResultCard(
      status: DeepLinkResultStatus.rejected,
      onRetry: () async {},
    ),
    'link_handler_failed' => DeepLinkResultCard(
      status: DeepLinkResultStatus.handlerFailed,
      onRetry: () async {},
    ),
    _ => DeepLinkResultCard(status: DeepLinkResultStatus.dispatched),
  };

  for (final state in [
    'kill_active',
    'kill_confirm',
    'kill_busy',
    'platform_web',
    'platform_android',
    'link_dispatched',
    'link_queued',
    'link_duplicate',
    'link_rejected',
    'link_handler_failed',
  ]) {
    testWidgets('Wave 25 $state golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final variant in defaultGoldenMatrix()) {
        await tester.pumpWidget(const SizedBox.shrink());
        const target = ValueKey('wave25Golden');
        await runGoldenMatrix(
          tester,
          (_) => Padding(
            key: target,
            padding: const EdgeInsets.all(16),
            child: build(state),
          ),
          matrix: [variant],
        );
        if (state == 'kill_confirm') {
          final select = find.byKey(const ValueKey('killSwitchSelect_shop'));
          await tester.ensureVisible(select);
          await tester.tap(select);
          await tester.pump();
          expect(
            find.textContaining('cannot enable a remotely killed feature'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(target),
          matchesGoldenFile('goldens/wave25_${state}_${variant.name}.png'),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}

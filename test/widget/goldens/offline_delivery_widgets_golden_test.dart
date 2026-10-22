import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance(
    'offline_delivery_widgets_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);

  final cases =
      <
        ({
          String name,
          Widget child,
          Future<void> Function(WidgetTester tester)? prepare,
        })
      >[
        (
          name: 'queue_idle',
          child: OutboxQueueStatusCard(
            pendingCount: 3,
            manualReviewCount: 0,
            status: OutboxQueueStatus.idle,
            onDrain: _noop,
          ),
          prepare: null,
        ),
        (
          name: 'queue_offline',
          child: OutboxQueueStatusCard(
            pendingCount: 2,
            manualReviewCount: 1,
            status: OutboxQueueStatus.offline,
            onDrain: _noop,
          ),
          prepare: null,
        ),
        (
          name: 'queue_error',
          child: OutboxQueueStatusCard(
            pendingCount: 1,
            manualReviewCount: 0,
            status: OutboxQueueStatus.error,
            onDrain: _noop,
          ),
          prepare: null,
        ),
        (
          name: 'conflict_empty',
          child: OutboxConflictSummaryPanel(
            conflicts: [],
            onResolve: _noopResolve,
          ),
          prepare: null,
        ),
        (
          name: 'conflict_pending',
          child: OutboxConflictSummaryPanel(
            conflicts: [
              OutboxConflictSummary(
                reference: 'opaque-ref-1',
                localLabel: 'Local reward claim',
                remoteLabel: 'Remote reward differs',
                timestampText: 'Checked today',
              ),
            ],
            onResolve: _noopResolve,
          ),
          prepare: null,
        ),
        (
          name: 'conflict_keep_local',
          child: OutboxConflictSummaryPanel(
            conflicts: [
              OutboxConflictSummary(
                reference: 'opaque-ref-1',
                localLabel: 'Local reward claim',
                remoteLabel: 'Remote reward differs',
              ),
            ],
            onResolve: _noopResolve,
          ),
          prepare: (tester) async {
            await tester.tap(
              find.byKey(const ValueKey('outboxKeepLocal_opaque-ref-1')),
            );
            await tester.pump();
          },
        ),
        (
          name: 'conflict_accept_remote',
          child: OutboxConflictSummaryPanel(
            conflicts: [
              OutboxConflictSummary(
                reference: 'opaque-ref-1',
                localLabel: 'Local reward claim',
                remoteLabel: 'Remote reward differs',
              ),
            ],
            onResolve: _noopResolve,
          ),
          prepare: (tester) async {
            await tester.tap(
              find.byKey(const ValueKey('outboxAcceptRemote_opaque-ref-1')),
            );
            await tester.pump();
          },
        ),
      ];

  for (final entry in cases) {
    testWidgets('Offline delivery ${entry.name} golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await runGoldenMatrix(
        tester,
        (_) => Padding(padding: const EdgeInsets.all(16), child: entry.child),
        goldenBaseName: 'offline_delivery_${entry.name}',
      );

      if (entry.prepare != null) {
        const targetKey = ValueKey('offline_delivery_confirmation_target');
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Center(
                child: KeyedSubtree(
                  key: targetKey,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: entry.child,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await entry.prepare!(tester);
        await expectLater(
          find.byKey(targetKey),
          matchesGoldenFile(
            'goldens/offline_delivery_${entry.name}_confirm_baseline.png',
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });
  }
}

Future<void> _noop() async {}

Future<void> _noopResolve(
  String reference,
  OutboxConflictResolution resolution,
) async {}

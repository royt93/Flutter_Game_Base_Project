import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance(
    'save_recovery_widgets_golden_test.dart',
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
          name: 'cloud_ready',
          child: CloudSaveStatusCard(
            status: CloudSaveStatus.ready,
            pendingCount: 2,
            lastSyncText: 'Last synced earlier',
            onSync: _noop,
          ),
          prepare: null,
        ),
        (
          name: 'cloud_syncing',
          child: CloudSaveStatusCard(
            status: CloudSaveStatus.syncing,
            pendingCount: 2,
            busy: true,
            onSync: _noop,
          ),
          prepare: null,
        ),
        (
          name: 'conflict',
          child: SaveConflictPicker(
            local: SaveConflictSummary(
              revision: 'local-r1',
              savedAtText: 'Device copy',
              progressText: 'Level 8',
            ),
            cloud: SaveConflictSummary(
              revision: 'cloud-r1',
              savedAtText: 'Cloud copy',
              progressText: 'Level 12',
            ),
            onResolve: _noopResolve,
          ),
          prepare: null,
        ),
        (
          name: 'conflict_confirm',
          child: SaveConflictPicker(
            local: SaveConflictSummary(
              revision: 'local-r1',
              savedAtText: 'Device copy',
              progressText: 'Level 8',
            ),
            cloud: SaveConflictSummary(
              revision: 'cloud-r1',
              savedAtText: 'Cloud copy',
              progressText: 'Level 12',
            ),
            onResolve: _noopResolve,
          ),
          prepare: (tester) async {
            await tester.tap(find.byKey(const ValueKey('saveConflict_cloud')));
            await tester.pump();
          },
        ),
        (
          name: 'checkpoint',
          child: CheckpointResumeCard(
            checkpoint: CheckpointSummary(
              revision: 'checkpoint-r1',
              savedAtText: 'Saved earlier',
              progressText: 'Level 14',
            ),
            onResume: _noopRevision,
            onStartNew: _noopRevision,
          ),
          prepare: null,
        ),
        (
          name: 'checkpoint_confirm',
          child: CheckpointResumeCard(
            checkpoint: CheckpointSummary(
              revision: 'checkpoint-r1',
              savedAtText: 'Saved earlier',
              progressText: 'Level 14',
            ),
            onResume: _noopRevision,
            onStartNew: _noopRevision,
          ),
          prepare: (tester) async {
            await tester.tap(find.byKey(const ValueKey('checkpointStartNew')));
            await tester.pump();
          },
        ),
        (
          name: 'checkpoint_empty',
          child: CheckpointResumeCard(
            checkpoint: null,
            onResume: _noopRevision,
          ),
          prepare: null,
        ),
      ];

  for (final entry in cases) {
    testWidgets('Save recovery ${entry.name} golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await runGoldenMatrix(
        tester,
        (_) => Padding(padding: const EdgeInsets.all(16), child: entry.child),
        goldenBaseName: 'save_recovery_${entry.name}',
      );
      if (entry.prepare != null) {
        const targetKey = ValueKey('save_recovery_confirmation_target');
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
            'goldens/save_recovery_${entry.name}_confirm_baseline.png',
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });
  }
}

Future<void> _noop() async {}

Future<void> _noopRevision(String revision) async {}

Future<void> _noopResolve(
  SaveConflictChoice choice,
  String localRevision,
  String cloudRevision,
) async {}

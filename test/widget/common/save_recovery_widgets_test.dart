import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

void main() {
  testWidgets('cloud status retry shows safe error and disables offline', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CloudSaveStatusCard(
            status: CloudSaveStatus.ready,
            onSync: () async {
              calls++;
              throw StateError('private save payload');
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('cloudSaveSync')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Sync failed. Try again.'), findsOneWidget);
    expect(find.textContaining('private save payload'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CloudSaveStatusCard(
            status: CloudSaveStatus.offline,
            onSync: () async => calls++,
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<CommonButton>(find.byKey(const ValueKey('cloudSaveSync')))
          .onTap,
      isNull,
    );
    expect(calls, 1);
  });

  testWidgets('cloud status prevents overlapping actions', (tester) async {
    final completer = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CloudSaveStatusCard(
            status: CloudSaveStatus.ready,
            onSync: () {
              calls++;
              return completer.future;
            },
          ),
        ),
      ),
    );
    final button = find.byKey(const ValueKey('cloudSaveSync'));
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    expect(calls, 1);
    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('conflict cancel never resolves and confirm carries revisions', (
    tester,
  ) async {
    SaveConflictChoice? resolved;
    String? localRevision;
    String? cloudRevision;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaveConflictPicker(
            local: SaveConflictSummary(
              revision: 'local-r1',
              savedAtText: 'Device copy',
              progressText: 'Level 8',
            ),
            cloud: SaveConflictSummary(
              revision: 'cloud-r2',
              savedAtText: 'Cloud copy',
              progressText: 'Level 12',
            ),
            onResolve: (choice, local, cloud) async {
              resolved = choice;
              localRevision = local;
              cloudRevision = cloud;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('saveConflict_cloud')));
    await tester.pump();
    expect(find.text('Keep: Cloud'), findsOneWidget);
    expect(find.text('Replace: This device'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('saveConflictCancel')));
    await tester.pump();
    expect(resolved, isNull);

    await tester.tap(find.byKey(const ValueKey('saveConflict_local')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('saveConflictConfirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('saveConflictConfirm')), findsNothing);
    expect(resolved, SaveConflictChoice.local);
    expect(localRevision, 'local-r1');
    expect(cloudRevision, 'cloud-r2');
  });

  testWidgets('conflict callback failure requires a fresh selection', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaveConflictPicker(
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
            onResolve: (_, _, _) async {
              calls++;
              throw StateError('private payload');
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('saveConflict_local')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('saveConflictConfirm')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(
      find.text('Could not apply this choice. Select again to retry.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('saveConflictConfirm')), findsNothing);
    expect(find.textContaining('private payload'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('saveConflict_local')));
    await tester.pump();
    expect(find.byKey(const ValueKey('saveConflictConfirm')), findsOneWidget);
  });

  testWidgets('conflict revision update during callback ignores stale result', (
    tester,
  ) async {
    final completer = Completer<void>();
    final local = SaveConflictSummary(
      revision: 'local-r1',
      savedAtText: 'Device copy',
      progressText: 'Level 8',
    );
    final cloud = SaveConflictSummary(
      revision: 'cloud-r1',
      savedAtText: 'Cloud copy',
      progressText: 'Level 12',
    );
    Widget build(SaveConflictSummary nextCloud) => MaterialApp(
      home: Scaffold(
        body: SaveConflictPicker(
          local: local,
          cloud: nextCloud,
          onResolve: (_, _, _) => completer.future,
        ),
      ),
    );
    await tester.pumpWidget(build(cloud));
    await tester.tap(find.byKey(const ValueKey('saveConflict_local')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('saveConflictConfirm')));
    await tester.pump();
    expect(
      tester
          .widget<CommonButton>(
            find.byKey(const ValueKey('saveConflict_local')),
          )
          .onTap,
      isNull,
    );
    await tester.pumpWidget(
      build(
        SaveConflictSummary(
          revision: 'cloud-r2',
          savedAtText: 'Later cloud copy',
          progressText: 'Level 13',
        ),
      ),
    );
    completer.completeError(StateError('stale private error'));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Could not apply this choice. Select again to retry.'),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('saveConflictConfirm')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conflict revision update invalidates old selection', (
    tester,
  ) async {
    final local = SaveConflictSummary(
      revision: 'local-r1',
      savedAtText: 'Device copy',
      progressText: 'Level 8',
    );
    final cloud = SaveConflictSummary(
      revision: 'cloud-r1',
      savedAtText: 'Cloud copy',
      progressText: 'Level 9',
    );
    var calls = 0;
    Widget build(SaveConflictSummary nextCloud) => MaterialApp(
      home: Scaffold(
        body: SaveConflictPicker(
          local: local,
          cloud: nextCloud,
          onResolve: (_, _, _) async => calls++,
        ),
      ),
    );
    await tester.pumpWidget(build(cloud));
    await tester.tap(find.byKey(const ValueKey('saveConflict_local')));
    await tester.pump();
    await tester.pumpWidget(
      build(
        SaveConflictSummary(
          revision: 'cloud-r2',
          savedAtText: 'New cloud copy',
          progressText: 'Level 10',
        ),
      ),
    );
    expect(find.byKey(const ValueKey('saveConflictConfirm')), findsNothing);
    expect(calls, 0);
  });

  testWidgets('checkpoint start-new requires confirmation; empty is inert', (
    tester,
  ) async {
    var resumeCalls = 0;
    var startCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckpointResumeCard(
            checkpoint: null,
            onResume: (_) async => resumeCalls++,
            onStartNew: (_) async => startCalls++,
          ),
        ),
      ),
    );
    expect(find.text('No checkpoint available'), findsOneWidget);
    expect(find.byKey(const ValueKey('checkpointResume')), findsNothing);
    expect(resumeCalls, 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckpointResumeCard(
            checkpoint: CheckpointSummary(
              revision: 'checkpoint-r3',
              savedAtText: 'Today',
              progressText: 'Level 14',
            ),
            onResume: (_) async => resumeCalls++,
            onStartNew: (_) async => startCalls++,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('checkpointStartNew')));
    await tester.pump();
    expect(startCalls, 0);
    await tester.tap(find.byKey(const ValueKey('checkpointCancel')));
    await tester.pump();
    expect(startCalls, 0);
    await tester.tap(find.byKey(const ValueKey('checkpointStartNew')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('checkpointConfirm')));
    await tester.pumpAndSettle();
    expect(startCalls, 1);
    expect(resumeCalls, 0);
  });

  testWidgets('checkpoint resume passes revision and unmount ignores result', (
    tester,
  ) async {
    final completer = Completer<void>();
    String? resumedRevision;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckpointResumeCard(
            checkpoint: CheckpointSummary(
              revision: 'checkpoint-r7',
              savedAtText: 'Today',
              progressText: 'Level 14',
            ),
            onResume: (revision) {
              resumedRevision = revision;
              return completer.future;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('checkpointResume')));
    await tester.pump();
    expect(resumedRevision, 'checkpoint-r7');
    await tester.pumpWidget(const SizedBox.shrink());
    completer.completeError(StateError('stale failure'));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('summary and status constructors reject invalid boundary values', () {
    expect(
      () =>
          CloudSaveStatusCard(status: CloudSaveStatus.ready, pendingCount: -1),
      throwsArgumentError,
    );
    expect(
      () => CloudSaveStatusCard(status: CloudSaveStatus.ready, title: ' '),
      throwsArgumentError,
    );
    expect(
      () => SaveConflictSummary(
        revision: ' ',
        savedAtText: 'Today',
        progressText: 'Level 1',
      ),
      throwsArgumentError,
    );
    expect(
      () => SaveConflictSummary(
        revision: 'r1',
        savedAtText: ' ',
        progressText: 'Level 1',
      ),
      throwsArgumentError,
    );
    expect(
      () => CheckpointSummary(
        revision: 'r1',
        savedAtText: 'Today',
        progressText: ' ',
      ),
      throwsArgumentError,
    );
    expect(
      () => CheckpointResumeCard(
        checkpoint: null,
        onResume: (_) async {},
        title: ' ',
      ),
      throwsArgumentError,
    );
  });

  testWidgets('cloud status covers every state and external busy gate', (
    tester,
  ) async {
    for (final (status, label) in [
      (CloudSaveStatus.ready, 'Ready to sync'),
      (CloudSaveStatus.syncing, 'Syncing'),
      (CloudSaveStatus.synced, 'Synced'),
      (CloudSaveStatus.offline, 'Offline'),
      (CloudSaveStatus.error, 'Sync failed. Try again.'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CloudSaveStatusCard(
              status: status,
              busy: status == CloudSaveStatus.ready,
              pendingCount: 3,
              lastSyncText: 'Today',
              onSync: () async {},
            ),
          ),
        ),
      );
      expect(
        find.text(status == CloudSaveStatus.ready ? 'Syncing' : label),
        findsOneWidget,
      );
      final button = tester.widget<CommonButton>(
        find.byKey(const ValueKey('cloudSaveSync')),
      );
      expect(
        button.onTap == null,
        status == CloudSaveStatus.offline ||
            status == CloudSaveStatus.syncing ||
            status == CloudSaveStatus.ready,
      );
      expect(find.text('Pending changes: 3'), findsOneWidget);
    }
  });

  testWidgets('conflict cloud choice carries cloud revision direction', (
    tester,
  ) async {
    SaveConflictChoice? choice;
    String? localRevision;
    String? cloudRevision;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaveConflictPicker(
            local: SaveConflictSummary(
              revision: 'local-r9',
              savedAtText: 'Device',
              progressText: 'Level 4',
            ),
            cloud: SaveConflictSummary(
              revision: 'cloud-r10',
              savedAtText: 'Cloud',
              progressText: 'Level 10',
            ),
            onResolve: (nextChoice, local, cloud) async {
              choice = nextChoice;
              localRevision = local;
              cloudRevision = cloud;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('saveConflict_cloud')));
    await tester.pump();
    expect(find.text('Keep: Cloud'), findsOneWidget);
    expect(find.text('Replace: This device'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('saveConflictConfirm')));
    await tester.pumpAndSettle();
    expect(choice, SaveConflictChoice.cloud);
    expect(localRevision, 'local-r9');
    expect(cloudRevision, 'cloud-r10');
  });

  testWidgets('checkpoint external busy blocks resume and start-new', (
    tester,
  ) async {
    var resumeCalls = 0;
    var startCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckpointResumeCard(
            checkpoint: CheckpointSummary(
              revision: 'checkpoint-r4',
              savedAtText: 'Today',
              progressText: 'Level 6',
            ),
            busy: true,
            onResume: (_) async => resumeCalls++,
            onStartNew: (_) async => startCalls++,
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<CommonButton>(find.byKey(const ValueKey('checkpointResume')))
          .onTap,
      isNull,
    );
    expect(
      tester
          .widget<CommonButton>(
            find.byKey(const ValueKey('checkpointStartNew')),
          )
          .onTap,
      isNull,
    );
    expect(resumeCalls, 0);
    expect(startCalls, 0);
  });

  testWidgets(
    'checkpoint failure hides exception and requires reconfirmation',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CheckpointResumeCard(
              checkpoint: CheckpointSummary(
                revision: 'checkpoint-r5',
                savedAtText: 'Today',
                progressText: 'Level 7',
              ),
              onResume: (_) async {},
              onStartNew: (_) async {
                calls++;
                throw StateError('private payload');
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('checkpointStartNew')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('checkpointConfirm')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Action failed. Try again.'), findsOneWidget);
      expect(find.textContaining('private payload'), findsNothing);
      expect(find.byKey(const ValueKey('checkpointConfirm')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('checkpointStartNew')));
      await tester.pump();
      expect(find.byKey(const ValueKey('checkpointConfirm')), findsOneWidget);
    },
  );

  testWidgets('all recovery cards fit 320dp at 200% text in RTL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                CloudSaveStatusCard(
                  status: CloudSaveStatus.error,
                  pendingCount: 12,
                  lastSyncText: 'Last synced a long time ago',
                  onSync: () async {},
                ),
                SaveConflictPicker(
                  local: SaveConflictSummary(
                    revision: 'local-r1',
                    savedAtText: 'This device, yesterday evening',
                    progressText: 'Level 128 with 4,200 stars',
                  ),
                  cloud: SaveConflictSummary(
                    revision: 'cloud-r1',
                    savedAtText: 'Cloud, this morning',
                    progressText: 'Level 140 with 3,900 stars',
                  ),
                  onResolve: (_, _, _) async {},
                ),
                CheckpointResumeCard(
                  checkpoint: CheckpointSummary(
                    revision: 'checkpoint-r1',
                    savedAtText: 'Saved a few minutes ago',
                    progressText: 'Level 14 with three moves left',
                  ),
                  onResume: (_) async {},
                  onStartNew: (_) async {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final cloudChoice = find.byKey(const ValueKey('saveConflict_cloud'));
    await tester.ensureVisible(cloudChoice);
    await tester.tap(cloudChoice);
    await tester.pump();
    final startNew = find.byKey(const ValueKey('checkpointStartNew'));
    await tester.ensureVisible(startNew);
    await tester.tap(startNew);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('recovery actions expose labeled button semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  CloudSaveStatusCard(
                    status: CloudSaveStatus.ready,
                    onSync: () async {},
                  ),
                  CheckpointResumeCard(
                    checkpoint: CheckpointSummary(
                      revision: 'checkpoint-r1',
                      savedAtText: 'Today',
                      progressText: 'Level 14',
                    ),
                    onResume: (_) async {},
                    onStartNew: (_) async {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      for (final label in ['Sync now', 'Resume', 'Start new game']) {
        final button = find.byWidgetPredicate(
          (widget) => widget is CommonButton && widget.label == label,
        );
        expect(
          tester.getSemantics(button),
          matchesSemantics(
            label: label,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('checkpoint busy transition cancels pending confirmation', (
    tester,
  ) async {
    var calls = 0;
    Widget build({required bool busy}) => MaterialApp(
      home: Scaffold(
        body: CheckpointResumeCard(
          checkpoint: CheckpointSummary(
            revision: 'checkpoint-r1',
            savedAtText: 'Today',
            progressText: 'Level 8',
          ),
          busy: busy,
          onResume: (_) async {},
          onStartNew: (_) async => calls++,
        ),
      ),
    );
    await tester.pumpWidget(build(busy: false));
    await tester.tap(find.byKey(const ValueKey('checkpointStartNew')));
    await tester.pump();
    expect(find.byKey(const ValueKey('checkpointConfirm')), findsOneWidget);
    await tester.pumpWidget(build(busy: true));
    await tester.pumpWidget(build(busy: false));
    expect(find.byKey(const ValueKey('checkpointConfirm')), findsNothing);
    expect(calls, 0);
  });

  testWidgets('conflict busy transition cancels pending selection', (
    tester,
  ) async {
    Widget build({required bool busy}) => MaterialApp(
      home: Scaffold(
        body: SaveConflictPicker(
          local: SaveConflictSummary(
            revision: 'local-r1',
            savedAtText: 'Device',
            progressText: 'Level 8',
          ),
          cloud: SaveConflictSummary(
            revision: 'cloud-r1',
            savedAtText: 'Cloud',
            progressText: 'Level 9',
          ),
          busy: busy,
          onResolve: (_, _, _) async {},
        ),
      ),
    );
    await tester.pumpWidget(build(busy: false));
    await tester.tap(find.byKey(const ValueKey('saveConflict_local')));
    await tester.pump();
    await tester.pumpWidget(build(busy: true));
    await tester.pumpWidget(build(busy: false));
    expect(find.byKey(const ValueKey('saveConflictConfirm')), findsNothing);
  });

  testWidgets('checkpoint revision update cancels pending confirmation', (
    tester,
  ) async {
    final first = CheckpointSummary(
      revision: 'checkpoint-r1',
      savedAtText: 'Today',
      progressText: 'Level 8',
    );
    var calls = 0;
    Widget build(CheckpointSummary? summary) => MaterialApp(
      home: Scaffold(
        body: CheckpointResumeCard(
          checkpoint: summary,
          onResume: (_) async {},
          onStartNew: (_) async => calls++,
        ),
      ),
    );
    await tester.pumpWidget(build(first));
    await tester.tap(find.byKey(const ValueKey('checkpointStartNew')));
    await tester.pump();
    await tester.pumpWidget(
      build(
        CheckpointSummary(
          revision: 'checkpoint-r2',
          savedAtText: 'Later',
          progressText: 'Level 9',
        ),
      ),
    );
    expect(find.byKey(const ValueKey('checkpointConfirm')), findsNothing);
    expect(calls, 0);
  });
}

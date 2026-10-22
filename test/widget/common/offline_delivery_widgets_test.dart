import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

void main() {
  test('summary constructors reject unsafe boundary values', () {
    for (final count in [-1, -20]) {
      expect(
        () => OutboxQueueStatusCard(
          pendingCount: count,
          manualReviewCount: 0,
          status: OutboxQueueStatus.idle,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => OutboxConflictSummary(
        reference: ' ',
        localLabel: 'Local update',
        remoteLabel: 'Remote update',
      ),
      throwsArgumentError,
    );
    expect(
      () => OutboxConflictSummary(
        reference: 'safe-ref',
        localLabel: ' ',
        remoteLabel: 'Remote update',
      ),
      throwsArgumentError,
    );
    expect(
      () => OutboxConflictSummaryPanel(
        conflicts: [
          OutboxConflictSummary(
            reference: 'same-ref',
            localLabel: 'Local A',
            remoteLabel: 'Remote A',
          ),
          OutboxConflictSummary(
            reference: 'same-ref',
            localLabel: 'Local B',
            remoteLabel: 'Remote B',
          ),
        ],
        onResolve: (_, _) async {},
      ),
      throwsArgumentError,
    );
  });

  testWidgets('queue summary covers every state and offline/busy gate', (
    tester,
  ) async {
    for (final (status, label) in [
      (OutboxQueueStatus.idle, 'Waiting to sync'),
      (OutboxQueueStatus.draining, 'Syncing queued changes'),
      (OutboxQueueStatus.offline, 'Offline · changes stay on this device'),
      (OutboxQueueStatus.error, 'Sync could not finish. Try again later.'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutboxQueueStatusCard(
              pendingCount: 3,
              manualReviewCount: 1,
              status: status,
              onDrain: () async {},
            ),
          ),
        ),
      );
      expect(find.text(label), findsOneWidget);
      expect(find.text('Pending: 3 · Needs review: 1'), findsOneWidget);
      final button = tester.widget<CommonButton>(
        find.byKey(const ValueKey('outboxDrain')),
      );
      expect(
        button.onTap == null,
        status == OutboxQueueStatus.draining ||
            status == OutboxQueueStatus.offline,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OutboxQueueStatusCard(
            pendingCount: 1,
            manualReviewCount: 0,
            status: OutboxQueueStatus.idle,
            busy: true,
            onDrain: () async {},
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<CommonButton>(find.byKey(const ValueKey('outboxDrain')))
          .onTap,
      isNull,
    );
  });

  testWidgets('drain callback errors stay generic and retry on a fresh tap', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _QueueActionHost(
            onDrain: () async {
              attempts++;
              if (attempts == 1) throw StateError('private item payload');
            },
          ),
        ),
      ),
    );
    final drain = find.byKey(const ValueKey('outboxDrain'));
    await tester.tap(drain);
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.text('private item payload'), findsNothing);
    expect(find.text('Drain failed. Try again.'), findsOneWidget);
    await tester.tap(drain);
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets('conflict summary keeps payload and idempotency key private', (
    tester,
  ) async {
    const secretKey = 'player-2187.purchase-991';
    const secretPayload = 'raw-score-9182';
    OutboxConflictResolution? resolution;
    String? resolvedReference;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OutboxConflictSummaryPanel(
            conflicts: [
              OutboxConflictSummary(
                reference: 'conflict-opaque-a7',
                localLabel: 'Reward claim pending',
                remoteLabel: 'Remote already claimed',
                timestampText: 'Checked today',
              ),
            ],
            onResolve: (reference, value) async {
              resolvedReference = reference;
              resolution = value;
            },
          ),
        ),
      ),
    );

    final semanticsHandle = tester.ensureSemantics();
    try {
      expect(find.textContaining(secretKey), findsNothing);
      expect(find.textContaining(secretPayload), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('$secretKey|$secretPayload')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('outboxKeepLocal_conflict-opaque-a7')),
      );
      await tester.pump();
      expect(find.textContaining('retry delivery later'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('outboxConflictCancel_conflict-opaque-a7')),
      );
      await tester.pump();
      expect(resolvedReference, isNull);

      await tester.tap(
        find.byKey(const ValueKey('outboxAcceptRemote_conflict-opaque-a7')),
      );
      await tester.pump();
      expect(find.textContaining('does not undo'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('outboxConflictConfirm_conflict-opaque-a7')),
      );
      await tester.pumpAndSettle();
      expect(resolvedReference, 'conflict-opaque-a7');
      expect(resolution, OutboxConflictResolution.acceptRemote);
      expect(find.textContaining(secretKey), findsNothing);
      expect(find.textContaining(secretPayload), findsNothing);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('conflict busy and changed references invalidate selection', (
    tester,
  ) async {
    Widget build({required bool busy, required String reference}) =>
        MaterialApp(
          home: Scaffold(
            body: OutboxConflictSummaryPanel(
              conflicts: [
                OutboxConflictSummary(
                  reference: reference,
                  localLabel: 'Pending local change',
                  remoteLabel: 'Remote copy',
                ),
              ],
              busy: busy,
              onResolve: (_, _) async {},
            ),
          ),
        );
    await tester.pumpWidget(build(busy: false, reference: 'opaque-r1'));
    await tester.tap(find.byKey(const ValueKey('outboxKeepLocal_opaque-r1')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('outboxConflictConfirm_opaque-r1')),
      findsOneWidget,
    );
    await tester.pumpWidget(build(busy: true, reference: 'opaque-r1'));
    expect(
      find.byKey(const ValueKey('outboxConflictConfirm_opaque-r1')),
      findsNothing,
    );
    await tester.pumpWidget(build(busy: false, reference: 'opaque-r2'));
    expect(
      find.byKey(const ValueKey('outboxConflictConfirm_opaque-r2')),
      findsNothing,
    );
  });

  testWidgets('multiple conflicts resolve only selected opaque reference', (
    tester,
  ) async {
    final resolved = <String, OutboxConflictResolution>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OutboxConflictSummaryPanel(
            conflicts: [
              OutboxConflictSummary(
                reference: 'opaque-a',
                localLabel: 'Purchase receipt pending',
                remoteLabel: 'Remote receipt differs',
              ),
              OutboxConflictSummary(
                reference: 'opaque-b',
                localLabel: 'Reward delivery pending',
                remoteLabel: 'Remote reward differs',
              ),
            ],
            onResolve: (reference, resolution) async {
              resolved[reference] = resolution;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('outboxKeepLocal_opaque-a')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('outboxConflictConfirm_opaque-a')),
    );
    await tester.pumpAndSettle();
    expect(resolved, {'opaque-a': OutboxConflictResolution.keepLocal});
    expect(
      find.byKey(const ValueKey('outboxKeepLocal_opaque-b')),
      findsOneWidget,
    );
  });

  testWidgets('outbox widgets fit narrow RTL 200% and expose CTA semantics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final handle = tester.ensureSemantics();
    try {
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
                  OutboxQueueStatusCard(
                    pendingCount: 12,
                    manualReviewCount: 2,
                    status: OutboxQueueStatus.idle,
                    onDrain: () async {},
                  ),
                  OutboxConflictSummaryPanel(
                    conflicts: [
                      OutboxConflictSummary(
                        reference: 'safe-ref-1',
                        localLabel: 'A pending reward change with longer label',
                        remoteLabel: 'Remote reward status is different',
                      ),
                    ],
                    onResolve: (_, _) async {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final keepLocal = find.byKey(
        const ValueKey('outboxKeepLocal_safe-ref-1'),
      );
      await tester.ensureVisible(keepLocal);
      await tester.tap(keepLocal);
      await tester.pump();
      expect(tester.takeException(), isNull);
      final drainButton = find.byWidgetPredicate(
        (widget) => widget is CommonButton && widget.label == 'Sync now',
      );
      final semantics = tester.getSemantics(drainButton);
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      handle.dispose();
    }
  });
}

class _QueueActionHost extends StatefulWidget {
  const _QueueActionHost({required this.onDrain});

  final Future<void> Function() onDrain;

  @override
  State<_QueueActionHost> createState() => _QueueActionHostState();
}

class _QueueActionHostState extends State<_QueueActionHost> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _drain() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onDrain();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      OutboxQueueStatusCard(
        pendingCount: 1,
        manualReviewCount: 0,
        status: _failed ? OutboxQueueStatus.error : OutboxQueueStatus.idle,
        busy: _busy,
        onDrain: _drain,
      ),
      if (_failed) const Text('Drain failed. Try again.'),
    ],
  );
}

import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

void main() {
  final history = [
    ContentRevisionSummary(
      revision: 'opaque-revision-v3',
      version: 3,
      appliedAtText: 'Today',
      label: 'Spring event',
    ),
    ContentRevisionSummary(
      revision: 'opaque-revision-v4',
      version: 4,
      appliedAtText: 'Yesterday',
      label: 'Summer event',
    ),
  ];

  test('revision summaries and panel validate caller metadata', () {
    expect(
      () => ContentRevisionSummary(
        revision: ' ',
        version: 1,
        appliedAtText: 'Today',
        label: 'Event',
      ),
      throwsArgumentError,
    );
    expect(
      () => ContentRevisionSummary(
        revision: 'rev',
        version: -1,
        appliedAtText: 'Today',
        label: 'Event',
      ),
      throwsArgumentError,
    );
    expect(
      () => ContentRevisionHistoryPanel(
        revisions: history,
        currentRevision: 'missing',
        onRollback: (_) async {},
      ),
      throwsArgumentError,
    );
    expect(
      () => ContentRevisionHistoryPanel(
        revisions: [history.first, history.first],
        currentRevision: 'opaque-revision-v3',
        onRollback: (_) async {},
      ),
      throwsArgumentError,
    );
  });

  testWidgets('empty and current revisions have no rollback action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentRevisionHistoryPanel(
            revisions: const [],
            currentRevision: null,
            onRollback: (_) async {},
          ),
        ),
      ),
    );
    expect(find.text('No previous content revisions.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('contentRevisionSelect_opaque-revision-v3')),
      findsNothing,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentRevisionHistoryPanel(
            revisions: history,
            currentRevision: 'opaque-revision-v4',
            onRollback: (_) async {},
          ),
        ),
      ),
    );
    expect(find.text('Active'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('contentRevisionSelect_opaque-revision-v4')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('contentRevisionSelect_opaque-revision-v3')),
      findsOneWidget,
    );
  });

  testWidgets('confirm passes exact opaque revision; cancel stays inert', (
    tester,
  ) async {
    String? rolledBack;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentRevisionHistoryPanel(
            revisions: history,
            currentRevision: 'opaque-revision-v4',
            onRollback: (revision) async => rolledBack = revision,
          ),
        ),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('contentRevisionSelect_opaque-revision-v3')),
    );
    await tester.pump();
    expect(find.textContaining('active content'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('contentRevisionCancel_opaque-revision-v3')),
    );
    await tester.pump();
    expect(rolledBack, isNull);

    await tester.tap(
      find.byKey(const ValueKey('contentRevisionSelect_opaque-revision-v3')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('contentRevisionConfirm_opaque-revision-v3')),
    );
    await tester.pumpAndSettle();
    expect(rolledBack, 'opaque-revision-v3');
    expect(
      find.byKey(const ValueKey('contentRevisionConfirm_opaque-revision-v3')),
      findsNothing,
    );
  });

  testWidgets('callback failure is generic and requires a fresh selection', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentRevisionHistoryPanel(
            revisions: history,
            currentRevision: 'opaque-revision-v4',
            onRollback: (_) async {
              calls++;
              throw StateError('secret checksum and content body');
            },
          ),
        ),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('contentRevisionSelect_opaque-revision-v3')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('contentRevisionConfirm_opaque-revision-v3')),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(
      find.text('Could not restore this revision. Select again to retry.'),
      findsOneWidget,
    );
    expect(find.textContaining('secret checksum'), findsNothing);
    expect(find.textContaining('content body'), findsNothing);
    expect(
      find.byKey(const ValueKey('contentRevisionConfirm_opaque-revision-v3')),
      findsNothing,
    );
  });

  testWidgets('busy gate and revision metadata update clear selection', (
    tester,
  ) async {
    final completer = Completer<void>();
    Widget build({
      required List<ContentRevisionSummary> entries,
      required bool busy,
    }) => MaterialApp(
      home: Scaffold(
        body: ContentRevisionHistoryPanel(
          revisions: entries,
          currentRevision: 'opaque-revision-v4',
          busy: busy,
          onRollback: (_) => completer.future,
        ),
      ),
    );
    await tester.pumpWidget(build(entries: history, busy: false));
    await tester.tap(
      find.byKey(const ValueKey('contentRevisionSelect_opaque-revision-v3')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('contentRevisionConfirm_opaque-revision-v3')),
      findsOneWidget,
    );
    await tester.pumpWidget(build(entries: history, busy: true));
    expect(
      find.byKey(const ValueKey('contentRevisionConfirm_opaque-revision-v3')),
      findsNothing,
    );

    await tester.pumpWidget(build(entries: history, busy: false));
    await tester.tap(
      find.byKey(const ValueKey('contentRevisionSelect_opaque-revision-v3')),
    );
    await tester.pump();
    final changed = [
      ContentRevisionSummary(
        revision: 'opaque-revision-v3',
        version: 3,
        appliedAtText: 'Updated metadata',
        label: 'Spring event',
      ),
      history.last,
    ];
    await tester.pumpWidget(build(entries: changed, busy: false));
    expect(
      find.byKey(const ValueKey('contentRevisionConfirm_opaque-revision-v3')),
      findsNothing,
    );
    completer.complete();
  });

  testWidgets(
    'pending rollback locks actions and revision update ignores result',
    (tester) async {
      final completer = Completer<void>();
      final original = [history.first, history.last];
      Widget build(List<ContentRevisionSummary> revisions) => MaterialApp(
        home: Scaffold(
          body: ContentRevisionHistoryPanel(
            revisions: revisions,
            currentRevision: 'opaque-revision-v4',
            onRollback: (_) => completer.future,
          ),
        ),
      );
      await tester.pumpWidget(build(original));
      await tester.tap(
        find.byKey(const ValueKey('contentRevisionSelect_opaque-revision-v3')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('contentRevisionConfirm_opaque-revision-v3')),
      );
      await tester.pump();
      expect(
        tester
            .widget<CommonButton>(
              find.byKey(
                const ValueKey('contentRevisionConfirm_opaque-revision-v3'),
              ),
            )
            .onTap,
        isNull,
      );
      final changed = [
        ContentRevisionSummary(
          revision: 'opaque-revision-v3',
          version: 7,
          appliedAtText: 'Updated timestamp',
          label: 'Summer event',
        ),
        history.last,
      ];
      await tester.pumpWidget(build(changed));
      completer.completeError(StateError('stale private failure'));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Could not restore this revision. Select again to retry.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unmount during rollback ignores late failure', (tester) async {
    final completion = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentRevisionHistoryPanel(
            revisions: history,
            currentRevision: 'opaque-revision-v4',
            onRollback: (_) => completion.future,
          ),
        ),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('contentRevisionSelect_opaque-revision-v3')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('contentRevisionConfirm_opaque-revision-v3')),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    completion.completeError(StateError('private late error'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('revision identifiers and checksums are not displayed', (
    tester,
  ) async {
    const sensitive = 'secret-full-sha256-checksum';
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContentRevisionHistoryPanel(
              revisions: [
                ContentRevisionSummary(
                  revision: sensitive,
                  version: 4,
                  appliedAtText: 'Today',
                  label: 'Spring event',
                ),
              ],
              currentRevision: null,
              onRollback: (_) async {},
            ),
          ),
        ),
      );
      expect(find.textContaining(sensitive), findsNothing);
      expect(find.bySemanticsLabel(RegExp(sensitive)), findsNothing);
      expect(find.text('Version 4: Spring event'), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('revision panel fits 320dp at 200% RTL and has labeled actions', (
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
            body: ContentRevisionHistoryPanel(
              revisions: history,
              currentRevision: 'opaque-revision-v4',
              onRollback: (_) async {},
            ),
          ),
        ),
      );
      final action = find.byKey(
        const ValueKey('contentRevisionSelect_opaque-revision-v3'),
      );
      await tester.ensureVisible(action);
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSemantics(action)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      handle.dispose();
    }
  });
}

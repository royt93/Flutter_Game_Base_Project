import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/reward_audit_trail_panel.dart';
import 'package:roy_casual_kit/presentation/widgets/common/reward_plan_preview_card.dart';

Widget _host(Widget child, {bool rtl = false, double scale = 1}) => MaterialApp(
  builder: (context, c) => Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: c!,
    ),
  ),
  home: Scaffold(body: child),
);

final _lines = [
  RewardPlanPreviewLine(label: 'Coins', amountText: '+50'),
  RewardPlanPreviewLine(label: 'Energy', amountText: '+1'),
];

RewardPlanPreviewCard _plan({
  RewardPlanPreviewStatus status = RewardPlanPreviewStatus.ready,
  List<RewardPlanPreviewLine>? lines,
  Future<void> Function()? onConfirm,
  Future<void> Function()? onRefresh,
  VoidCallback? onCancel,
  bool busy = false,
}) => RewardPlanPreviewCard(
  lines: lines ?? _lines,
  status: status,
  onConfirm: onConfirm,
  onRefresh: onRefresh,
  onCancel: onCancel,
  busy: busy,
);

final _rows = [
  RewardAuditRow(
    sourceLabel: 'Daily login',
    timeText: 'Today',
    summaryText: '1 currency line',
    status: RewardAuditStatus.committed,
  ),
  RewardAuditRow(
    sourceLabel: 'Quest',
    timeText: 'Today',
    summaryText: '2 currency lines, 1 item',
    status: RewardAuditStatus.partial,
  ),
];

void main() {
  group('RewardPlanPreviewCard', () {
    test('validates copy and line text', () {
      expect(
        () => RewardPlanPreviewLine(label: ' ', amountText: '+1'),
        throwsArgumentError,
      );
      expect(
        () => RewardPlanPreviewLine(label: 'Coins', amountText: ''),
        throwsArgumentError,
      );
      expect(
        () => RewardPlanPreviewCard(
          lines: _lines,
          status: RewardPlanPreviewStatus.ready,
          title: ' ',
        ),
        throwsArgumentError,
      );
    });

    test('copies input lines', () {
      final mutable = [..._lines];
      final card = _plan(lines: mutable);
      mutable.clear();
      expect(card.lines, hasLength(2));
      expect(() => card.lines.add(_lines.first), throwsUnsupportedError);
    });

    testWidgets('shows each status label and the preview caveat', (
      tester,
    ) async {
      for (final (status, text) in [
        (RewardPlanPreviewStatus.ready, 'Ready to apply'),
        (
          RewardPlanPreviewStatus.stale,
          'Preview is out of date. Refresh before applying.',
        ),
        (RewardPlanPreviewStatus.executing, 'Applying rewards'),
        (RewardPlanPreviewStatus.applied, 'Rewards applied'),
        (RewardPlanPreviewStatus.failed, 'Rewards were not fully applied.'),
      ]) {
        await tester.pumpWidget(_host(_plan(status: status)));
        expect(find.text(text), findsOneWidget);
        expect(find.text('Coins: +50'), findsOneWidget);
        expect(
          find.text('A preview is not a grant. Availability may change.'),
          findsOneWidget,
        );
      }
    });

    testWidgets('empty plan cannot be confirmed', (tester) async {
      await tester.pumpWidget(_host(_plan(lines: [], onConfirm: () async {})));
      expect(find.text('No rewards in this preview.'), findsOneWidget);
      expect(
        tester
            .widget<CommonButton>(
              find.byKey(const ValueKey('rewardPlanConfirm')),
            )
            .onTap,
        isNull,
      );
    });

    testWidgets('confirm only enabled when ready; refresh only stale/failed', (
      tester,
    ) async {
      for (final (status, confirm, refresh) in [
        (RewardPlanPreviewStatus.ready, true, false),
        (RewardPlanPreviewStatus.stale, false, true),
        (RewardPlanPreviewStatus.executing, false, false),
        (RewardPlanPreviewStatus.applied, false, false),
        (RewardPlanPreviewStatus.failed, false, true),
      ]) {
        await tester.pumpWidget(
          _host(
            _plan(
              status: status,
              onConfirm: () async {},
              onRefresh: () async {},
            ),
          ),
        );
        final c = tester.widget<CommonButton>(
          find.byKey(const ValueKey('rewardPlanConfirm')),
        );
        expect(c.onTap != null, confirm, reason: '$status confirm');
        expect(
          find.byKey(const ValueKey('rewardPlanRefresh')),
          refresh ? findsOneWidget : findsNothing,
          reason: '$status refresh',
        );
      }
    });

    testWidgets('callback returning does not change displayed status', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(_host(_plan(onConfirm: () async => calls++)));
      await tester.tap(find.byKey(const ValueKey('rewardPlanConfirm')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Ready to apply'), findsOneWidget);
      expect(find.text('Rewards applied'), findsNothing);
    });

    testWidgets('in-flight lock blocks double tap; generic failure copy', (
      tester,
    ) async {
      final done = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        _host(
          _plan(
            onConfirm: () {
              calls++;
              return done.future;
            },
          ),
        ),
      );
      final action = find.byKey(const ValueKey('rewardPlanConfirm'));
      await tester.tap(action);
      await tester.pump();
      expect(tester.widget<CommonButton>(action).onTap, isNull);
      await tester.tap(action, warnIfMissed: false);
      expect(calls, 1);
      done.completeError(StateError('private plan fingerprint'));
      await tester.pumpAndSettle();
      expect(find.text('Action failed. Try again.'), findsOneWidget);
      expect(find.textContaining('fingerprint'), findsNothing);
    });

    testWidgets('new status ignores late error but keeps lock until done', (
      tester,
    ) async {
      final done = Completer<void>();
      await tester.pumpWidget(_host(_plan(onConfirm: () => done.future)));
      final action = find.byKey(const ValueKey('rewardPlanConfirm'));
      await tester.tap(action);
      await tester.pump();
      await tester.pumpWidget(
        _host(
          _plan(
            status: RewardPlanPreviewStatus.stale,
            onConfirm: () => done.future,
          ),
        ),
      );
      done.completeError(StateError('late'));
      await tester.pumpAndSettle();
      expect(find.text('Action failed. Try again.'), findsNothing);
    });

    testWidgets('changed lines clear a prior error', (tester) async {
      await tester.pumpWidget(
        _host(_plan(onConfirm: () async => throw StateError('x'))),
      );
      await tester.tap(find.byKey(const ValueKey('rewardPlanConfirm')));
      await tester.pumpAndSettle();
      expect(find.text('Action failed. Try again.'), findsOneWidget);
      await tester.pumpWidget(
        _host(
          _plan(
            lines: [RewardPlanPreviewLine(label: 'Gems', amountText: '+2')],
            onConfirm: () async => throw StateError('x'),
          ),
        ),
      );
      expect(find.text('Action failed. Try again.'), findsNothing);
    });

    testWidgets('unmount during action is safe', (tester) async {
      final done = Completer<void>();
      await tester.pumpWidget(_host(_plan(onConfirm: () => done.future)));
      await tester.tap(find.byKey(const ValueKey('rewardPlanConfirm')));
      await tester.pumpWidget(const SizedBox.shrink());
      done.completeError(StateError('late'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits 320dp at 200% RTL with accessible actions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            _plan(onConfirm: () async {}, onCancel: () {}),
            rtl: true,
            scale: 2,
          ),
        );
        final action = find.byKey(const ValueKey('rewardPlanConfirm'));
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
  });

  group('RewardAuditTrailPanel', () {
    test('validates cap, copy and row text', () {
      expect(
        () => RewardAuditTrailPanel(rows: _rows, maxVisibleRows: 0),
        throwsArgumentError,
      );
      expect(
        () => RewardAuditTrailPanel(rows: _rows, title: ' '),
        throwsArgumentError,
      );
      expect(
        () => RewardAuditRow(
          sourceLabel: '',
          timeText: 'Today',
          summaryText: 'x',
          status: RewardAuditStatus.pending,
        ),
        throwsArgumentError,
      );
    });

    test('copies input rows', () {
      final mutable = [..._rows];
      final panel = RewardAuditTrailPanel(rows: mutable);
      mutable.clear();
      expect(panel.rows, hasLength(2));
      expect(() => panel.rows.add(_rows.first), throwsUnsupportedError);
    });

    testWidgets('empty state and no resume action without callback', (
      tester,
    ) async {
      await tester.pumpWidget(_host(RewardAuditTrailPanel(rows: [])));
      expect(find.text('No reward transactions yet.'), findsOneWidget);
      expect(find.byKey(const ValueKey('rewardAuditResume')), findsNothing);
    });

    testWidgets('shows status wording without claiming completion', (
      tester,
    ) async {
      await tester.pumpWidget(_host(RewardAuditTrailPanel(rows: _rows)));
      expect(find.text('Committed'), findsOneWidget);
      expect(find.text('Partially applied'), findsOneWidget);
      expect(
        find.text('Summaries show recorded rewards, not per-line completion.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Retry attempts all unfinished transactions. Some may remain unfinished.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('caps to newest rows and reports hidden count', (tester) async {
      final rows = [
        for (var i = 0; i < 5; i++)
          RewardAuditRow(
            sourceLabel: 'Source $i',
            timeText: 'T$i',
            summaryText: 'Summary $i',
            status: RewardAuditStatus.committed,
          ),
      ];
      await tester.pumpWidget(
        _host(RewardAuditTrailPanel(rows: rows, maxVisibleRows: 2)),
      );
      expect(find.text('Older transactions hidden: 3'), findsOneWidget);
      expect(find.text('Source 4 · T4'), findsOneWidget);
      expect(find.text('Source 3 · T3'), findsOneWidget);
      expect(find.text('Source 2 · T2'), findsNothing);
    });

    testWidgets('resume disabled when everything is committed', (tester) async {
      await tester.pumpWidget(
        _host(
          RewardAuditTrailPanel(
            rows: [_rows.first],
            onResumePending: () async {},
          ),
        ),
      );
      expect(
        tester
            .widget<CommonButton>(
              find.byKey(const ValueKey('rewardAuditResume')),
            )
            .onTap,
        isNull,
      );
    });

    testWidgets('resume callback returning keeps rows unchanged', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _host(
          RewardAuditTrailPanel(
            rows: _rows,
            onResumePending: () async => calls++,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('rewardAuditResume')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Partially applied'), findsOneWidget);
    });

    testWidgets('in-flight lock and generic failure copy', (tester) async {
      final done = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        _host(
          RewardAuditTrailPanel(
            rows: _rows,
            onResumePending: () {
              calls++;
              return done.future;
            },
          ),
        ),
      );
      final action = find.byKey(const ValueKey('rewardAuditResume'));
      await tester.tap(action);
      await tester.pump();
      expect(tester.widget<CommonButton>(action).onTap, isNull);
      await tester.tap(action, warnIfMissed: false);
      expect(calls, 1);
      done.completeError(StateError('private transaction id'));
      await tester.pumpAndSettle();
      expect(find.text('Retry failed. Try again.'), findsOneWidget);
      expect(find.textContaining('transaction id'), findsNothing);
    });

    testWidgets('new rows ignore late error but keep lock until done', (
      tester,
    ) async {
      final done = Completer<void>();
      Widget build(List<RewardAuditRow> rows) => _host(
        RewardAuditTrailPanel(rows: rows, onResumePending: () => done.future),
      );
      await tester.pumpWidget(build(_rows));
      final action = find.byKey(const ValueKey('rewardAuditResume'));
      await tester.tap(action);
      await tester.pump();
      await tester.pumpWidget(build([_rows.last]));
      expect(tester.widget<CommonButton>(action).onTap, isNull);
      done.completeError(StateError('late'));
      await tester.pumpAndSettle();
      expect(find.text('Retry failed. Try again.'), findsNothing);
      expect(tester.widget<CommonButton>(action).onTap, isNotNull);
    });

    testWidgets('unmount during retry is safe', (tester) async {
      final done = Completer<void>();
      await tester.pumpWidget(
        _host(
          RewardAuditTrailPanel(
            rows: _rows,
            onResumePending: () => done.future,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('rewardAuditResume')));
      await tester.pumpWidget(const SizedBox.shrink());
      done.completeError(StateError('late'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits 320dp at 200% RTL with accessible retry', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            RewardAuditTrailPanel(rows: _rows, onResumePending: () async {}),
            rtl: true,
            scale: 2,
          ),
        );
        final action = find.byKey(const ValueKey('rewardAuditResume'));
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
  });
}

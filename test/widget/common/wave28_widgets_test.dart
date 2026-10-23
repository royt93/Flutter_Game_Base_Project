import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

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

void main() {
  group('AnalyticsQueueStatusCard', () {
    test('validates non-negative counts and non-blank drop reasons', () {
      expect(
        () => AnalyticsQueueSnapshot(
          pendingCount: -1,
          uploadedCount: 0,
          droppedCounts: const {},
        ),
        throwsArgumentError,
      );
      expect(
        () => AnalyticsQueueSnapshot(
          pendingCount: 0,
          uploadedCount: 0,
          droppedCounts: {' ': 1},
        ),
        throwsArgumentError,
      );
    });

    testWidgets(
      'shows counts and dropped reasons; hides flush without consent',
      (tester) async {
        final snapshot = AnalyticsQueueSnapshot(
          pendingCount: 12,
          uploadedCount: 88,
          droppedCounts: {'Rate limited': 4, 'Rejected': 1},
        );
        await tester.pumpWidget(
          _host(
            AnalyticsQueueStatusCard(
              snapshot: snapshot,
              consentGranted: false,
              onFlush: () async {},
            ),
          ),
        );
        expect(find.text('Pending: 12'), findsOneWidget);
        expect(find.text('Uploaded: 88'), findsOneWidget);
        expect(find.text('Dropped: 5'), findsOneWidget);
        expect(find.text('Rate limited: 4'), findsOneWidget);
        expect(find.text('Analytics consent not granted'), findsOneWidget);
        expect(find.byKey(const ValueKey('analyticsQueueFlush')), findsNothing);

        await tester.pumpWidget(
          _host(
            AnalyticsQueueStatusCard(
              snapshot: snapshot,
              consentGranted: true,
              onFlush: () async {},
            ),
          ),
        );
        expect(
          find.byKey(const ValueKey('analyticsQueueFlush')),
          findsOneWidget,
        );
      },
    );

    testWidgets('flush in-flight locks action and error copy is generic', (
      tester,
    ) async {
      final done = Completer<void>();
      await tester.pumpWidget(
        _host(
          AnalyticsQueueStatusCard(
            snapshot: AnalyticsQueueSnapshot(
              pendingCount: 3,
              uploadedCount: 0,
              droppedCounts: const {},
            ),
            onFlush: () => done.future,
          ),
        ),
      );
      final flush = find.byKey(const ValueKey('analyticsQueueFlush'));
      await tester.tap(flush);
      await tester.pump();
      expect(tester.widget<CommonButton>(flush).onTap, isNull);
      done.completeError(StateError('private queue token'));
      await tester.pumpAndSettle();
      expect(find.text('Upload failed. Try again.'), findsOneWidget);
      expect(find.textContaining('private queue token'), findsNothing);
    });

    testWidgets('fits 320dp at 200% RTL with labeled action', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            AnalyticsQueueStatusCard(
              snapshot: AnalyticsQueueSnapshot(
                pendingCount: 2,
                uploadedCount: 1,
                droppedCounts: const {},
              ),
              onFlush: () async {},
            ),
            rtl: true,
            scale: 2,
          ),
        );
        final action = find.byKey(const ValueKey('analyticsQueueFlush'));
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

  group('SaveRestorePreviewPanel', () {
    final slots = [
      RestoreSlotPreview(
        slotName: 'Hero Slot',
        lastPlayedText: 'Yesterday, 16:05',
        keyCount: 42,
      ),
    ];

    test('validates non-blank slot name and non-negative key count', () {
      expect(
        () => RestoreSlotPreview(
          slotName: ' ',
          lastPlayedText: 'Today',
          keyCount: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => RestoreSlotPreview(
          slotName: 'Slot',
          lastPlayedText: 'Today',
          keyCount: -1,
        ),
        throwsArgumentError,
      );
    });

    testWidgets('requires confirm to restore; cancel leaves state untouched', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _host(
          SaveRestorePreviewPanel(
            slots: slots,
            onConfirmRestore: () async => calls++,
          ),
        ),
      );
      expect(find.text('Hero Slot'), findsOneWidget);
      expect(find.text('Yesterday, 16:05 · 42 saved values'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('restorePreviewStart')));
      await tester.pump();
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      expect(calls, 0);

      await tester.tap(find.byKey(const ValueKey('restorePreviewCancel')));
      await tester.pump();
      expect(calls, 0);
      expect(find.byKey(const ValueKey('restorePreviewConfirm')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('restorePreviewStart')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('restorePreviewConfirm')));
      await tester.pumpAndSettle();
      expect(calls, 1);
    });

    testWidgets('empty state shows message and hides restore CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SaveRestorePreviewPanel(
            slots: const [],
            onConfirmRestore: () async {},
          ),
        ),
      );
      expect(find.text('This backup contains no save slots.'), findsOneWidget);
      expect(find.byKey(const ValueKey('restorePreviewStart')), findsNothing);
    });

    testWidgets('in-flight restore locks and errors are generic', (
      tester,
    ) async {
      final done = Completer<void>();
      await tester.pumpWidget(
        _host(
          SaveRestorePreviewPanel(
            slots: slots,
            onConfirmRestore: () => done.future,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('restorePreviewStart')));
      await tester.pump();
      final confirm = find.byKey(const ValueKey('restorePreviewConfirm'));
      await tester.tap(confirm);
      await tester.pump();
      expect(tester.widget<CommonButton>(confirm).onTap, isNull);
      done.completeError(StateError('private slot path /internal/save'));
      await tester.pumpAndSettle();
      expect(find.text('Restore failed. Try again.'), findsOneWidget);
      expect(find.textContaining('private slot path'), findsNothing);
    });

    testWidgets('fits 320dp at 200% RTL with labeled action', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            SaveRestorePreviewPanel(
              slots: slots,
              onConfirmRestore: () async {},
            ),
            rtl: true,
            scale: 2,
          ),
        );
        final action = find.byKey(const ValueKey('restorePreviewStart'));
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

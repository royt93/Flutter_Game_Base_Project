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
  group('MemoryWatchdogPanel', () {
    final rows = [
      for (var i = 0; i < 4; i++)
        WatchdogRow(
          kindLabel: 'Ticker',
          ownerText: 'Widget$i',
          ageText: '${i + 1}s',
          labelText: 'label-$i',
        ),
    ];

    test('rejects blank row data and non-positive cap', () {
      expect(
        () => WatchdogRow(kindLabel: 'Ticker', ownerText: ' ', ageText: '1s'),
        throwsArgumentError,
      );
      expect(
        () =>
            MemoryWatchdogPanel(orphans: [], recentlyDisposed: [], maxRows: 0),
        throwsArgumentError,
      );
    });

    testWidgets('shows empty states, caps rows and reports hidden count', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(MemoryWatchdogPanel(orphans: [], recentlyDisposed: [])),
      );
      expect(find.text('No leak candidates.'), findsOneWidget);
      expect(find.text('Nothing disposed yet.'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          MemoryWatchdogPanel(
            orphans: rows,
            recentlyDisposed: rows.take(1).toList(),
            maxRows: 2,
          ),
        ),
      );
      expect(find.text('+2 more hidden'), findsOneWidget);
      expect(find.textContaining('Widget0'), findsNWidgets(2));
      expect(find.textContaining('Widget1'), findsOneWidget);
      expect(find.textContaining('Widget2'), findsNothing);
      expect(
        find.text(
          'Debug detector only. It does not prevent leaks and reports nothing in release builds.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('refresh callback locks and hides errors', (tester) async {
      final done = Completer<void>();
      await tester.pumpWidget(
        _host(
          MemoryWatchdogPanel(
            orphans: [],
            recentlyDisposed: [],
            onRefresh: () => done.future,
          ),
        ),
      );
      final action = find.byKey(const ValueKey('watchdogRefresh'));
      await tester.tap(action);
      await tester.pump();
      expect(tester.widget<CommonButton>(action).onTap, isNull);
      done.completeError(StateError('private owner label'));
      await tester.pumpAndSettle();
      expect(find.text('Refresh failed. Try again.'), findsOneWidget);
      expect(find.textContaining('private owner'), findsNothing);
    });

    testWidgets('fits 320dp at 200% RTL with labeled refresh', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            MemoryWatchdogPanel(
              orphans: rows,
              recentlyDisposed: rows,
              onRefresh: () async {},
            ),
            rtl: true,
            scale: 2,
          ),
        );
        final action = find.byKey(const ValueKey('watchdogRefresh'));
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

  group('AnnouncementPreviewCard', () {
    test('rejects blank preview content', () {
      expect(
        () => AnnouncementPreviewCard(messageText: ' ', localeLabel: 'English'),
        throwsArgumentError,
      );
    });

    testWidgets('shows exact localized message and invokes caller preview', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _host(
          AnnouncementPreviewCard(
            messageText: 'Level 7 complete. 250 coins earned.',
            localeLabel: 'English',
            categoryLabel: 'Reward',
            throttleText: '1.5 seconds per category',
            onPreview: () async => calls++,
          ),
        ),
      );
      expect(find.text('Level 7 complete. 250 coins earned.'), findsOneWidget);
      expect(find.text('Language: English'), findsOneWidget);
      expect(find.text('Category: Reward'), findsOneWidget);
      expect(
        find.text('Repeat limit: 1.5 seconds per category'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('announcementPreview')));
      await tester.pumpAndSettle();
      expect(calls, 1);
    });

    testWidgets('busy locks and callback exception is hidden', (tester) async {
      await tester.pumpWidget(
        _host(
          AnnouncementPreviewCard(
            messageText: 'Safe message',
            localeLabel: 'English',
            onPreview: () async =>
                throw StateError('raw translation parameter'),
          ),
        ),
      );
      final action = find.byKey(const ValueKey('announcementPreview'));
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Preview failed. Try again.'), findsOneWidget);
      expect(find.textContaining('raw translation parameter'), findsNothing);
    });

    testWidgets('fits 320dp at 200% RTL with labeled preview', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            AnnouncementPreviewCard(
              messageText: 'A localized announcement for a screen reader.',
              localeLabel: 'Vietnamese',
              onPreview: () async {},
            ),
            rtl: true,
            scale: 2,
          ),
        );
        final action = find.byKey(const ValueKey('announcementPreview'));
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

  group('RewardedAdResultCard', () {
    test('rejects blank labels', () {
      expect(
        () => RewardedAdResultCard(
          status: RewardedAdStatus.idle,
          onWatch: () async {},
          title: ' ',
        ),
        throwsArgumentError,
      );
    });

    testWidgets('maps statuses honestly and only rewarded state shows reward', (
      tester,
    ) async {
      for (final (status, label) in [
        (RewardedAdStatus.idle, 'Watch an ad to earn a reward'),
        (RewardedAdStatus.notReady, 'No ad is ready yet. Try again soon.'),
        (RewardedAdStatus.loading, 'Loading ad'),
        (RewardedAdStatus.rewarded, 'Reward earned'),
        (RewardedAdStatus.cancelled, 'Ad closed early. No reward earned.'),
        (
          RewardedAdStatus.failed,
          'The ad could not be shown. No reward earned.',
        ),
      ]) {
        await tester.pumpWidget(
          _host(
            RewardedAdResultCard(
              status: status,
              rewardText: '50 coins',
              onWatch: () async {},
            ),
          ),
        );
        expect(find.text(label), findsOneWidget);
        expect(
          find.text('50 coins'),
          status == RewardedAdStatus.rewarded ? findsOneWidget : findsNothing,
        );
        expect(
          tester
              .widget<CommonButton>(
                find.byKey(const ValueKey('rewardedAdWatch')),
              )
              .onTap,
          status == RewardedAdStatus.idle ||
                  status == RewardedAdStatus.cancelled ||
                  status == RewardedAdStatus.failed
              ? isNotNull
              : isNull,
        );
      }
    });

    testWidgets('double tap calls once; exception hides detail', (
      tester,
    ) async {
      final done = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        _host(
          RewardedAdResultCard(
            status: RewardedAdStatus.idle,
            onWatch: () {
              calls++;
              return done.future;
            },
          ),
        ),
      );
      final action = find.byKey(const ValueKey('rewardedAdWatch'));
      await tester.tap(action);
      await tester.pump();
      expect(calls, 1);
      expect(tester.widget<CommonButton>(action).onTap, isNull);
      done.completeError(StateError('private ad response'));
      await tester.pumpAndSettle();
      expect(find.text('Action failed. Try again.'), findsOneWidget);
      expect(find.textContaining('private ad response'), findsNothing);
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
            RewardedAdResultCard(
              status: RewardedAdStatus.cancelled,
              onWatch: () async {},
            ),
            rtl: true,
            scale: 2,
          ),
        );
        final action = find.byKey(const ValueKey('rewardedAdWatch'));
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

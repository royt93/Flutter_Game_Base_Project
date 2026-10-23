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

final _options = [
  ReminderIntervalOption(id: 'daily', label: 'Every day'),
  ReminderIntervalOption(id: 'weekly', label: 'Every week'),
];

void main() {
  group('RemoteConfigHealthCard', () {
    test('validates counts and copy', () {
      expect(
        () => RemoteConfigHealthCard(
          source: RemoteConfigHealthSource.assetOnly,
          violationCount: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => RemoteConfigHealthCard(
          source: RemoteConfigHealthSource.assetOnly,
          violationCount: 0,
          title: ' ',
        ),
        throwsArgumentError,
      );
    });

    testWidgets('maps every source and shows only a violation count', (
      tester,
    ) async {
      for (final (source, label) in [
        (RemoteConfigHealthSource.unknown, 'Not checked yet'),
        (RemoteConfigHealthSource.assetOnly, 'Using bundled settings'),
        (RemoteConfigHealthSource.remoteMerged, 'Remote settings applied'),
        (
          RemoteConfigHealthSource.remoteFailed,
          'Using bundled fallback settings',
        ),
      ]) {
        await tester.pumpWidget(
          _host(RemoteConfigHealthCard(source: source, violationCount: 2)),
        );
        expect(find.text(label), findsOneWidget);
        expect(find.text('Schema violations: 2'), findsOneWidget);
        expect(find.textContaining('key'), findsNothing);
      }
    });

    testWidgets('refresh locks in flight and hides exception text', (
      tester,
    ) async {
      final done = Completer<void>();
      await tester.pumpWidget(
        _host(
          RemoteConfigHealthCard(
            source: RemoteConfigHealthSource.remoteFailed,
            violationCount: 0,
            onRefresh: () => done.future,
          ),
        ),
      );
      final action = find.byKey(const ValueKey('remoteConfigHealthRefresh'));
      await tester.tap(action);
      await tester.pump();
      expect(tester.widget<CommonButton>(action).onTap, isNull);
      done.completeError(StateError('private config key shop_price'));
      await tester.pumpAndSettle();
      expect(find.text('Refresh failed. Try again.'), findsOneWidget);
      expect(find.textContaining('shop_price'), findsNothing);
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
            RemoteConfigHealthCard(
              source: RemoteConfigHealthSource.remoteFailed,
              violationCount: 3,
              onRefresh: () async {},
            ),
            rtl: true,
            scale: 2,
          ),
        );
        final action = find.byKey(const ValueKey('remoteConfigHealthRefresh'));
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

  group('ReminderPreferencesPanel', () {
    test('validates options, selection and copy', () {
      expect(
        () => ReminderPreferencesPanel(
          intervalOptions: [],
          enabled: false,
          selectedId: null,
          onChanged: (_, _) async {},
        ),
        throwsArgumentError,
      );
      expect(
        () => ReminderPreferencesPanel(
          intervalOptions: _options,
          enabled: true,
          selectedId: 'missing',
          onChanged: (_, _) async {},
        ),
        throwsArgumentError,
      );
      expect(
        () => ReminderIntervalOption(id: ' ', label: 'Every day'),
        throwsArgumentError,
      );
    });

    testWidgets('sends caller preference and does not promise delivery', (
      tester,
    ) async {
      (bool, String?)? saved;
      await tester.pumpWidget(
        _host(
          ReminderPreferencesPanel(
            intervalOptions: _options,
            enabled: false,
            selectedId: 'daily',
            onChanged: (enabled, id) async => saved = (enabled, id),
          ),
        ),
      );
      expect(
        find.text(
          'Delivery depends on notification permission. The system may delay or skip reminders.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('scheduled'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('reminderEnabled')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('reminderInterval_weekly')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('reminderPreferencesSave')));
      await tester.pumpAndSettle();
      expect(saved, (true, 'weekly'));
    });

    testWidgets('interval choices stay disabled until reminders are enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ReminderPreferencesPanel(
            intervalOptions: _options,
            enabled: false,
            selectedId: 'daily',
            onChanged: (_, _) async {},
          ),
        ),
      );
      expect(
        tester
            .widget<RadioListTile<String>>(
              find.byKey(const ValueKey('reminderInterval_weekly')),
            )
            .enabled,
        isFalse,
      );
    });

    testWidgets('save failure is generic and in-flight locks save', (
      tester,
    ) async {
      final done = Completer<void>();
      await tester.pumpWidget(
        _host(
          ReminderPreferencesPanel(
            intervalOptions: _options,
            enabled: true,
            selectedId: 'daily',
            onChanged: (_, _) => done.future,
          ),
        ),
      );
      final save = find.byKey(const ValueKey('reminderPreferencesSave'));
      await tester.tap(save);
      await tester.pump();
      expect(tester.widget<CommonButton>(save).onTap, isNull);
      done.completeError(StateError('private notification channel'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save preference. Try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('notification channel'), findsNothing);
    });

    testWidgets('fits 320dp at 200% RTL with labeled save action', (
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
            ReminderPreferencesPanel(
              intervalOptions: _options,
              enabled: true,
              selectedId: 'daily',
              onChanged: (_, _) async {},
            ),
            rtl: true,
            scale: 2,
          ),
        );
        final action = find.byKey(const ValueKey('reminderPreferencesSave'));
        await tester.ensureVisible(action);
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getSemantics(action)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    });
  });

  group('ConnectivityStatusCard', () {
    test('validates queue count and copy', () {
      expect(
        () => ConnectivityStatusCard(
          state: ConnectivityCardState.online,
          queuedCount: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => ConnectivityStatusCard(
          state: ConnectivityCardState.online,
          queuedCount: 0,
          title: ' ',
        ),
        throwsArgumentError,
      );
    });

    testWidgets('shows every state, queue count and automatic-drain note', (
      tester,
    ) async {
      for (final (state, label) in [
        (ConnectivityCardState.offline, 'Offline'),
        (ConnectivityCardState.checking, 'Checking connection'),
        (ConnectivityCardState.online, 'Online'),
        (ConnectivityCardState.degraded, 'Connection unstable'),
      ]) {
        await tester.pumpWidget(
          _host(ConnectivityStatusCard(state: state, queuedCount: 5)),
        );
        expect(find.text(label), findsOneWidget);
        expect(find.text('Waiting tasks: 5'), findsOneWidget);
        expect(
          find.text('Waiting tasks run automatically when back online.'),
          findsOneWidget,
        );
      }
    });

    testWidgets(
      'retry only appears for offline or degraded and is generic on error',
      (tester) async {
        for (final (state, visible) in [
          (ConnectivityCardState.offline, true),
          (ConnectivityCardState.checking, false),
          (ConnectivityCardState.online, false),
          (ConnectivityCardState.degraded, true),
        ]) {
          await tester.pumpWidget(
            _host(
              ConnectivityStatusCard(
                state: state,
                queuedCount: 0,
                onRetry: () async => throw StateError('private endpoint url'),
              ),
            ),
          );
          expect(
            find.byKey(const ValueKey('connectivityStatusRetry')),
            visible ? findsOneWidget : findsNothing,
          );
        }
        await tester.pumpWidget(
          _host(
            ConnectivityStatusCard(
              state: ConnectivityCardState.offline,
              queuedCount: 0,
              onRetry: () async => throw StateError('private endpoint url'),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('connectivityStatusRetry')));
        await tester.pumpAndSettle();
        expect(find.text('Retry failed. Try again.'), findsOneWidget);
        expect(find.textContaining('endpoint url'), findsNothing);
      },
    );

    testWidgets('fits 320dp at 200% RTL with labeled retry', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            ConnectivityStatusCard(
              state: ConnectivityCardState.offline,
              queuedCount: 4,
              onRetry: () async {},
            ),
            rtl: true,
            scale: 2,
          ),
        );
        final action = find.byKey(const ValueKey('connectivityStatusRetry'));
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

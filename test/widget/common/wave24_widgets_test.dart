import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/consent_state_service.dart';
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

final _consentItems = [
  ConsentPreferenceItem(
    id: 'analytics',
    label: 'Analytics',
    description: 'Help improve the game.',
    status: ConsentStatus.unknown,
  ),
  ConsentPreferenceItem(
    id: 'personalization',
    label: 'Personalization',
    description: 'Tailor content to your play.',
    status: ConsentStatus.granted,
  ),
];

void main() {
  group('ConsentPreferencesPanel', () {
    test('rejects empty, duplicate and blank input', () {
      expect(
        () => ConsentPreferencesPanel(items: [], onChanged: (_, _) async {}),
        throwsArgumentError,
      );
      expect(
        () => ConsentPreferencesPanel(
          items: [_consentItems.first, _consentItems.first],
          onChanged: (_, _) async {},
        ),
        throwsArgumentError,
      );
      expect(
        () => ConsentPreferenceItem(
          id: ' ',
          label: 'Analytics',
          description: 'copy',
          status: ConsentStatus.unknown,
        ),
        throwsArgumentError,
      );
    });

    testWidgets('shows explicit statuses and sends exact caller id/choice', (
      tester,
    ) async {
      final calls = <(String, ConsentStatus)>[];
      await tester.pumpWidget(
        _host(
          ConsentPreferencesPanel(
            items: _consentItems,
            onChanged: (id, status) async => calls.add((id, status)),
          ),
        ),
      );
      expect(find.text('Not decided yet'), findsOneWidget);
      expect(find.text('Allowed'), findsOneWidget);
      expect(
        tester
            .widget<CommonButton>(
              find.byKey(const ValueKey('consentAllow_personalization')),
            )
            .onTap,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('consentDeny_analytics')));
      await tester.pumpAndSettle();
      expect(calls, [(('analytics', ConsentStatus.denied))]);
    });

    testWidgets('busy locks all choices; callback failure is generic', (
      tester,
    ) async {
      Widget build({bool busy = false, bool fail = false}) => _host(
        ConsentPreferencesPanel(
          items: _consentItems,
          busy: busy,
          onChanged: (_, _) async {
            if (fail) throw StateError('private provider response');
          },
        ),
      );
      await tester.pumpWidget(build(busy: true));
      expect(
        tester
            .widget<CommonButton>(
              find.byKey(const ValueKey('consentAllow_analytics')),
            )
            .onTap,
        isNull,
      );
      await tester.pumpWidget(build(fail: true));
      await tester.tap(find.byKey(const ValueKey('consentAllow_analytics')));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save your choice. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('private provider'), findsNothing);
    });

    testWidgets('in-flight callback locks both categories', (tester) async {
      final done = Completer<void>();
      await tester.pumpWidget(
        _host(
          ConsentPreferencesPanel(
            items: _consentItems,
            onChanged: (_, _) => done.future,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('consentAllow_analytics')));
      await tester.pump();
      expect(
        tester
            .widget<CommonButton>(
              find.byKey(const ValueKey('consentDeny_personalization')),
            )
            .onTap,
        isNull,
      );
      done.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('fits narrow 200% RTL and exposes labeled choices', (
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
            ConsentPreferencesPanel(
              items: _consentItems,
              onChanged: (_, _) async {},
            ),
            rtl: true,
            scale: 2,
          ),
        );
        final action = find.byKey(const ValueKey('consentDeny_analytics'));
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

  group('SyncStatusCard', () {
    test('rejects blank copy', () {
      expect(
        () => SyncStatusCard(
          status: SyncStatus.idle,
          onSync: () async {},
          title: ' ',
        ),
        throwsArgumentError,
      );
    });

    testWidgets('shows external status and invokes retry callback', (
      tester,
    ) async {
      var calls = 0;
      Widget build(SyncStatus status) => _host(
        SyncStatusCard(
          status: status,
          lastSyncedText: 'Yesterday',
          onSync: () async => calls++,
        ),
      );
      await tester.pumpWidget(build(SyncStatus.failed));
      expect(find.text('Sync failed. Try again.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('syncStatusAction')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Last synced: Yesterday'), findsOneWidget);

      await tester.pumpWidget(build(SyncStatus.synced));
      expect(find.text('Up to date'), findsOneWidget);
    });

    testWidgets('busy and syncing state disable action', (tester) async {
      for (final (status, busy) in [
        (SyncStatus.syncing, false),
        (SyncStatus.idle, true),
      ]) {
        await tester.pumpWidget(
          _host(
            SyncStatusCard(status: status, busy: busy, onSync: () async {}),
          ),
        );
        expect(
          tester
              .widget<CommonButton>(
                find.byKey(const ValueKey('syncStatusAction')),
              )
              .onTap,
          isNull,
        );
      }
    });

    testWidgets('callback failure uses generic message, not exception', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SyncStatusCard(
            status: SyncStatus.idle,
            onSync: () async => throw StateError('raw server token'),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('syncStatusAction')));
      await tester.pumpAndSettle();
      expect(find.text('Action failed. Try again.'), findsOneWidget);
      expect(find.textContaining('raw server token'), findsNothing);
    });

    testWidgets('in-flight sync blocks repeat action and unmount is safe', (
      tester,
    ) async {
      final done = Completer<void>();
      await tester.pumpWidget(
        _host(
          SyncStatusCard(status: SyncStatus.idle, onSync: () => done.future),
        ),
      );
      final action = find.byKey(const ValueKey('syncStatusAction'));
      await tester.tap(action);
      await tester.pump();
      expect(tester.widget<CommonButton>(action).onTap, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      done.completeError(StateError('late'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits narrow 200% RTL', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            SyncStatusCard(status: SyncStatus.failed, onSync: () async {}),
            rtl: true,
            scale: 2,
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    });
  });

  group('BatterySaverIndicator', () {
    test('rejects battery percentage outside range', () {
      expect(
        () => BatterySaverIndicator(active: true, batteryPercent: 101),
        throwsArgumentError,
      );
      expect(
        () => BatterySaverIndicator(active: true, batteryPercent: -1),
        throwsArgumentError,
      );
    });

    testWidgets('hidden while inactive; reports active state and percent', (
      tester,
    ) async {
      await tester.pumpWidget(_host(BatterySaverIndicator(active: false)));
      expect(find.text('Battery saver on'), findsNothing);
      await tester.pumpWidget(
        _host(BatterySaverIndicator(active: true, batteryPercent: 17)),
      );
      expect(find.text('Battery saver on'), findsOneWidget);
      expect(find.text('Battery: 17%'), findsOneWidget);
    });

    testWidgets('fits narrow 200% RTL', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            BatterySaverIndicator(active: true, batteryPercent: 12),
            rtl: true,
            scale: 2,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getSemantics(find.byType(BatterySaverIndicator))
              .getSemanticsData()
              .label,
          contains('Battery saver on'),
        );
      } finally {
        handle.dispose();
      }
    });
  });
}

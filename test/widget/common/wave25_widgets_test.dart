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

final _killItems = [
  KillSwitchItem(
    id: 'event-shop',
    label: 'Event shop',
    killed: false,
    sourceLabel: 'Bundled default',
  ),
  KillSwitchItem(
    id: 'remote-event',
    label: 'Remote event',
    killed: true,
    sourceLabel: 'Remote configuration',
  ),
  KillSwitchItem(
    id: 'local-event',
    label: 'Local event',
    killed: true,
    sourceLabel: 'Local override',
    localOverride: true,
  ),
];

void main() {
  group('RemoteKillSwitchPanel', () {
    test('rejects duplicate ids, blank text and invalid override', () {
      expect(
        () => RemoteKillSwitchPanel(
          items: [_killItems.first, _killItems.first],
          onKillLocally: (_) async {},
          onClearOverride: (_) async {},
        ),
        throwsArgumentError,
      );
      expect(
        () => KillSwitchItem(
          id: 'x',
          label: 'Feature',
          killed: false,
          sourceLabel: 'Default',
          localOverride: true,
        ),
        throwsArgumentError,
      );
      expect(
        () => KillSwitchItem(
          id: 'x',
          label: ' ',
          killed: false,
          sourceLabel: 'Default',
        ),
        throwsArgumentError,
      );
    });

    testWidgets('requires confirm for local kill; never offers remote clear', (
      tester,
    ) async {
      final killed = <String>[];
      final cleared = <String>[];
      await tester.pumpWidget(
        _host(
          RemoteKillSwitchPanel(
            items: _killItems,
            onKillLocally: (id) async => killed.add(id),
            onClearOverride: (id) async => cleared.add(id),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('killSwitchClear_remote-event')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('killSwitchSelect_remote-event')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('killSwitchClear_local-event')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('killSwitchSelect_event-shop')),
      );
      await tester.pump();
      expect(
        find.textContaining('cannot enable a remotely killed feature'),
        findsOneWidget,
      );
      expect(killed, isEmpty);
      await tester.tap(
        find.byKey(const ValueKey('killSwitchCancel_event-shop')),
      );
      await tester.pump();
      expect(killed, isEmpty);

      await tester.tap(
        find.byKey(const ValueKey('killSwitchSelect_event-shop')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('killSwitchConfirm_event-shop')),
      );
      await tester.pumpAndSettle();
      expect(killed, ['event-shop']);

      await tester.tap(
        find.byKey(const ValueKey('killSwitchClear_local-event')),
      );
      await tester.pumpAndSettle();
      expect(cleared, ['local-event']);
    });

    testWidgets('busy locks actions; callback exception is hidden', (
      tester,
    ) async {
      Widget build({bool busy = false, bool fail = false}) => _host(
        RemoteKillSwitchPanel(
          items: [_killItems.first],
          busy: busy,
          onKillLocally: (_) async {
            if (fail) throw StateError('remote token/private reason');
          },
          onClearOverride: (_) async {},
        ),
      );
      await tester.pumpWidget(build(busy: true));
      expect(
        tester
            .widget<CommonButton>(
              find.byKey(const ValueKey('killSwitchSelect_event-shop')),
            )
            .onTap,
        isNull,
      );
      await tester.pumpWidget(build(fail: true));
      await tester.tap(
        find.byKey(const ValueKey('killSwitchSelect_event-shop')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('killSwitchConfirm_event-shop')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Could not apply this change. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('remote token'), findsNothing);
      expect(find.textContaining('private reason'), findsNothing);
    });

    testWidgets('in-flight actions lock and unmount ignores late failure', (
      tester,
    ) async {
      final done = Completer<void>();
      await tester.pumpWidget(
        _host(
          RemoteKillSwitchPanel(
            items: [_killItems.first],
            onKillLocally: (_) => done.future,
            onClearOverride: (_) async {},
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('killSwitchSelect_event-shop')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('killSwitchConfirm_event-shop')),
      );
      await tester.pump();
      expect(
        tester
            .widget<CommonButton>(
              find.byKey(const ValueKey('killSwitchConfirm_event-shop')),
            )
            .onTap,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      done.completeError(StateError('late'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits 320dp at 200% RTL with labeled actions', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            RemoteKillSwitchPanel(
              items: _killItems,
              onKillLocally: (_) async {},
              onClearOverride: (_) async {},
            ),
            rtl: true,
            scale: 2,
          ),
        );
        final select = find.byKey(
          const ValueKey('killSwitchSelect_event-shop'),
        );
        await tester.ensureVisible(select);
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getSemantics(select)
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

  group('PlatformCapabilityMatrix', () {
    test('rejects empty, duplicate and blank rows', () {
      expect(
        () => PlatformCapabilityMatrix(platformLabel: 'Android', rows: []),
        throwsArgumentError,
      );
      expect(
        () => PlatformCapabilityMatrix(
          platformLabel: 'Android',
          rows: [
            PlatformCapabilityRow(label: 'Haptics', supported: true),
            PlatformCapabilityRow(label: 'Haptics', supported: false),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => PlatformCapabilityRow(label: ' ', supported: false),
        throwsArgumentError,
      );
    });

    testWidgets('shows both supported and unsupported text and disclaimer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          PlatformCapabilityMatrix(
            platformLabel: 'Web',
            rows: [
              PlatformCapabilityRow(label: 'Haptics', supported: false),
              PlatformCapabilityRow(label: 'Shaders', supported: true),
            ],
          ),
        ),
      );
      expect(find.text('Haptics'), findsOneWidget);
      expect(find.text('Not supported'), findsOneWidget);
      expect(find.text('Shaders'), findsOneWidget);
      expect(find.text('Supported'), findsOneWidget);
      expect(
        find.text('Defaults for this platform, not a live check.'),
        findsOneWidget,
      );
    });

    testWidgets('fits 320dp at 200% RTL with semantics', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            PlatformCapabilityMatrix(
              platformLabel: 'Desktop',
              rows: [
                PlatformCapabilityRow(label: 'Haptics', supported: false),
                PlatformCapabilityRow(label: 'Audio', supported: true),
              ],
            ),
            rtl: true,
            scale: 2,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.bySemanticsLabel('Haptics: Not supported'), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });
  });

  group('DeepLinkResultCard', () {
    test('rejects blank display copy', () {
      expect(
        () => DeepLinkResultCard(
          status: DeepLinkResultStatus.dispatched,
          title: ' ',
        ),
        throwsArgumentError,
      );
    });

    testWidgets('shows generic outcomes, never URI, parameters or errors', (
      tester,
    ) async {
      const privateUri = 'myapp://open?token=secret-value';
      const rawError = 'No route matches $privateUri';
      for (final (status, expected) in [
        (DeepLinkResultStatus.dispatched, 'Link opened'),
        (DeepLinkResultStatus.queued, 'Link will open when the app is ready'),
        (DeepLinkResultStatus.duplicate, 'Link was already handled'),
        (DeepLinkResultStatus.rejected, 'This link is not valid'),
        (DeepLinkResultStatus.handlerFailed, 'The link could not be completed'),
      ]) {
        await tester.pumpWidget(
          _host(
            DeepLinkResultCard(
              status: status,
              summaryText: 'Safe caller summary',
            ),
          ),
        );
        expect(find.text(expected), findsOneWidget);
        expect(find.text('Safe caller summary'), findsOneWidget);
        expect(find.textContaining(privateUri), findsNothing);
        expect(find.textContaining(rawError), findsNothing);
        expect(find.textContaining('secret-value'), findsNothing);
      }
    });

    testWidgets(
      'retry is limited to rejected/handler failure and errors generic',
      (tester) async {
        var calls = 0;
        await tester.pumpWidget(
          _host(
            DeepLinkResultCard(
              status: DeepLinkResultStatus.dispatched,
              onRetry: () async => calls++,
            ),
          ),
        );
        expect(find.byKey(const ValueKey('deepLinkRetry')), findsNothing);

        await tester.pumpWidget(
          _host(
            DeepLinkResultCard(
              status: DeepLinkResultStatus.rejected,
              onRetry: () async {
                calls++;
                throw StateError('secret callback detail');
              },
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('deepLinkRetry')));
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(find.text('Action failed. Try again.'), findsOneWidget);
        expect(find.textContaining('secret callback detail'), findsNothing);
      },
    );

    testWidgets('busy blocks retry; unmount ignores late exception', (
      tester,
    ) async {
      final done = Completer<void>();
      await tester.pumpWidget(
        _host(
          DeepLinkResultCard(
            status: DeepLinkResultStatus.handlerFailed,
            busy: true,
            onRetry: () => done.future,
          ),
        ),
      );
      expect(
        tester
            .widget<CommonButton>(find.byKey(const ValueKey('deepLinkRetry')))
            .onTap,
        isNull,
      );
      await tester.pumpWidget(
        _host(
          DeepLinkResultCard(
            status: DeepLinkResultStatus.handlerFailed,
            onRetry: () => done.future,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('deepLinkRetry')));
      await tester.pump();
      expect(
        tester
            .widget<CommonButton>(find.byKey(const ValueKey('deepLinkRetry')))
            .onTap,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      done.completeError(StateError('late secret'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits 320dp at 200% RTL with labeled retry', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            DeepLinkResultCard(
              status: DeepLinkResultStatus.handlerFailed,
              onRetry: () async {},
            ),
            rtl: true,
            scale: 2,
          ),
        );
        final retry = find.byKey(const ValueKey('deepLinkRetry'));
        await tester.ensureVisible(retry);
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getSemantics(retry)
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

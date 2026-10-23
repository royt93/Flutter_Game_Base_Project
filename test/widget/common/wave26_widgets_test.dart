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
  group('SessionTimelineInspector', () {
    test('validates row text and cap', () {
      expect(
        () => SessionTimelineRow(offsetText: ' ', phaseLabel: 'Playing'),
        throwsArgumentError,
      );
      expect(
        () => SessionTimelineInspector(rows: [], maxVisibleRows: 0),
        throwsArgumentError,
      );
    });

    testWidgets('shows bounded, caller-filtered rows and empty state', (
      tester,
    ) async {
      await tester.pumpWidget(_host(SessionTimelineInspector(rows: [])));
      expect(find.text('No session transitions yet.'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          SessionTimelineInspector(
            rows: [
              for (var i = 0; i < 4; i++)
                SessionTimelineRow(
                  offsetText: '00:0$i',
                  phaseLabel: 'Phase $i',
                  detailText: i == 3 ? 'Caller-safe summary' : null,
                ),
            ],
            maxVisibleRows: 2,
            durationText: '00:04',
            terminalLabel: 'Won',
          ),
        ),
      );
      expect(find.text('Duration: 00:04'), findsOneWidget);
      expect(find.text('Won'), findsOneWidget);
      expect(find.text('Older transitions hidden. (2)'), findsOneWidget);
      expect(find.text('00:02 · Phase 2'), findsOneWidget);
      expect(find.text('00:03 · Phase 3'), findsOneWidget);
      expect(find.text('Caller-safe summary'), findsOneWidget);
      expect(find.text('00:00 · Phase 0'), findsNothing);
    });

    testWidgets('fits 320dp at 200% RTL', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            SessionTimelineInspector(
              rows: [
                SessionTimelineRow(
                  offsetText: '00:12',
                  phaseLabel: 'Paused',
                  detailText: 'User',
                ),
              ],
            ),
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

  group('EconomyCertificateStatusCard', () {
    test('rejects blank caller text', () {
      expect(
        () => EconomyCertificateStatusCard(
          status: EconomyCertificateCardStatus.unverified,
          title: ' ',
        ),
        throwsArgumentError,
      );
    });

    testWidgets('all verification statuses render only caller-safe summary', (
      tester,
    ) async {
      const sensitive = 'secret-HMAC-9999-coins';
      for (final (status, label) in [
        (EconomyCertificateCardStatus.unverified, 'Not checked yet'),
        (EconomyCertificateCardStatus.valid, 'Signature checks out'),
        (EconomyCertificateCardStatus.tampered, 'Could not be verified'),
        (
          EconomyCertificateCardStatus.clockSuspicious,
          'Signature checks out, but the device clock looked altered when it was issued',
        ),
      ]) {
        await tester.pumpWidget(
          _host(
            EconomyCertificateStatusCard(
              status: status,
              summaryText: 'Certificate status only',
            ),
          ),
        );
        expect(find.text(label), findsOneWidget);
        expect(find.text('Certificate status only'), findsOneWidget);
        expect(find.textContaining(sensitive), findsNothing);
      }
    });

    testWidgets('retry locks in flight and hides thrown exception', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _host(
          EconomyCertificateStatusCard(
            status: EconomyCertificateCardStatus.tampered,
            onVerifyAgain: () async {
              calls++;
              throw StateError('private balances secret');
            },
          ),
        ),
      );
      final verify = find.byKey(const ValueKey('economyCertificateVerify'));
      await tester.tap(verify);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Verification failed. Try again.'), findsOneWidget);
      expect(find.textContaining('private balances'), findsNothing);
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
            EconomyCertificateStatusCard(
              status: EconomyCertificateCardStatus.clockSuspicious,
              onVerifyAgain: () async {},
            ),
            rtl: true,
            scale: 2,
          ),
        );
        final action = find.byKey(const ValueKey('economyCertificateVerify'));
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

  group('GuardrailStatusPanel', () {
    test('validates row text', () {
      expect(
        () => GuardrailStatusRow(
          featureLabel: 'Feature',
          metricLabel: 'Crash rate',
          state: GuardrailRowState.ok,
          boundsText: ' ',
        ),
        throwsArgumentError,
      );
    });

    testWidgets('shows status and only caller-opted metrics', (tester) async {
      await tester.pumpWidget(
        _host(
          GuardrailStatusPanel(
            rows: [
              GuardrailStatusRow(
                featureLabel: 'Shop rollout',
                metricLabel: 'Crash rate',
                state: GuardrailRowState.violated,
              ),
              GuardrailStatusRow(
                featureLabel: 'Quest rollout',
                metricLabel: 'Failure rate',
                state: GuardrailRowState.ok,
                boundsText: 'under 2%',
                currentText: '0.4%',
              ),
              GuardrailStatusRow(
                featureLabel: 'Offer rollout',
                metricLabel: 'Load time',
                state: GuardrailRowState.noData,
              ),
            ],
          ),
        ),
      );
      expect(find.textContaining('Rolled back on this device'), findsOneWidget);
      expect(find.textContaining('Within limits'), findsOneWidget);
      expect(find.textContaining('No data yet'), findsOneWidget);
      expect(find.text('Limits: under 2%'), findsOneWidget);
      expect(find.text('Current: 0.4%'), findsOneWidget);
    });

    testWidgets('fits 320dp at 200% RTL', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            GuardrailStatusPanel(
              rows: [
                GuardrailStatusRow(
                  featureLabel: 'Rollout',
                  metricLabel: 'Error rate',
                  state: GuardrailRowState.violated,
                ),
              ],
            ),
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
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance('wave26_widgets_golden_test.dart');
  tearDownAll(() => goldenFileComparator = previous);

  Widget build(String state) => switch (state) {
    'timeline_empty' => SessionTimelineInspector(rows: []),
    'timeline_history' => SessionTimelineInspector(
      rows: [
        SessionTimelineRow(offsetText: '00:00', phaseLabel: 'Ready'),
        SessionTimelineRow(offsetText: '00:03', phaseLabel: 'Playing'),
        SessionTimelineRow(offsetText: '00:17', phaseLabel: 'Won'),
      ],
      durationText: '00:17',
      terminalLabel: 'Won',
    ),
    'certificate_valid' => EconomyCertificateStatusCard(
      status: EconomyCertificateCardStatus.valid,
      summaryText: 'Signature verified',
    ),
    'certificate_tampered' => EconomyCertificateStatusCard(
      status: EconomyCertificateCardStatus.tampered,
    ),
    'certificate_suspicious' => EconomyCertificateStatusCard(
      status: EconomyCertificateCardStatus.clockSuspicious,
    ),
    'certificate_unverified' => EconomyCertificateStatusCard(
      status: EconomyCertificateCardStatus.unverified,
      onVerifyAgain: () async {},
    ),
    'guardrails' => GuardrailStatusPanel(
      rows: [
        GuardrailStatusRow(
          featureLabel: 'Shop',
          metricLabel: 'Crash rate',
          state: GuardrailRowState.violated,
        ),
        GuardrailStatusRow(
          featureLabel: 'Quest',
          metricLabel: 'Failure rate',
          state: GuardrailRowState.ok,
          boundsText: '< 2%',
          currentText: '0.5%',
        ),
      ],
    ),
    _ => GuardrailStatusPanel(rows: []),
  };

  for (final state in [
    'timeline_empty',
    'timeline_history',
    'certificate_valid',
    'certificate_tampered',
    'certificate_suspicious',
    'certificate_unverified',
    'guardrails',
    'guardrails_empty',
  ]) {
    testWidgets('Wave 26 $state golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final variant in defaultGoldenMatrix()) {
        await tester.pumpWidget(const SizedBox.shrink());
        const target = ValueKey('wave26Golden');
        await runGoldenMatrix(
          tester,
          (_) => Padding(
            key: target,
            padding: const EdgeInsets.all(16),
            child: build(state),
          ),
          matrix: [variant],
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(target),
          matchesGoldenFile('goldens/wave26_${state}_${variant.name}.png'),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance('wave31_widgets_golden_test.dart');
  tearDownAll(() => goldenFileComparator = previous);

  final lines = [
    RewardPlanPreviewLine(label: 'Coins', amountText: '+50'),
    RewardPlanPreviewLine(label: 'Energy', amountText: '+1'),
  ];
  final rows = [
    RewardAuditRow(
      sourceLabel: 'Daily login',
      timeText: 'Yesterday',
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

  Widget build(String state) => switch (state) {
    'plan_ready' => RewardPlanPreviewCard(
      lines: lines,
      status: RewardPlanPreviewStatus.ready,
      onConfirm: () async {},
    ),
    'plan_stale' => RewardPlanPreviewCard(
      lines: lines,
      status: RewardPlanPreviewStatus.stale,
      onConfirm: () async {},
      onRefresh: () async {},
    ),
    'replay_not_checked' => ReplayVerificationResultCard(
      status: ReplayVerificationStatus.notChecked,
      checkedOutcomeCount: 0,
    ),
    'replay_matched' => ReplayVerificationResultCard(
      status: ReplayVerificationStatus.matched,
      checkedOutcomeCount: 3,
      rngStatus: ReplayRngCheckStatus.matched,
      onVerifyAgain: () async {},
    ),
    'replay_diverged' => ReplayVerificationResultCard(
      status: ReplayVerificationStatus.diverged,
      checkedOutcomeCount: 3,
      divergenceIndex: 1,
      rngStatus: ReplayRngCheckStatus.mismatched,
      rngMismatchCount: 2,
    ),
    'replay_invalid' => ReplayVerificationResultCard(
      status: ReplayVerificationStatus.invalid,
      checkedOutcomeCount: 0,
      onVerifyAgain: () async {},
    ),
    'audit_empty' => RewardAuditTrailPanel(rows: []),
    'audit_unresolved' => RewardAuditTrailPanel(
      rows: rows,
      onResumePending: () async {},
    ),
    _ => RewardAuditTrailPanel(
      rows: [rows.first],
      onResumePending: () async {},
    ),
  };

  for (final state in [
    'plan_ready',
    'plan_stale',
    'replay_not_checked',
    'replay_matched',
    'replay_diverged',
    'replay_invalid',
    'audit_empty',
    'audit_unresolved',
    'audit_resolved',
  ]) {
    testWidgets('Wave 31 $state golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final variant in defaultGoldenMatrix()) {
        await tester.pumpWidget(const SizedBox.shrink());
        const target = ValueKey('wave31Golden');
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
          matchesGoldenFile('goldens/wave31_${state}_${variant.name}.png'),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance('wave32_widgets_golden_test.dart');
  tearDownAll(() => goldenFileComparator = previous);

  OnboardingFlowRow flow(
    String id,
    String label, {
    bool seen = false,
    bool next = false,
    int priority = 0,
  }) => OnboardingFlowRow(
    flowId: id,
    label: label,
    priority: priority,
    version: 1,
    isSeen: seen,
    isNext: next,
  );

  ExperimentVariantRow experiment({
    String assigned = 'control',
    bool overridden = false,
  }) => ExperimentVariantRow(
    experimentKey: 'shop_layout',
    label: 'Shop layout',
    assignedVariant: assigned,
    availableVariants: ['control', 'wide'],
    isOverridden: overridden,
  );

  Widget build(String state) => switch (state) {
    'onboarding_empty' => OnboardingFlowQueueCard(rows: []),
    'onboarding_queue' => OnboardingFlowQueueCard(
      rows: [
        flow('a', 'Welcome tour', next: true, priority: 10),
        flow('b', 'Shop tip', priority: 5),
        flow('c', 'First win', seen: true),
      ],
      onMarkSeen: (_) async {},
    ),
    'onboarding_done' => OnboardingFlowQueueCard(
      rows: [flow('a', 'Welcome tour', seen: true)],
    ),
    'experiment_empty' => ExperimentVariantAssignmentCard(rows: []),
    'experiment_readonly' => ExperimentVariantAssignmentCard(
      rows: [experiment()],
    ),
    'experiment_override' => ExperimentVariantAssignmentCard(
      rows: [experiment(assigned: 'wide', overridden: true)],
      onSelectOverride: (_, _) async {},
    ),
    _ => ExperimentVariantAssignmentCard(
      rows: [experiment()],
      onSelectOverride: (_, _) async {},
    ),
  };

  for (final state in [
    'onboarding_empty',
    'onboarding_queue',
    'onboarding_done',
    'experiment_empty',
    'experiment_readonly',
    'experiment_override',
    'experiment_choices',
  ]) {
    testWidgets('Wave 32 $state golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final variant in defaultGoldenMatrix()) {
        await tester.pumpWidget(const SizedBox.shrink());
        const target = ValueKey('wave32Golden');
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
          matchesGoldenFile('goldens/wave32_${state}_${variant.name}.png'),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}

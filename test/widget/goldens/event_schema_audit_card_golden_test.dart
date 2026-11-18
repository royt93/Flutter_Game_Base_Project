import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance(
    'event_schema_audit_card_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);

  Widget build(String state) => switch (state) {
    'empty' => EventSchemaAuditCard(
      snapshot: EventSchemaAuditSnapshot(
        totalValidations: 0,
        rejectedCount: 0,
        redactedCount: 0,
      ),
    ),
    'healthy' => EventSchemaAuditCard(
      snapshot: EventSchemaAuditSnapshot(
        totalValidations: 42,
        rejectedCount: 0,
        redactedCount: 0,
      ),
    ),
    _ => EventSchemaAuditCard(
      snapshot: EventSchemaAuditSnapshot(
        totalValidations: 42,
        rejectedCount: 3,
        redactedCount: 5,
      ),
    ),
  };

  for (final state in ['empty', 'healthy', 'rejected']) {
    testWidgets('Wave 33 schema audit $state golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final variant in defaultGoldenMatrix()) {
        await tester.pumpWidget(const SizedBox.shrink());
        const target = ValueKey('eventSchemaAuditGolden');
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
          matchesGoldenFile(
            'goldens/event_schema_audit_${state}_${variant.name}.png',
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}

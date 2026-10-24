import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('experiment overrides follow the actual build mode', (
    tester,
  ) async {
    var calls = 0;
    final control = ExperimentVariantRow(
      experimentKey: 'layout',
      label: 'Layout',
      assignedVariant: 'Control',
      availableVariants: ['Control', 'Wide'],
    );
    final overridden = ExperimentVariantRow(
      experimentKey: 'layout',
      label: 'Layout',
      assignedVariant: 'Wide',
      availableVariants: ['Control', 'Wide'],
      isOverridden: true,
    );

    for (final row in [control, overridden]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExperimentVariantAssignmentCard(
              rows: [row],
              onSelectOverride: (_, _) async => calls++,
            ),
          ),
        ),
      );
      expect(
        find.text('Assigned variant: ${row.assignedVariant}'),
        findsOneWidget,
      );
      if (kReleaseMode) {
        expect(find.byType(CommonButton), findsNothing);
        expect(calls, 0);
      } else {
        final action = row.isOverridden
            ? find.byKey(const ValueKey('experimentClear_0'))
            : find.byKey(const ValueKey('experimentOverride_0_1'));
        await tester.tap(action);
        await tester.pump(const Duration(milliseconds: 100));
        expect(calls, row.isOverridden ? 2 : 1);
      }
    }
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/support_diagnostics_card.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance(
    'support_diagnostics_card_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);
  const states = ['normal', 'truncated', 'errors'];
  for (final state in states) {
    testWidgets('SupportDiagnosticsCard $state golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await runGoldenMatrix(
        tester,
        (_) => SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SupportDiagnosticsCard(
              summary: SupportDiagnosticsSummary(
                appVersion: '1.2.3',
                generatedAtText: 'Today, 10:30',
                sections: const ['health', 'replay', 'config'],
                truncated: state == 'truncated',
                errors: state == 'errors'
                    ? const {'logs': 'section omitted'}
                    : const {},
              ),
              onShare: () async {},
              preview: const Text('Redacted preview'),
            ),
          ),
        ),
        goldenBaseName: 'support_diagnostics_card_$state',
      );
    });
  }
}

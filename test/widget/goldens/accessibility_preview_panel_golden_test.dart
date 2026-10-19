import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/accessibility_preview_panel.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance(
    'accessibility_preview_panel_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);
  const states = ['baseline', 'textScale-1.3', 'textScale-2.0', 'highlight'];
  for (final state in states) {
    testWidgets('AccessibilityPreviewPanel $state golden matrix', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final target = GlobalKey();
      await runGoldenMatrix(
        tester,
        (_) => SizedBox(
          height: 480,
          child: AccessibilityPreviewPanel(
            maxHeight: 480,
            targets: [target],
            preview: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topLeft,
                child: TextButton(
                  key: target,
                  onPressed: () {},
                  child: const Text('Tap target sample'),
                ),
              ),
            ),
            onClose: () {},
          ),
        ),
        goldenBaseName: 'accessibility_preview_panel_$state',
      );
    });
  }
}

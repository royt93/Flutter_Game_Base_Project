import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/contrast_preview_card.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance(
    'contrast_preview_card_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);
  const states = [
    'normal_pass',
    'normal_fail',
    'large_pass',
    'custom_threshold',
  ];
  for (final state in states) {
    testWidgets('ContrastPreviewCard $state golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pass = state == 'normal_pass';
      final large = state == 'large_pass';
      final custom = state == 'custom_threshold';
      await runGoldenMatrix(
        tester,
        (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: ContrastPreviewCard(
            foreground: pass || large ? Colors.black : Colors.white,
            background: pass || large ? Colors.white : const Color(0xFF777777),
            sampleText: 'Sample text for contrast preview',
            largeText: large,
            threshold: custom ? 7 : null,
            onTap: () {},
          ),
        ),
        goldenBaseName: 'contrast_preview_card_$state',
      );
    });
  }
}

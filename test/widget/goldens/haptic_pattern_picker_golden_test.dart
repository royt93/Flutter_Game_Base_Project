import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/haptic_pattern_picker.dart';
import 'package:roy_casual_kit/core/haptic_choreographer.dart';
import 'package:roy_casual_kit/core/haptics.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

final _options = [
  HapticPatternOption(
    id: 'soft',
    label: 'Soft',
    pattern: HapticPattern([const HapticPulse(level: HapticLevel.light)]),
  ),
  HapticPatternOption(
    id: 'reward',
    label: 'Reward',
    pattern: HapticPattern.reward,
  ),
  HapticPatternOption(
    id: 'error',
    label: 'Error',
    pattern: HapticPattern.error,
  ),
];

void main() {
  final previous = installGoldenTolerance(
    'haptic_pattern_picker_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);
  const states = ['normal', 'selected', 'busy', 'disabled'];
  for (final state in states) {
    testWidgets('HapticPatternPicker $state golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await runGoldenMatrix(
        tester,
        (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: HapticPatternPicker(
            options: _options,
            selectedId: state == 'selected' ? 'reward' : 'soft',
            busy: state == 'busy',
            hapticsEnabled: state != 'disabled',
            onSelect: (_) {},
            onPreview: (_) {},
          ),
        ),
        goldenBaseName: 'haptic_pattern_picker_$state',
      );
    });
  }
}

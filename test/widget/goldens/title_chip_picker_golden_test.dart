import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/title_chip_picker.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

final _options = [
  TitleOption(id: 'explorer', label: 'Explorer'),
  TitleOption(id: 'streak', label: 'Streak Master'),
  TitleOption(
    id: 'legend',
    label: 'Legendary Champion of the Realm',
    locked: true,
    unlockHint: 'Reach level 50',
  ),
  TitleOption(id: 'long', label: 'An Extraordinarily Long Player Title'),
];

void main() {
  final previous = installGoldenTolerance('title_chip_picker_golden_test.dart');
  tearDownAll(() => goldenFileComparator = previous);
  const states = ['none', 'selected', 'locked', 'long'];
  for (final state in states) {
    testWidgets('TitleChipPicker $state golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final selected = switch (state) {
        'none' => null,
        'selected' => 'streak',
        'locked' => 'explorer',
        _ => 'long',
      };
      await runGoldenMatrix(
        tester,
        (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: TitleChipPicker(
            options: _options,
            selectedId: selected,
            onSelect: (_) {},
            onLockedTap: (_) {},
          ),
        ),
        goldenBaseName: 'title_chip_picker_$state',
      );
    });
  }
}

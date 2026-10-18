import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/avatar_frame_selector.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

const _options = [
  AvatarFrameOption(id: 'classic', label: 'Classic Cyan', color: Colors.cyan),
  AvatarFrameOption(id: 'neon', label: 'Neon Purple', color: Colors.purple),
  AvatarFrameOption(
    id: 'gold',
    label: 'Golden Legend Edition',
    color: Colors.amber,
    locked: true,
  ),
  AvatarFrameOption(
    id: 'fire',
    label: 'Fire Streak',
    color: Colors.deepOrange,
    locked: true,
  ),
];

void main() {
  final previous = installGoldenTolerance(
    'avatar_frame_selector_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);

  const states = <String, (List<AvatarFrameOption>, String?)>{
    'noselection': (_options, null),
    'selected': (_options, 'neon'),
    'empty': (<AvatarFrameOption>[], null),
  };
  for (final entry in states.entries) {
    testWidgets('AvatarFrameSelector ${entry.key} golden matrix', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await runGoldenMatrix(
        tester,
        (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: AvatarFrameSelector(
            options: entry.value.$1,
            selectedId: entry.value.$2,
            previewChild: const Icon(Icons.person_rounded),
            onSelect: (_) {},
            onLockedTap: (_) {},
          ),
        ),
        goldenBaseName: 'avatar_frame_selector_${entry.key}',
      );
    });
  }
}

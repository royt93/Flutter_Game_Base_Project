import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/inventory_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/character_collection_grid.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

const _characters = [
  CharacterCollectionItem(
    id: 'knight',
    name: 'Knight',
    rarity: ItemRarity.common,
    isOwned: true,
    isSelected: true,
  ),
  CharacterCollectionItem(
    id: 'mage',
    name: 'Mage',
    rarity: ItemRarity.epic,
    isOwned: true,
  ),
  CharacterCollectionItem(
    id: 'dragon',
    name: 'Dragon Lord',
    rarity: ItemRarity.legendary,
    isOwned: false,
  ),
];

void main() {
  final previousGoldenComparator = installGoldenTolerance(
    'character_collection_grid_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previousGoldenComparator);

  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('CharacterCollectionGrid owned/locked states qua Golden Matrix', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: CharacterCollectionGrid(
          characters: _characters,
          onCharacterTap: (_) {},
          onSelect: (_) {},
        ),
      ),
      goldenBaseName: 'character_collection_grid',
    );
  });

  testWidgets('CharacterCollectionGrid empty qua Golden Matrix', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: CharacterCollectionGrid(
          characters: const [],
          onCharacterTap: (_) {},
        ),
      ),
      goldenBaseName: 'character_collection_grid_empty',
    );
  });
}

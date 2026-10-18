import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/crafting_recipe_card.dart';
import 'package:roy_casual_kit/presentation/widgets/common/milestone_celebration_dialog.dart';

import '../../support/golden_matrix.dart';

final _output = MilestoneReward(
  icon: Icons.shield_rounded,
  label: 'Iron Shield',
  amountLabel: 'x1',
);

const _ready = [
  CraftingIngredient(
    itemId: 'iron',
    label: 'Iron',
    ownedQuantity: 4,
    requiredQuantity: 3,
  ),
  CraftingIngredient(
    itemId: 'wood',
    label: 'Wood',
    ownedQuantity: 2,
    requiredQuantity: 2,
  ),
  CraftingIngredient(
    itemId: 'crystal',
    label: 'Crystal',
    ownedQuantity: 1,
    requiredQuantity: 1,
  ),
];

void main() {
  testWidgets('CraftingRecipeCard craftable qua Golden Matrix', (tester) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: CraftingRecipeCard(
          recipeId: 'iron_shield',
          title: 'Iron Shield Recipe',
          subtitle: 'A sturdy defense item',
          output: _output,
          ingredients: _ready,
          onCraft: () {},
        ),
      ),
      guidelines: const [],
    );
  });

  testWidgets('CraftingRecipeCard missing and locked qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: CraftingRecipeCard(
          recipeId: 'moon_staff',
          title: 'Moon Staff',
          output: MilestoneReward(
            icon: Icons.auto_awesome_rounded,
            label: 'Moon Staff',
          ),
          ingredients: const [
            CraftingIngredient(
              itemId: 'moonstone',
              label: 'Moonstone',
              ownedQuantity: 0,
              requiredQuantity: 3,
            ),
            CraftingIngredient(
              itemId: 'wood',
              label: 'Ancient Wood',
              ownedQuantity: 1,
              requiredQuantity: 2,
            ),
          ],
          isLocked: true,
          onCraft: () {},
        ),
      ),
      guidelines: const [],
    );
  });
}

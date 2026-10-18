import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

final _output = MilestoneReward(
  icon: Icons.shield_rounded,
  label: 'Iron Shield',
  amountLabel: 'x1',
);

const _ready = [
  CraftingIngredient(
    itemId: 'iron',
    label: 'Iron',
    ownedQuantity: 5,
    requiredQuantity: 3,
  ),
  CraftingIngredient(
    itemId: 'wood',
    label: 'Wood',
    ownedQuantity: 2,
    requiredQuantity: 2,
  ),
];

const _missing = [
  CraftingIngredient(
    itemId: 'iron',
    label: 'Iron',
    ownedQuantity: 1,
    requiredQuantity: 3,
  ),
  CraftingIngredient(
    itemId: 'wood',
    label: 'Wood',
    ownedQuantity: 2,
    requiredQuantity: 2,
  ),
];

Widget _subject({
  List<CraftingIngredient> ingredients = _ready,
  bool locked = false,
  bool crafting = false,
  VoidCallback? onCraft,
  ValueChanged<String>? onIngredientTap,
  bool textScale2 = false,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale2 ? 2 : 1)),
    child: child!,
  ),
  home: Scaffold(
    body: Center(
      child: SingleChildScrollView(
        child: CraftingRecipeCard(
          recipeId: 'iron_shield',
          title: 'Iron Shield Recipe',
          output: _output,
          ingredients: ingredients,
          isLocked: locked,
          isCrafting: crafting,
          onCraft: onCraft ?? () {},
          onIngredientTap: onIngredientTap,
        ),
      ),
    ),
  ),
);

void main() {
  group('CraftingRecipeCard validation', () {
    test(
      'rejects empty ids/labels, empty ingredients, duplicate ids and bad counts',
      () {
        void invalid({
          String recipeId = 'recipe',
          String title = 'Recipe',
          List<CraftingIngredient> ingredients = _ready,
        }) => expect(
          () => CraftingRecipeCard(
            recipeId: recipeId,
            title: title,
            output: _output,
            ingredients: ingredients,
            onCraft: () {},
          ),
          throwsArgumentError,
        );

        invalid(recipeId: ' ');
        invalid(title: ' ');
        invalid(ingredients: const []);
        invalid(
          ingredients: const [
            CraftingIngredient(
              itemId: 'a',
              label: 'A',
              ownedQuantity: 0,
              requiredQuantity: 1,
            ),
            CraftingIngredient(
              itemId: 'a',
              label: 'B',
              ownedQuantity: 0,
              requiredQuantity: 1,
            ),
          ],
        );
        invalid(
          ingredients: const [
            CraftingIngredient(
              itemId: 'a',
              label: 'A',
              ownedQuantity: -1,
              requiredQuantity: 1,
            ),
          ],
        );
        invalid(
          ingredients: const [
            CraftingIngredient(
              itemId: 'a',
              label: 'A',
              ownedQuantity: 0,
              requiredQuantity: 0,
            ),
          ],
        );
      },
    );
  });

  group('CraftingRecipeCard UI', () {
    testWidgets('craftable recipe enables button and calls caller once', (
      tester,
    ) async {
      var crafted = 0;
      await tester.pumpWidget(_subject(onCraft: () => crafted++));

      expect(find.text('Creates Iron Shield'), findsOneWidget);
      expect(find.text('5/3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('craftingRecipeCraftBtn')));
      await tester.pump();
      expect(crafted, 1);
    });

    testWidgets('missing ingredient disables craft and shows status', (
      tester,
    ) async {
      await tester.pumpWidget(_subject(ingredients: _missing));
      final button = tester.widget<CommonButton>(
        find.byKey(const ValueKey('craftingRecipeCraftBtn')),
      );
      expect(button.onTap, isNull);
      expect(find.text('Missing ingredients'), findsOneWidget);
    });

    testWidgets('locked and crafting states disable action', (tester) async {
      await tester.pumpWidget(_subject(locked: true));
      var button = tester.widget<CommonButton>(
        find.byKey(const ValueKey('craftingRecipeCraftBtn')),
      );
      expect(button.label, 'Locked');
      expect(button.onTap, isNull);

      await tester.pumpWidget(_subject(crafting: true));
      button = tester.widget<CommonButton>(
        find.byKey(const ValueKey('craftingRecipeCraftBtn')),
      );
      expect(button.loading, isTrue);
      expect(button.onTap, isNull);
    });

    testWidgets('ingredient tap routes item id', (tester) async {
      String? tapped;
      await tester.pumpWidget(_subject(onIngredientTap: (id) => tapped = id));
      await tester.tap(find.byKey(const ValueKey('craftingIngredient_wood')));
      expect(tapped, 'wood');
    });

    testWidgets('semantics and text scale 2.0', (tester) async {
      await tester.pumpWidget(
        _subject(ingredients: _missing, textScale2: true),
      );
      final semantics = tester.widget<Semantics>(
        find.byKey(const ValueKey('craftingRecipeSemantics')),
      );
      expect(
        semantics.properties.label,
        contains('1 of 2 ingredients available'),
      );
      expect(tester.takeException(), isNull);
    });
  });
}

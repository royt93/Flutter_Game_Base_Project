import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import 'milestone_celebration_dialog.dart' show MilestoneReward;

/// Caller-provided ingredient status for one recipe.
@immutable
class CraftingIngredient {
  const CraftingIngredient({
    required this.itemId,
    required this.label,
    required this.ownedQuantity,
    required this.requiredQuantity,
    this.icon = Icons.inventory_2_rounded,
  });

  final String itemId;
  final String label;
  final int ownedQuantity;
  final int requiredQuantity;
  final IconData icon;

  bool get isAvailable => ownedQuantity >= requiredQuantity;
}

/// Presentation-only crafting recipe card. Caller owns inventory mutation,
/// recipe eligibility beyond ingredient counts, and crafted-item granting.
class CraftingRecipeCard extends StatelessWidget {
  CraftingRecipeCard({
    super.key,
    required this.recipeId,
    required this.title,
    required this.output,
    required this.ingredients,
    required this.onCraft,
    this.subtitle,
    this.isLocked = false,
    this.isCrafting = false,
    this.craftLabel = 'Craft',
    this.lockedLabel = 'Locked',
    this.craftingLabel = 'Crafting…',
    this.onIngredientTap,
    this.semanticLabel,
  }) {
    if (recipeId.trim().isEmpty || title.trim().isEmpty) {
      throw ArgumentError('recipeId and title must not be empty');
    }
    if (ingredients.isEmpty) {
      throw ArgumentError.value(
        ingredients,
        'ingredients',
        'must not be empty',
      );
    }
    if (craftLabel.trim().isEmpty ||
        lockedLabel.trim().isEmpty ||
        craftingLabel.trim().isEmpty) {
      throw ArgumentError('action labels must not be empty');
    }
    final ids = <String>{};
    for (final ingredient in ingredients) {
      if (ingredient.itemId.trim().isEmpty || ingredient.label.trim().isEmpty) {
        throw ArgumentError.value(
          ingredient,
          'ingredients',
          'itemId and label must not be empty',
        );
      }
      if (!ids.add(ingredient.itemId)) {
        throw ArgumentError.value(
          ingredient.itemId,
          'ingredients',
          'duplicate ingredient itemId',
        );
      }
      if (ingredient.ownedQuantity < 0 || ingredient.requiredQuantity <= 0) {
        throw ArgumentError.value(
          ingredient,
          'ingredients',
          'ownedQuantity must be non-negative and requiredQuantity positive',
        );
      }
    }
    if (output.label.trim().isEmpty ||
        (output.amountLabel != null && output.amountLabel!.trim().isEmpty)) {
      throw ArgumentError.value(
        output,
        'output',
        'reward labels must not be empty',
      );
    }
  }

  final String recipeId;
  final String title;
  final String? subtitle;
  final MilestoneReward output;
  final List<CraftingIngredient> ingredients;
  final VoidCallback onCraft;
  final bool isLocked;
  final bool isCrafting;
  final String craftLabel;
  final String lockedLabel;
  final String craftingLabel;
  final ValueChanged<String>? onIngredientTap;
  final String? semanticLabel;

  bool get _canCraft =>
      !isLocked && !isCrafting && ingredients.every((i) => i.isAvailable);

  @override
  Widget build(BuildContext context) {
    final availableCount = ingredients.where((i) => i.isAvailable).length;
    final semantic =
        semanticLabel ??
        '$title recipe. Output ${output.label} ${output.amountLabel ?? ""}. $availableCount of ${ingredients.length} ingredients available.';
    final statusLabel = isCrafting
        ? craftingLabel
        : isLocked
        ? lockedLabel
        : !_canCraft
        ? 'Missing ingredients'
        : null;

    return Semantics(
      key: const ValueKey('craftingRecipeSemantics'),
      container: true,
      label: semantic,
      child: Container(
        padding: const EdgeInsets.all(NeonTheme.s16),
        decoration: BoxDecoration(
          color: NeonTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: NeonTheme.purple.withValues(alpha: 0.35),
            width: 2,
          ),
          boxShadow: NeonTheme.drop(y: 4, blur: 12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.science_rounded, color: NeonTheme.purple, size: 24),
                const SizedBox(width: NeonTheme.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: NeonTheme.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: NeonTheme.inkSoft,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: NeonTheme.s8),
            _outputRow(),
            const SizedBox(height: NeonTheme.s8),
            Text(
              'Required Materials',
              style: TextStyle(
                color: NeonTheme.inkSoft,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final ingredient in ingredients)
                  _ingredientChip(ingredient),
              ],
            ),
            if (statusLabel != null) ...[
              const SizedBox(height: NeonTheme.s8),
              Text(
                statusLabel,
                key: const ValueKey('craftingRecipeStatus'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isCrafting ? NeonTheme.cyan : NeonTheme.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            const SizedBox(height: NeonTheme.s16),
            CommonButton(
              key: const ValueKey('craftingRecipeCraftBtn'),
              label: isCrafting
                  ? craftingLabel
                  : isLocked
                  ? lockedLabel
                  : craftLabel,
              color: NeonTheme.purple,
              loading: isCrafting,
              onTap: _canCraft ? onCraft : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _outputRow() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: NeonTheme.gold.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: NeonTheme.gold.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        Icon(output.icon, color: output.color ?? NeonTheme.gold, size: 22),
        const SizedBox(width: NeonTheme.s8),
        Expanded(
          child: Text(
            'Creates ${output.label}',
            style: TextStyle(
              color: NeonTheme.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (output.amountLabel != null)
          Text(
            output.amountLabel!,
            style: TextStyle(
              color: output.color ?? NeonTheme.gold,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    ),
  );

  Widget _ingredientChip(CraftingIngredient ingredient) {
    final available = ingredient.isAvailable;
    final color = available ? NeonTheme.lime : NeonTheme.red;
    return GestureDetector(
      key: ValueKey('craftingIngredient_${ingredient.itemId}'),
      onTap: onIngredientTap == null
          ? null
          : () => onIngredientTap!(ingredient.itemId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Icon(ingredient.icon, size: 15, color: color),
            Text(
              ingredient.label,
              style: TextStyle(
                color: NeonTheme.ink,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${ingredient.ownedQuantity}/${ingredient.requiredQuantity}',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

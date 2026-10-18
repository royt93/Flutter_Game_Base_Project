import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/inventory_service.dart' show ItemRarity;

enum CharacterCollectionFilter { all, owned, locked }

/// Caller-supplied character presentation and unlock/selection state.
@immutable
class CharacterCollectionItem {
  const CharacterCollectionItem({
    required this.id,
    required this.name,
    required this.rarity,
    required this.isOwned,
    this.isSelected = false,
    this.avatar,
  });

  final String id;
  final String name;
  final ItemRarity rarity;
  final bool isOwned;
  final bool isSelected;
  final Widget? avatar;
}

/// Lazy three-column character collection grid with caller-owned unlock and
/// selection state.
class CharacterCollectionGrid extends StatefulWidget {
  CharacterCollectionGrid({
    super.key,
    required this.characters,
    required this.onCharacterTap,
    this.onSelect,
    this.title = 'Character Collection',
    this.emptyMessage = 'No characters available.',
    this.filter = CharacterCollectionFilter.all,
    this.onFilterChanged,
    this.maxGridHeight = 420,
  }) {
    if (title.trim().isEmpty || emptyMessage.trim().isEmpty) {
      throw ArgumentError('title and emptyMessage must not be empty');
    }
    if (!maxGridHeight.isFinite || maxGridHeight <= 0) {
      throw ArgumentError.value(
        maxGridHeight,
        'maxGridHeight',
        'must be positive and finite',
      );
    }
    final ids = <String>{};
    for (final character in characters) {
      if (character.id.trim().isEmpty || character.name.trim().isEmpty) {
        throw ArgumentError.value(
          character,
          'characters',
          'id and name must not be empty',
        );
      }
      if (!ids.add(character.id)) {
        throw ArgumentError.value(
          character.id,
          'characters',
          'duplicate character id',
        );
      }
      if (character.isSelected && !character.isOwned) {
        throw ArgumentError.value(
          character.id,
          'characters',
          'locked character cannot be selected',
        );
      }
    }
    if (characters.where((c) => c.isSelected).length > 1) {
      throw ArgumentError.value(
        characters,
        'characters',
        'at most one character may be selected',
      );
    }
  }

  final List<CharacterCollectionItem> characters;
  final ValueChanged<String> onCharacterTap;
  final ValueChanged<String>? onSelect;
  final String title;
  final String emptyMessage;
  final CharacterCollectionFilter filter;
  final ValueChanged<CharacterCollectionFilter>? onFilterChanged;
  final double maxGridHeight;

  @override
  State<CharacterCollectionGrid> createState() =>
      _CharacterCollectionGridState();
}

class _CharacterCollectionGridState extends State<CharacterCollectionGrid> {
  late CharacterCollectionFilter _localFilter = widget.filter;

  @override
  void didUpdateWidget(covariant CharacterCollectionGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) _localFilter = widget.filter;
  }

  List<CharacterCollectionItem> get _filtered => widget.characters.where((c) {
    return switch (_localFilter) {
      CharacterCollectionFilter.all => true,
      CharacterCollectionFilter.owned => c.isOwned,
      CharacterCollectionFilter.locked => !c.isOwned,
    };
  }).toList();

  Color _rarityColor(ItemRarity rarity) => switch (rarity) {
    ItemRarity.common => NeonTheme.muted,
    ItemRarity.rare => NeonTheme.cyan,
    ItemRarity.epic => NeonTheme.purple,
    ItemRarity.legendary => NeonTheme.gold,
  };

  void _setFilter(CharacterCollectionFilter value) {
    if (widget.onFilterChanged != null) {
      widget.onFilterChanged!(value);
    } else {
      setState(() => _localFilter = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final cellExtent = 168 * textScale;
    final rowCount = (filtered.length + 2) ~/ 3;
    final contentHeight = rowCount == 0
        ? 0.0
        : rowCount * cellExtent + (rowCount - 1) * 8;
    final gridHeight = contentHeight.clamp(0.0, widget.maxGridHeight);
    final chipHeight = (14 * textScale + 14).clamp(48.0, double.infinity);
    final semantics =
        '${widget.title}. ${filtered.length} characters shown. ${widget.characters.where((c) => c.isOwned).length} owned.';
    return Semantics(
      key: const ValueKey('characterCollectionSemantics'),
      container: true,
      label: semantics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              color: NeonTheme.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: NeonTheme.s8),
          Wrap(
            spacing: 6,
            children: [
              for (final filter in CharacterCollectionFilter.values)
                _filterChip(filter, chipHeight),
            ],
          ),
          const SizedBox(height: NeonTheme.s8),
          if (filtered.isEmpty)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  widget.emptyMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: NeonTheme.inkSoft),
                ),
              ),
            )
          else
            SizedBox(
              height: gridHeight,
              child: GridView.builder(
                padding: EdgeInsets.zero,
                key: const ValueKey('characterCollectionGrid'),
                itemCount: filtered.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  mainAxisExtent: cellExtent,
                ),
                itemBuilder: (context, index) {
                  final character = filtered[index];
                  return _characterCell(character);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(CharacterCollectionFilter filter, double height) {
    final selected = _localFilter == filter;
    final text = switch (filter) {
      CharacterCollectionFilter.all => 'All',
      CharacterCollectionFilter.owned => 'Owned',
      CharacterCollectionFilter.locked => 'Locked',
    };
    return Semantics(
      button: true,
      selected: selected,
      label: '$text filter',
      child: GestureDetector(
        key: ValueKey('characterFilter_${filter.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _setFilter(filter),
        child: Container(
          height: height,
          constraints: const BoxConstraints(minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? NeonTheme.purple : NeonTheme.cardAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? NeonTheme.purple
                  : NeonTheme.inkSoft.withValues(alpha: 0.25),
            ),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              text,
              style: TextStyle(
                color: selected ? Colors.white : NeonTheme.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _characterCell(CharacterCollectionItem character) {
    final rarity = _rarityColor(character.rarity);
    return Semantics(
      button: true,
      selected: character.isSelected,
      label:
          '${character.name}, ${character.rarity.name}, ${character.isOwned ? "owned" : "locked"}${character.isSelected ? ", selected" : ""}',
      child: GestureDetector(
        key: ValueKey('characterItem_${character.id}'),
        onTap: () => widget.onCharacterTap(character.id),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: character.isSelected
                ? NeonTheme.cyan.withValues(alpha: 0.12)
                : NeonTheme.card,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: character.isSelected
                  ? NeonTheme.cyan
                  : rarity.withValues(alpha: 0.55),
              width: character.isSelected ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (character.avatar != null)
                      Opacity(
                        opacity: character.isOwned ? 1 : 0.4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: character.avatar,
                        ),
                      )
                    else
                      Icon(
                        character.isOwned
                            ? Icons.person_rounded
                            : Icons.lock_rounded,
                        size: 38,
                        color: rarity.withValues(
                          alpha: character.isOwned ? 1 : 0.55,
                        ),
                      ),
                    if (!character.isOwned && character.avatar != null)
                      Icon(
                        Icons.lock_rounded,
                        color: NeonTheme.inkSoft,
                        size: 22,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                character.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NeonTheme.ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 3,
                children: [
                  Text(
                    character.rarity.name.toUpperCase(),
                    style: TextStyle(
                      color: rarity,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (character.isSelected)
                    Text(
                      'SELECTED',
                      style: TextStyle(
                        color: NeonTheme.cyan,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
              if (character.isOwned && widget.onSelect != null)
                GestureDetector(
                  key: ValueKey('characterSelect_${character.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onSelect!(character.id),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Center(
                      child: Text(
                        character.isSelected ? 'Selected' : 'Select',
                        style: TextStyle(
                          color: character.isSelected
                              ? NeonTheme.inkSoft
                              : NeonTheme.cyan,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

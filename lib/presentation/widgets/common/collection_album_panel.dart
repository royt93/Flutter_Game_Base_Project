import 'package:flutter/material.dart';

import '../../../core/inventory_service.dart' show ItemRarity;
import '../../../core/neon_theme.dart';

/// Caller-provided view of one collectible in a collection album.
@immutable
class CollectionAlbumItem {
  const CollectionAlbumItem({
    required this.id,
    required this.name,
    required this.rarity,
    required this.ownedCount,
    required this.requiredCount,
    this.icon = Icons.auto_awesome_rounded,
  });

  final String id;
  final String name;
  final ItemRarity rarity;
  final int ownedCount;
  final int requiredCount;
  final IconData icon;

  bool get isOwned => ownedCount >= requiredCount;
}

enum CollectionAlbumFilter { all, owned, missing }

/// Collection album with caller-owned item/quantity state and a lazy 3-column grid.
class CollectionAlbumPanel extends StatefulWidget {
  CollectionAlbumPanel({
    super.key,
    required this.title,
    required this.items,
    required this.onItemTap,
    this.completionRewardLabel,
    this.onViewReward,
    this.emptyMessage = 'No collectibles in this album.',
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (emptyMessage.trim().isEmpty) {
      throw ArgumentError.value(
        emptyMessage,
        'emptyMessage',
        'must not be empty',
      );
    }
    final ids = <String>{};
    for (final item in items) {
      if (item.id.trim().isEmpty || item.name.trim().isEmpty) {
        throw ArgumentError.value(
          item,
          'items',
          'id and name must not be empty',
        );
      }
      if (!ids.add(item.id)) {
        throw ArgumentError.value(
          item.id,
          'items',
          'duplicate item id: ${item.id}',
        );
      }
      if (item.ownedCount < 0 || item.requiredCount <= 0) {
        throw ArgumentError.value(
          item,
          'items',
          'ownedCount must be non-negative and requiredCount positive',
        );
      }
    }
    if (completionRewardLabel != null &&
        completionRewardLabel!.trim().isEmpty) {
      throw ArgumentError.value(
        completionRewardLabel,
        'completionRewardLabel',
        'must not be empty when provided',
      );
    }
  }

  final String title;
  final List<CollectionAlbumItem> items;
  final ValueChanged<String> onItemTap;
  final String? completionRewardLabel;
  final VoidCallback? onViewReward;
  final String emptyMessage;

  @override
  State<CollectionAlbumPanel> createState() => _CollectionAlbumPanelState();
}

class _CollectionAlbumPanelState extends State<CollectionAlbumPanel> {
  CollectionAlbumFilter _filter = CollectionAlbumFilter.all;

  List<CollectionAlbumItem> get _filteredItems => switch (_filter) {
    CollectionAlbumFilter.all => widget.items,
    CollectionAlbumFilter.owned =>
      widget.items.where((i) => i.isOwned).toList(),
    CollectionAlbumFilter.missing =>
      widget.items.where((i) => !i.isOwned).toList(),
  };

  int get _ownedCount => widget.items.where((i) => i.isOwned).length;

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;
    final complete =
        widget.items.isNotEmpty && _ownedCount == widget.items.length;
    final semantics =
        '${widget.title}. $_ownedCount of ${widget.items.length} collectibles owned.';

    return Semantics(
      key: const ValueKey('collectionAlbumSemantics'),
      container: true,
      label: semantics,
      child: Container(
        padding: const EdgeInsets.all(NeonTheme.s16),
        decoration: BoxDecoration(
          color: NeonTheme.card,
          borderRadius: BorderRadius.circular(18),
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
            Text(
              widget.title,
              style: TextStyle(
                color: NeonTheme.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$_ownedCount / ${widget.items.length} collected',
              key: const ValueKey('collectionAlbumProgress'),
              style: TextStyle(
                color: complete ? NeonTheme.lime : NeonTheme.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (complete && widget.completionRewardLabel != null) ...[
              const SizedBox(height: NeonTheme.s8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    'Complete · ${widget.completionRewardLabel}',
                    style: TextStyle(
                      color: NeonTheme.lime,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (widget.onViewReward != null)
                    GestureDetector(
                      key: const ValueKey('collectionViewRewardBtn'),
                      onTap: widget.onViewReward,
                      child: Text(
                        'View Reward',
                        style: TextStyle(
                          color: NeonTheme.cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: NeonTheme.s8),
            Wrap(
              spacing: 6,
              children: [
                for (final filter in CollectionAlbumFilter.values)
                  _filterChip(filter),
              ],
            ),
            const SizedBox(height: NeonTheme.s8),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: NeonTheme.s16),
                child: Text(
                  widget.items.isEmpty
                      ? widget.emptyMessage
                      : 'No matching items.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: NeonTheme.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              SizedBox(
                height: 248,
                child: GridView.builder(
                  key: const ValueKey('collectionAlbumGrid'),
                  itemCount: filtered.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _CollectionCell(
                      item: item,
                      onTap: () => widget.onItemTap(item.id),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(CollectionAlbumFilter filter) {
    final selected = _filter == filter;
    final label = switch (filter) {
      CollectionAlbumFilter.all => 'All',
      CollectionAlbumFilter.owned => 'Owned',
      CollectionAlbumFilter.missing => 'Missing',
    };
    return Semantics(
      button: true,
      selected: selected,
      label: '$label filter',
      child: GestureDetector(
        key: ValueKey('collectionFilter_${filter.name}'),
        onTap: () => setState(() => _filter = filter),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? NeonTheme.purple : NeonTheme.cardAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? NeonTheme.purple
                  : NeonTheme.inkSoft.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : NeonTheme.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectionCell extends StatelessWidget {
  const _CollectionCell({required this.item, required this.onTap});

  final CollectionAlbumItem item;
  final VoidCallback onTap;

  Color get _rarityColor => switch (item.rarity) {
    ItemRarity.common => NeonTheme.muted,
    ItemRarity.rare => NeonTheme.cyan,
    ItemRarity.epic => NeonTheme.purple,
    ItemRarity.legendary => NeonTheme.gold,
  };

  @override
  Widget build(BuildContext context) {
    final owned = item.isOwned;
    return Semantics(
      button: true,
      label:
          '${item.name}, ${item.rarity.name}, ${owned ? "collected" : "missing"}, ${item.ownedCount} of ${item.requiredCount}',
      child: GestureDetector(
        key: ValueKey('collectionItem_${item.id}'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: owned
                ? _rarityColor.withValues(alpha: 0.12)
                : NeonTheme.cardAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _rarityColor.withValues(alpha: owned ? 0.8 : 0.3),
              width: owned ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                owned ? item.icon : Icons.help_outline_rounded,
                size: 30,
                color: _rarityColor,
              ),
              const SizedBox(height: 4),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NeonTheme.ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${item.ownedCount}/${item.requiredCount}',
                style: TextStyle(
                  color: _rarityColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

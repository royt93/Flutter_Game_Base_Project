import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/inventory_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/collection_album_panel.dart';

import '../../support/golden_matrix.dart';

const _items = [
  CollectionAlbumItem(
    id: 'blue_fox',
    name: 'Blue Fox',
    rarity: ItemRarity.rare,
    ownedCount: 1,
    requiredCount: 1,
    icon: Icons.pets_rounded,
  ),
  CollectionAlbumItem(
    id: 'moon_crown',
    name: 'Moon Crown',
    rarity: ItemRarity.legendary,
    ownedCount: 0,
    requiredCount: 1,
    icon: Icons.workspace_premium_rounded,
  ),
  CollectionAlbumItem(
    id: 'star_shard',
    name: 'Star Shard',
    rarity: ItemRarity.epic,
    ownedCount: 2,
    requiredCount: 5,
    icon: Icons.auto_awesome_rounded,
  ),
];

void main() {
  testWidgets('CollectionAlbumPanel mixed rarity qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: CollectionAlbumPanel(
          title: 'Forest Collection',
          items: _items,
          onItemTap: (_) {},
        ),
      ),
      guidelines: const [],
    );
  });

  testWidgets('CollectionAlbumPanel complete reward qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: CollectionAlbumPanel(
          title: 'Complete Set',
          items: [
            for (final item in _items)
              CollectionAlbumItem(
                id: item.id,
                name: item.name,
                rarity: item.rarity,
                ownedCount: item.requiredCount,
                requiredCount: item.requiredCount,
                icon: item.icon,
              ),
          ],
          completionRewardLabel: 'Golden Avatar',
          onItemTap: (_) {},
          onViewReward: () {},
        ),
      ),
      guidelines: const [],
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/inventory_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

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

Widget _subject({
  List<CollectionAlbumItem> items = _items,
  ValueChanged<String>? onItemTap,
  String? completionRewardLabel,
  VoidCallback? onViewReward,
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
        child: CollectionAlbumPanel(
          title: 'Forest Collection',
          items: items,
          onItemTap: onItemTap ?? (_) {},
          completionRewardLabel: completionRewardLabel,
          onViewReward: onViewReward,
        ),
      ),
    ),
  ),
);

void main() {
  group('CollectionAlbumPanel validation', () {
    test('rejects empty/duplicate ids, empty names and invalid quantities', () {
      expect(
        () => CollectionAlbumPanel(
          title: 'Album',
          items: const [
            CollectionAlbumItem(
              id: '',
              name: 'Item',
              rarity: ItemRarity.common,
              ownedCount: 0,
              requiredCount: 1,
            ),
          ],
          onItemTap: (_) {},
        ),
        throwsArgumentError,
      );
      expect(
        () => CollectionAlbumPanel(
          title: 'Album',
          items: const [
            CollectionAlbumItem(
              id: 'same',
              name: 'One',
              rarity: ItemRarity.common,
              ownedCount: 0,
              requiredCount: 1,
            ),
            CollectionAlbumItem(
              id: 'same',
              name: 'Two',
              rarity: ItemRarity.common,
              ownedCount: 0,
              requiredCount: 1,
            ),
          ],
          onItemTap: (_) {},
        ),
        throwsArgumentError,
      );
      expect(
        () => CollectionAlbumPanel(
          title: 'Album',
          items: const [
            CollectionAlbumItem(
              id: 'empty_name',
              name: ' ',
              rarity: ItemRarity.common,
              ownedCount: 0,
              requiredCount: 1,
            ),
          ],
          onItemTap: (_) {},
        ),
        throwsArgumentError,
      );
      expect(
        () => CollectionAlbumPanel(
          title: 'Album',
          items: const [
            CollectionAlbumItem(
              id: 'bad_count',
              name: 'Item',
              rarity: ItemRarity.common,
              ownedCount: -1,
              requiredCount: 1,
            ),
          ],
          onItemTap: (_) {},
        ),
        throwsArgumentError,
      );
    });
  });

  group('CollectionAlbumPanel UI', () {
    testWidgets('shows owned progress and routes item ID', (tester) async {
      String? tappedId;
      await tester.pumpWidget(_subject(onItemTap: (id) => tappedId = id));

      expect(find.text('1 / 3 collected'), findsOneWidget);
      expect(find.byKey(const ValueKey('collectionAlbumGrid')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('collectionItem_moon_crown')));
      expect(tappedId, 'moon_crown');
    });

    testWidgets('filters owned and missing items', (tester) async {
      await tester.pumpWidget(_subject());
      await tester.tap(find.byKey(const ValueKey('collectionFilter_owned')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('collectionItem_blue_fox')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('collectionItem_moon_crown')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('collectionItem_star_shard')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('collectionFilter_missing')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('collectionItem_blue_fox')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('collectionItem_moon_crown')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('collectionItem_star_shard')),
        findsOneWidget,
      );
    });

    testWidgets('shows completion reward only when all owned', (tester) async {
      await tester.pumpWidget(_subject(completionRewardLabel: 'Golden Avatar'));
      expect(find.text('Complete · Golden Avatar'), findsNothing);

      final completeItems = _items
          .map(
            (item) => CollectionAlbumItem(
              id: item.id,
              name: item.name,
              rarity: item.rarity,
              ownedCount: item.requiredCount,
              requiredCount: item.requiredCount,
              icon: item.icon,
            ),
          )
          .toList();
      var viewed = false;
      await tester.pumpWidget(
        _subject(
          items: completeItems,
          completionRewardLabel: 'Golden Avatar',
          onViewReward: () => viewed = true,
        ),
      );
      expect(find.text('Complete · Golden Avatar'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('collectionViewRewardBtn')));
      expect(viewed, isTrue);
    });

    testWidgets('empty album shows empty state', (tester) async {
      await tester.pumpWidget(_subject(items: const []));
      expect(find.text('0 / 0 collected'), findsOneWidget);
      expect(find.text('No collectibles in this album.'), findsOneWidget);
    });

    testWidgets('semantics announces title and completion count', (
      tester,
    ) async {
      await tester.pumpWidget(_subject());
      final semantics = tester.widget<Semantics>(
        find.byKey(const ValueKey('collectionAlbumSemantics')),
      );
      expect(
        semantics.properties.label,
        'Forest Collection. 1 of 3 collectibles owned.',
      );
    });

    testWidgets('no overflow at text scale 2.0', (tester) async {
      await tester.pumpWidget(_subject(textScale2: true));
      expect(tester.takeException(), isNull);
    });
  });
}

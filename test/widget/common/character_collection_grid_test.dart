import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/inventory_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

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

Widget _subject({
  List<CharacterCollectionItem> characters = _characters,
  ValueChanged<String>? onTap,
  ValueChanged<String>? onSelect,
  CharacterCollectionFilter filter = CharacterCollectionFilter.all,
  ValueChanged<CharacterCollectionFilter>? onFilterChanged,
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
      child: CharacterCollectionGrid(
        characters: characters,
        onCharacterTap: onTap ?? (_) {},
        onSelect: onSelect,
        filter: filter,
        onFilterChanged: onFilterChanged,
        maxGridHeight: 320,
      ),
    ),
  ),
);

void main() {
  group('CharacterCollectionGrid validation', () {
    test(
      'rejects empty/duplicate ids, empty names, locked selected and multi-selected',
      () {
        void invalid(List<CharacterCollectionItem> chars) => expect(
          () => CharacterCollectionGrid(
            characters: chars,
            onCharacterTap: (_) {},
          ),
          throwsArgumentError,
        );

        invalid(const [
          CharacterCollectionItem(
            id: ' ',
            name: 'A',
            rarity: ItemRarity.common,
            isOwned: true,
          ),
        ]);
        invalid(const [
          CharacterCollectionItem(
            id: 'a',
            name: ' ',
            rarity: ItemRarity.common,
            isOwned: true,
          ),
        ]);
        invalid(const [
          CharacterCollectionItem(
            id: 'a',
            name: 'A',
            rarity: ItemRarity.common,
            isOwned: true,
          ),
          CharacterCollectionItem(
            id: 'a',
            name: 'B',
            rarity: ItemRarity.common,
            isOwned: true,
          ),
        ]);
        invalid(const [
          CharacterCollectionItem(
            id: 'locked',
            name: 'Locked',
            rarity: ItemRarity.rare,
            isOwned: false,
            isSelected: true,
          ),
        ]);
        invalid(const [
          CharacterCollectionItem(
            id: 'a',
            name: 'A',
            rarity: ItemRarity.common,
            isOwned: true,
            isSelected: true,
          ),
          CharacterCollectionItem(
            id: 'b',
            name: 'B',
            rarity: ItemRarity.common,
            isOwned: true,
            isSelected: true,
          ),
        ]);
      },
    );
  });

  group('CharacterCollectionGrid UI', () {
    testWidgets('shows owned, locked and selected badges', (tester) async {
      await tester.pumpWidget(_subject());
      expect(
        find.byKey(const ValueKey('characterCollectionGrid')),
        findsOneWidget,
      );
      expect(find.text('Knight'), findsOneWidget);
      expect(find.text('SELECTED'), findsOneWidget);
      expect(find.text('LEGENDARY'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });

    testWidgets('local filter hides unmatched characters', (tester) async {
      await tester.pumpWidget(_subject());
      await tester.tap(find.byKey(const ValueKey('characterFilter_locked')));
      await tester.pump();
      expect(find.text('Dragon Lord'), findsOneWidget);
      expect(find.text('Knight'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('characterFilter_owned')));
      await tester.pump();
      expect(find.text('Dragon Lord'), findsNothing);
      expect(find.text('Mage'), findsOneWidget);
    });

    testWidgets('controlled filter routes changes to caller', (tester) async {
      final filters = <CharacterCollectionFilter>[];
      await tester.pumpWidget(_subject(onFilterChanged: filters.add));
      await tester.tap(find.byKey(const ValueKey('characterFilter_owned')));
      await tester.pump();
      expect(filters, [CharacterCollectionFilter.owned]);
      expect(find.text('Dragon Lord'), findsOneWidget);
    });

    testWidgets('tap and select callbacks route character IDs', (tester) async {
      final tapped = <String>[];
      final selected = <String>[];
      await tester.pumpWidget(
        _subject(onTap: tapped.add, onSelect: selected.add),
      );

      await tester.tap(find.byKey(const ValueKey('characterItem_dragon')));
      await tester.tap(find.byKey(const ValueKey('characterSelect_mage')));
      expect(tapped, contains('dragon'));
      expect(selected, ['mage']);
      expect(
        find.byKey(const ValueKey('characterSelect_dragon')),
        findsNothing,
      );
    });

    testWidgets('long catalog stays lazy and can filter during scrolling', (
      tester,
    ) async {
      final characters = List.generate(
        60,
        (index) => CharacterCollectionItem(
          id: 'character_$index',
          name: 'Character $index',
          rarity: ItemRarity.common,
          isOwned: index.isEven,
          isSelected: index == 0,
        ),
      );
      await tester.pumpWidget(_subject(characters: characters));
      expect(
        find.byKey(const ValueKey('characterItem_character_59')),
        findsNothing,
      );

      final grid = find.byKey(const ValueKey('characterCollectionGrid'));
      await tester.fling(grid, const Offset(0, -400), 1000);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey('characterFilter_locked')));
      await tester.pump();
      expect(find.text('SELECTED'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_subject(characters: characters));
      expect(find.text('SELECTED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('narrow 320dp viewport at text scale 2.0 does not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_subject(textScale2: true, onSelect: (_) {}));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('characterSelect_mage')),
        findsOneWidget,
      );
    });

    testWidgets('filter and select targets accept taps in 48dp padding', (
      tester,
    ) async {
      final filters = <CharacterCollectionFilter>[];
      final selected = <String>[];
      await tester.pumpWidget(
        _subject(onFilterChanged: filters.add, onSelect: selected.add),
      );

      final filter = find.byKey(const ValueKey('characterFilter_owned'));
      final filterRect = tester.getRect(filter);
      expect(filterRect.height, greaterThanOrEqualTo(48));
      await tester.tapAt(filterRect.topLeft + const Offset(2, 2));
      expect(filters, [CharacterCollectionFilter.owned]);

      final select = find.byKey(const ValueKey('characterSelect_mage'));
      final selectRect = tester.getRect(select);
      expect(selectRect.height, greaterThanOrEqualTo(48));
      await tester.tapAt(selectRect.topLeft + const Offset(2, 2));
      expect(selected, ['mage']);
    });

    testWidgets('grid fits one row and filter chips share one height', (
      tester,
    ) async {
      await tester.pumpWidget(_subject());

      final gridSize = tester.getSize(
        find.byKey(const ValueKey('characterCollectionGrid')),
      );
      expect(gridSize.height, 168);

      final heights = [
        for (final filter in CharacterCollectionFilter.values)
          tester
              .getSize(find.byKey(ValueKey('characterFilter_${filter.name}')))
              .height,
      ];
      expect(heights.toSet(), hasLength(1));
      expect(heights.first, greaterThanOrEqualTo(48));
    });

    testWidgets('long catalog caps grid at maxGridHeight', (tester) async {
      final characters = List.generate(
        30,
        (i) => CharacterCollectionItem(
          id: 'c$i',
          name: 'Character $i',
          rarity: ItemRarity.common,
          isOwned: true,
        ),
      );
      await tester.pumpWidget(_subject(characters: characters));

      expect(
        tester
            .getSize(find.byKey(const ValueKey('characterCollectionGrid')))
            .height,
        320,
      );
    });

    testWidgets('empty state, semantics and text scale', (tester) async {
      await tester.pumpWidget(_subject(characters: const []));
      expect(find.text('No characters available.'), findsOneWidget);

      await tester.pumpWidget(_subject(textScale2: true));
      final semantics = tester.widget<Semantics>(
        find.byKey(const ValueKey('characterCollectionSemantics')),
      );
      expect(semantics.properties.label, contains('3 characters shown'));
      expect(semantics.properties.label, contains('2 owned'));
      expect(tester.takeException(), isNull);
    });
  });
}

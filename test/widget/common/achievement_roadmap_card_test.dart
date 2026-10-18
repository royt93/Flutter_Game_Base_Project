import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

final _items = [
  AchievementRoadmapItem(
    id: 'collector_10',
    title: 'Collect 10 items',
    description: 'Find items across any levels',
    progress: 10,
    target: 10,
    reward: MilestoneReward(
      icon: Icons.diamond_rounded,
      label: 'Gems',
      amountLabel: 'x25',
    ),
  ),
  AchievementRoadmapItem(
    id: 'win_50',
    title: 'Win 50 levels',
    progress: 24,
    target: 50,
    reward: MilestoneReward(
      icon: Icons.stars_rounded,
      label: 'Stars',
      amountLabel: 'x10',
    ),
  ),
  AchievementRoadmapItem(
    id: 'combo_5',
    title: 'Reach a 5x combo',
    progress: 2,
    target: 5,
    reward: MilestoneReward(
      icon: Icons.bolt_rounded,
      label: 'Boost',
      amountLabel: 'x1',
    ),
  ),
];

Widget _subject({
  List<AchievementRoadmapItem>? items,
  ValueChanged<String>? onClaim,
  ValueChanged<String>? onOpen,
  bool loading = false,
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
      child: AchievementRoadmapCard(
        items: items ?? _items,
        onClaim: onClaim ?? (_) {},
        onOpen: onOpen,
        isLoading: loading,
      ),
    ),
  ),
);

void main() {
  group('AchievementRoadmapCard validation', () {
    test(
      'rejects duplicate IDs, empty title, negative progress and nonpositive target',
      () {
        void invalid(List<AchievementRoadmapItem> items) => expect(
          () => AchievementRoadmapCard(items: items, onClaim: (_) {}),
          throwsArgumentError,
        );

        invalid([_items.first, _items.first]);
        invalid([
          AchievementRoadmapItem(
            id: 'empty',
            title: ' ',
            progress: 0,
            target: 1,
            reward: MilestoneReward(icon: Icons.star, label: 'Star'),
          ),
        ]);
        invalid([
          AchievementRoadmapItem(
            id: 'negative',
            title: 'Negative',
            progress: -1,
            target: 1,
            reward: MilestoneReward(icon: Icons.star, label: 'Star'),
          ),
        ]);
        invalid([
          AchievementRoadmapItem(
            id: 'zero',
            title: 'Zero',
            progress: 0,
            target: 0,
            reward: MilestoneReward(icon: Icons.star, label: 'Star'),
          ),
        ]);
      },
    );
  });

  group('AchievementRoadmapCard UI', () {
    testWidgets('shows progress and claimable milestone routes id', (
      tester,
    ) async {
      final claimed = <String>[];
      await tester.pumpWidget(_subject(onClaim: claimed.add));
      expect(find.text('Collect 10 items'), findsOneWidget);
      expect(find.text('10/10'), findsNothing);
      expect(find.text('Complete'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('achievementClaim_collector_10')),
      );
      expect(claimed, ['collector_10']);
    });

    testWidgets('open callback routes achievement id', (tester) async {
      String? opened;
      await tester.pumpWidget(_subject(onOpen: (id) => opened = id));
      await tester.tap(
        find.byKey(const ValueKey('achievementRoadmapItem_win_50')),
      );
      expect(opened, 'win_50');
    });

    testWidgets('empty/loading states', (tester) async {
      await tester.pumpWidget(_subject(items: const []));
      expect(find.text('No achievements yet.'), findsOneWidget);
      await tester.pumpWidget(_subject(loading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Collect 10 items'), findsNothing);
    });

    testWidgets('semantics announces count and no overflow at text scale 2', (
      tester,
    ) async {
      await tester.pumpWidget(_subject(textScale2: true));
      final semantics = tester.widget<Semantics>(
        find.byKey(const ValueKey('achievementRoadmapSemantics')),
      );
      expect(
        semantics.properties.label,
        'Achievement Roadmap. 3 achievements.',
      );
      expect(tester.takeException(), isNull);
    });
  });
}

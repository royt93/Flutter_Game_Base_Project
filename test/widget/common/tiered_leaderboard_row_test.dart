import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/tiered_leaderboard_row.dart';

Widget _wrap(Widget child, {bool reduced = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('LeaderboardTier presentation', () {
    test('maps tier labels and distinct colors/icons', () {
      expect(LeaderboardTier.values.map((tier) => tier.displayName), [
        'Bronze',
        'Silver',
        'Gold',
        'Diamond',
      ]);
      expect(LeaderboardTier.bronze.color, isNot(LeaderboardTier.silver.color));
      expect(LeaderboardTier.gold.color, NeonTheme.gold);
      expect(LeaderboardTier.diamond.icon, Icons.diamond_rounded);
      expect(LeaderboardTier.values.map((tier) => tier.icon).toSet().length, 4);
    });
  });

  group('TierZone presentation', () {
    test('maps zone icon/color/description', () {
      expect(TierZone.promotion.icon, Icons.arrow_upward_rounded);
      expect(TierZone.promotion.color, NeonTheme.lime);
      expect(TierZone.promotion.description, 'promotion zone');
      expect(TierZone.safe.icon, Icons.remove_rounded);
      expect(TierZone.safe.description, 'safe zone');
      expect(TierZone.demotion.icon, Icons.arrow_downward_rounded);
      expect(TierZone.demotion.color, NeonTheme.red);
      expect(TierZone.demotion.description, 'demotion zone');
    });
  });

  group('TieredLeaderboardRow validation', () {
    test('rejects invalid rank, empty name/score, and invalid height', () {
      TieredLeaderboardRow row({
        int rank = 1,
        String name = 'Alice',
        String score = '100',
        double height = 64,
      }) => TieredLeaderboardRow(
        rank: rank,
        playerName: name,
        score: score,
        tier: LeaderboardTier.bronze,
        height: height,
      );

      expect(() => row(rank: 0), throwsArgumentError);
      expect(() => row(name: ' '), throwsArgumentError);
      expect(() => row(score: ''), throwsArgumentError);
      expect(() => row(height: 0), throwsArgumentError);
      expect(() => row(height: double.infinity), throwsArgumentError);
    });
  });

  group('TieredLeaderboardRow rendering and interaction', () {
    testWidgets('renders rank, player, score, tier badge and zone icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TieredLeaderboardRow(
            rank: 1,
            playerName: 'Alice',
            score: '12,450',
            tier: LeaderboardTier.gold,
            zone: TierZone.promotion,
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('12,450'), findsOneWidget);
      expect(find.text('Gold'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('renders zone indicators for promotion, safe and demotion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              for (final zone in TierZone.values)
                TieredLeaderboardRow(
                  key: ValueKey(zone.name),
                  rank: zone.index + 1,
                  playerName: 'Player ${zone.name}',
                  score: '100',
                  tier: LeaderboardTier.silver,
                  zone: zone,
                ),
            ],
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });

    testWidgets('highlights current player row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TieredLeaderboardRow(
            rank: 3,
            playerName: 'You',
            score: '8,000',
            tier: LeaderboardTier.diamond,
            isCurrentPlayer: true,
          ),
        ),
      );

      final row = tester.widget<Container>(
        find.byKey(const ValueKey('tieredLeaderboardRow_3')),
      );
      final decoration = row.decoration! as BoxDecoration;
      expect(decoration.color, NeonTheme.cardAlt);
      expect(decoration.border!.top.color, NeonTheme.gold);
    });

    testWidgets('tap invokes onTap and null onTap keeps row inert', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          TieredLeaderboardRow(
            rank: 5,
            playerName: 'Bob',
            score: '1,200',
            tier: LeaderboardTier.bronze,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('tieredLeaderboardRow_5')));
      expect(taps, 1);

      await tester.pumpWidget(
        _wrap(
          TieredLeaderboardRow(
            rank: 5,
            playerName: 'Bob',
            score: '1,200',
            tier: LeaderboardTier.bronze,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('tieredLeaderboardRow_5')));
      expect(taps, 1);
    });

    testWidgets(
      'rank/score changes transition, Reduced Motion settles immediately',
      (tester) async {
        Widget build(int rank, String score, {bool reduced = false}) => _wrap(
          TieredLeaderboardRow(
            rank: rank,
            playerName: 'Alice',
            score: score,
            tier: LeaderboardTier.gold,
          ),
          reduced: reduced,
        );

        await tester.pumpWidget(build(1, '100'));
        await tester.pumpWidget(build(2, '200'));
        await tester.pump(const Duration(milliseconds: 120));
        expect(find.text('2'), findsOneWidget);
        expect(find.text('200'), findsOneWidget);

        await tester.pumpWidget(build(3, '300', reduced: true));
        expect(find.text('3'), findsOneWidget);
        expect(find.text('300'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('semantics announce rank, player, tier, score and zone', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          TieredLeaderboardRow(
            rank: 7,
            playerName: 'You',
            score: '12.4K',
            tier: LeaderboardTier.diamond,
            zone: TierZone.demotion,
            isCurrentPlayer: true,
          ),
        ),
      );

      final node = tester.getSemantics(
        find.byKey(const ValueKey('tieredLeaderboardRow_7')),
      );
      expect(
        node.label,
        'Rank 7, You, Diamond tier, 12.4K points, in demotion zone',
      );
      handle.dispose();
    });
  });
}

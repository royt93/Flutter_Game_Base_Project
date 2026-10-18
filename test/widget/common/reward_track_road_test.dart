import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

final _tiers = [
  RewardTrackTier(
    id: 'tier_1',
    requiredXp: 100,
    freeReward: MilestoneReward(
      icon: Icons.monetization_on_rounded,
      label: 'Coins',
      amountLabel: 'x100',
    ),
    premiumReward: MilestoneReward(
      icon: Icons.diamond_rounded,
      label: 'Gems',
      amountLabel: 'x10',
    ),
  ),
  RewardTrackTier(
    id: 'tier_2',
    requiredXp: 250,
    freeReward: MilestoneReward(
      icon: Icons.favorite_rounded,
      label: 'Lives',
      amountLabel: 'x2',
    ),
  ),
  RewardTrackTier(
    id: 'tier_3',
    requiredXp: 500,
    freeReward: MilestoneReward(icon: Icons.shield_rounded, label: 'Shield'),
    premiumReward: MilestoneReward(
      icon: Icons.stars_rounded,
      label: 'Stars',
      amountLabel: 'x5',
    ),
  ),
];

Widget _subject({
  int currentXp = 150,
  bool premiumEnabled = false,
  Set<String> claimedFreeIds = const {},
  Set<String> claimedPremiumIds = const {},
  void Function(String, RewardTrackLane)? onClaim,
  bool disableAnimations = false,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: child!,
  ),
  home: Scaffold(
    body: Center(
      child: RewardTrackRoad(
        tiers: _tiers,
        currentXp: currentXp,
        premiumEnabled: premiumEnabled,
        claimedFreeIds: claimedFreeIds,
        claimedPremiumIds: claimedPremiumIds,
        onClaim: onClaim ?? (_, _) {},
      ),
    ),
  ),
);

void main() {
  group('RewardTrackRoad validation', () {
    test(
      'rejects negative XP, empty/duplicate IDs and unordered milestones',
      () {
        expect(
          () =>
              RewardTrackRoad(tiers: _tiers, currentXp: -1, onClaim: (_, _) {}),
          throwsArgumentError,
        );
        expect(
          () => RewardTrackRoad(
            tiers: [
              _tiers.first,
              RewardTrackTier(
                id: 'tier_1',
                requiredXp: 200,
                freeReward: _tiers.first.freeReward,
              ),
            ],
            currentXp: 0,
            onClaim: (_, _) {},
          ),
          throwsArgumentError,
        );
        expect(
          () => RewardTrackRoad(
            tiers: [
              _tiers[1],
              RewardTrackTier(
                id: 'tier_0',
                requiredXp: 50,
                freeReward: _tiers.first.freeReward,
              ),
            ],
            currentXp: 0,
            onClaim: (_, _) {},
          ),
          throwsArgumentError,
        );
      },
    );
  });

  group('RewardTrackRoad UI', () {
    testWidgets('shows horizontal tiers and claimable free reward', (
      tester,
    ) async {
      final claims = <(String, RewardTrackLane)>[];
      await tester.pumpWidget(
        _subject(onClaim: (id, lane) => claims.add((id, lane))),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('rewardTrackScroll')), findsOneWidget);
      expect(find.text('150 XP'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('rewardTrackTier_tier_1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('rewardTrackTier_tier_2')),
        findsOneWidget,
      );
      expect(find.text('Coins'), findsOneWidget);
      expect(find.text('Locked'), findsWidgets);

      final claim = find.byKey(
        const ValueKey('rewardTrackClaim_tier_1_free_Coins'),
      );
      expect(claim, findsOneWidget);
      await tester.tap(claim);
      expect(claims, [('tier_1', RewardTrackLane.free)]);
    });

    testWidgets('premium rewards locked until caller enables premium', (
      tester,
    ) async {
      await tester.pumpWidget(_subject(currentXp: 150));
      expect(find.text('Locked'), findsWidgets);
      expect(
        find.byKey(const ValueKey('rewardTrackClaim_tier_1_premium_Gems')),
        findsNothing,
      );

      await tester.pumpWidget(_subject(currentXp: 150, premiumEnabled: true));
      expect(
        find.byKey(const ValueKey('rewardTrackClaim_tier_1_premium_Gems')),
        findsOneWidget,
      );
    });

    testWidgets('claimed state and semantics reflect caller state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _subject(currentXp: 150, claimedFreeIds: const {'tier_1:free'}),
      );
      expect(find.text('Claimed'), findsOneWidget);

      final semantics = tester.widget<Semantics>(
        find.byKey(const ValueKey('rewardTrackSemantics')),
      );
      expect(semantics.properties.label, contains('150 XP'));
      expect(semantics.properties.label, contains('3 reward tiers'));
      expect(semantics.properties.label, contains('Premium locked'));
    });

    testWidgets('Reduced Motion renders without animation errors', (
      tester,
    ) async {
      await tester.pumpWidget(_subject(disableAnimations: true));
      expect(find.text('Reward Track'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolls horizontally to later tiers', (tester) async {
      await tester.pumpWidget(_subject(currentXp: 450));
      final scrollable = find.descendant(
        of: find.byKey(const ValueKey('rewardTrackScroll')),
        matching: find.byType(Scrollable),
      );
      await tester.drag(scrollable, const Offset(-300, 0));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('rewardTrackTier_tier_3')),
        findsOneWidget,
      );
    });
  });
}

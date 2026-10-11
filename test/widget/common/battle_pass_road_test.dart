import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/reward_transaction_pipeline.dart';
import 'package:roy_casual_kit/presentation/widgets/common/battle_pass_road.dart';

List<BattlePassMilestone> _milestones(int count) => [
  for (var i = 1; i <= count; i++)
    BattlePassMilestone(
      id: 'm$i',
      requiredProgress: i * 100,
      freeRewards: [RewardLine(currency: 'coin', amount: i * 10)],
      vipRewards: [RewardLine(currency: 'gem', amount: i)],
    ),
];

void main() {
  group('milestone helpers', () {
    test(
      'progress ratio clamps and interpolates between adjacent thresholds',
      () {
        expect(
          milestoneProgressRatio(
            progress: 150,
            previousThreshold: 100,
            nextThreshold: 200,
          ),
          0.5,
        );
        expect(
          milestoneProgressRatio(
            progress: 10,
            previousThreshold: 100,
            nextThreshold: 200,
          ),
          0,
        );
        expect(
          milestoneProgressRatio(
            progress: 300,
            previousThreshold: 100,
            nextThreshold: 200,
          ),
          1,
        );
      },
    );

    test('claim status is derived independently for free and VIP tracks', () {
      final milestone = _milestones(1).single;
      final statuses = battlePassMilestoneStatuses(
        milestone: milestone,
        progress: 100,
        vipEnabled: false,
        claimedFreeIds: const {},
        claimedVipIds: const {},
      );
      expect(statuses[0].status, BattlePassMilestoneStatus.claimable);
      expect(statuses[1].status, BattlePassMilestoneStatus.locked);
      expect(
        battlePassMilestoneStatuses(
          milestone: milestone,
          progress: 100,
          vipEnabled: true,
          claimedFreeIds: const {'m1'},
          claimedVipIds: const {},
        ).map((status) => status.status),
        [
          BattlePassMilestoneStatus.claimed,
          BattlePassMilestoneStatus.claimable,
        ],
      );
      expect(
        battlePassMilestoneStatuses(
          milestone: milestone,
          progress: 100,
          vipEnabled: false,
          claimedFreeIds: const {},
          claimedVipIds: const {'m1'},
        )[1].status,
        BattlePassMilestoneStatus.claimed,
      );
    });

    test('current milestone index selects next incomplete threshold', () {
      final milestones = _milestones(3);
      expect(currentBattlePassMilestoneIndex(milestones, 0), 0);
      expect(currentBattlePassMilestoneIndex(milestones, 150), 1);
      expect(currentBattlePassMilestoneIndex(milestones, 300), 2);
      expect(currentBattlePassMilestoneIndex(milestones, 500), 2);
    });

    test(
      'milestone model rejects empty id, zero threshold and empty free reward',
      () {
        expect(
          () => BattlePassMilestone(
            id: '',
            requiredProgress: 100,
            freeRewards: const [RewardLine(currency: 'coin', amount: 1)],
          ),
          throwsArgumentError,
        );
        expect(
          () => BattlePassMilestone(
            id: 'm0',
            requiredProgress: 0,
            freeRewards: const [RewardLine(currency: 'coin', amount: 1)],
          ),
          throwsArgumentError,
        );
        expect(
          () => BattlePassMilestone(
            id: 'm1',
            requiredProgress: 100,
            freeRewards: const [],
          ),
          throwsArgumentError,
        );
      },
    );
  });

  testWidgets('10 milestones build lazily and claim fires stable id/track', (
    tester,
  ) async {
    final claimed = <(String, BattlePassTrack)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 500,
            child: BattlePassRoad(
              milestones: _milestones(10),
              progress: 500,
              vipEnabled: true,
              claimedFreeIds: const {},
              claimedVipIds: const {},
              onClaimMilestone: (id, track) => claimed.add((id, track)),
            ),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('battlePassMilestone_m5')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('battlePassMilestone_m10')), findsNothing);
    final claim = find.byKey(const ValueKey('battlePassClaim_m5_vip'));
    expect(claim, findsOneWidget);
    await tester.tap(claim);
    expect(claimed, [('m5', BattlePassTrack.vip)]);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('battlePassMilestone_m10')),
      300,
      scrollable: find
          .descendant(
            of: find.byType(BattlePassRoad),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.byKey(const ValueKey('battlePassMilestone_m10')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked/claimed tracks have no active claim buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: BattlePassRoad(
              milestones: _milestones(2),
              progress: 100,
              vipEnabled: false,
              claimedFreeIds: const {'m1'},
              claimedVipIds: const {},
              onClaimMilestone: (_, _) => fail('locked/claimed cannot claim'),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('battlePassClaim_m1_free')), findsNothing);
    expect(find.byKey(const ValueKey('battlePassClaim_m1_vip')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('duplicate IDs and non-increasing thresholds are rejected', (
    tester,
  ) async {
    final duplicate = [
      ..._milestones(1),
      BattlePassMilestone(
        id: 'm1',
        requiredProgress: 200,
        freeRewards: const [RewardLine(currency: 'coin', amount: 1)],
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 300,
          child: BattlePassRoad(
            milestones: duplicate,
            progress: 0,
            vipEnabled: false,
            claimedFreeIds: const {},
            claimedVipIds: const {},
            onClaimMilestone: (_, _) {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isA<ArgumentError>());
  });
}

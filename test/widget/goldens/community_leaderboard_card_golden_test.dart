import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/community_leaderboard_card.dart';
import 'package:roy_casual_kit/presentation/widgets/common/tiered_leaderboard_row.dart';

import '../../support/golden_matrix.dart';

const _entries = [
  CommunityLeaderboardEntry(
    id: 'alpha',
    rank: 1,
    playerName: 'Alpha Guild',
    score: '25,000',
    zone: TierZone.promotion,
    tier: LeaderboardTier.diamond,
  ),
  CommunityLeaderboardEntry(
    id: 'beta',
    rank: 2,
    playerName: 'Beta Guild',
    score: '18,400',
    zone: TierZone.safe,
    tier: LeaderboardTier.gold,
    isCurrentPlayer: true,
  ),
  CommunityLeaderboardEntry(
    id: 'gamma',
    rank: 3,
    playerName: 'Gamma Guild',
    score: '15,200',
    zone: TierZone.demotion,
    tier: LeaderboardTier.silver,
  ),
];

void main() {
  testWidgets('CommunityLeaderboardCard entries qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: CommunityLeaderboardCard(entries: _entries),
      ),
      guidelines: const [],
    );
  });

  testWidgets('CommunityLeaderboardCard empty qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: CommunityLeaderboardCard(entries: const []),
      ),
      guidelines: const [],
    );
  });
}

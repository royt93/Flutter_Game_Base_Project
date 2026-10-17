import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/tiered_leaderboard_row.dart';

import '../../support/golden_matrix.dart';

void main() {
  testWidgets('TieredLeaderboardRow qua toàn bộ ma trận Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => TieredLeaderboardRow(
        rank: 1,
        playerName: 'Alexandra Champion',
        score: '15,420',
        tier: LeaderboardTier.diamond,
        zone: TierZone.promotion,
        isCurrentPlayer: true,
        onTap: () {},
        avatar: const CircleAvatar(child: Text('AC')),
      ),
    );
  });
}

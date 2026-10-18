import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/achievement_roadmap_card.dart';
import 'package:roy_casual_kit/presentation/widgets/common/milestone_celebration_dialog.dart';

import '../../support/golden_matrix.dart';

final _items = [
  AchievementRoadmapItem(
    id: 'collector',
    title: 'Collect 100 items',
    description: 'Find collectibles in every region',
    progress: 62,
    target: 100,
    reward: MilestoneReward(
      icon: Icons.diamond_rounded,
      label: 'Gems',
      amountLabel: 'x50',
    ),
  ),
  AchievementRoadmapItem(
    id: 'champion',
    title: 'Win 25 matches',
    progress: 25,
    target: 25,
    reward: MilestoneReward(icon: Icons.emoji_events_rounded, label: 'Trophy'),
  ),
  AchievementRoadmapItem(
    id: 'explorer',
    title: 'Visit 10 worlds',
    progress: 4,
    target: 10,
    reward: MilestoneReward(icon: Icons.public_rounded, label: 'Map Skin'),
    isClaimed: true,
  ),
];

void main() {
  testWidgets('AchievementRoadmapCard mixed progress qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: AchievementRoadmapCard(items: _items, onClaim: (_) {}),
      ),
      guidelines: const [],
    );
  });

  testWidgets('AchievementRoadmapCard empty qua Golden Matrix', (tester) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: AchievementRoadmapCard(items: const [], onClaim: (_) {}),
      ),
      guidelines: const [],
    );
  });
}

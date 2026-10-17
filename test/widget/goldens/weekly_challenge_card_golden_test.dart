import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/weekly_challenge_card.dart';
import '../../support/golden_matrix.dart';

void main() {
  testWidgets('WeeklyChallengeCard qua toàn bộ ma trận Golden Matrix', (
    tester,
  ) async {
    final expires = DateTime.now().add(const Duration(days: 3, hours: 4));
    await runGoldenMatrix(
      tester,
      (context) => SizedBox(
        width: 320,
        child: WeeklyChallengeCard(
          title: 'Weekly Grand Race',
          subtitle: 'Collect stars this week',
          expiresAt: expires,
          currentProgress: 60,
          targetProgress: 100,
          milestones: [
            ChallengeMilestone(target: 30, label: 'Tier 1'),
            ChallengeMilestone(target: 70, label: 'Tier 2'),
          ],
        ),
      ),
      guidelines: const [], // thẻ chứa chip mốc nhỏ
    );
  });
}

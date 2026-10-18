import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/comeback_bundle_card.dart';
import 'package:roy_casual_kit/presentation/widgets/common/milestone_celebration_dialog.dart';

import '../../support/golden_matrix.dart';

final _rewards = [
  MilestoneReward(
    icon: const IconData(0xe1d3, fontFamily: 'MaterialIcons'),
    label: 'Gems',
    amountLabel: 'x250',
  ),
  MilestoneReward(
    icon: const IconData(0xe3e7, fontFamily: 'MaterialIcons'),
    label: 'Energy',
    amountLabel: 'x5',
  ),
];

void main() {
  testWidgets('ComebackBundleCard active bundle qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: ComebackBundleCard(
          title: 'Welcome Back!',
          body: 'A return gift prepared just for you.',
          absenceLabel: '10 days away',
          rewards: _rewards,
          expiryLabel: 'Available for 23h',
          badgeLabel: 'RETURN GIFT',
          onClaim: () {},
          onViewOffer: () {},
        ),
      ),
      guidelines: const [],
    );
  });

  testWidgets('ComebackBundleCard expired bundle qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: ComebackBundleCard(
          title: 'Comeback Pack',
          body: 'This return offer has ended.',
          absenceLabel: '30 days away',
          rewards: _rewards,
          expiryLabel: 'Expired yesterday',
          isExpired: true,
          badgeLabel: 'EXPIRED',
          onClaim: () {},
        ),
      ),
      guidelines: const [],
    );
  });
}

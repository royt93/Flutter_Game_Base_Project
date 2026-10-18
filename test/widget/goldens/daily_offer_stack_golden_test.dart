import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/daily_offer_stack.dart';

import '../../support/golden_matrix.dart';

const _offers = [
  DailyOffer(
    id: 'starter',
    title: 'Starter Pack',
    priceLabel: r'$1.99',
    subtitle: 'Coins, gems and bonus lives',
    badgeLabel: 'BEST VALUE',
  ),
  DailyOffer(
    id: 'coins',
    title: 'Coin Pouch',
    priceLabel: r'$0.99',
    subtitle: 'Limited time offer',
    icon: Icons.monetization_on_rounded,
  ),
];

void main() {
  testWidgets('DailyOfferStack active offers qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: DailyOfferStack(offers: _offers, onOpen: (_) {}),
      ),
      guidelines: const [],
    );
  });

  testWidgets('DailyOfferStack mix expired offers qua Golden Matrix', (
    tester,
  ) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: DailyOfferStack(
          offers: const [
            DailyOffer(
              id: 'active',
              title: 'Active Event Pack',
              priceLabel: r'$2.99',
              badgeLabel: 'EVENT',
            ),
            DailyOffer(
              id: 'expired',
              title: 'Expired Offer',
              priceLabel: r'$0.99',
              isExpired: true,
            ),
          ],
          onOpen: (_) {},
        ),
      ),
      guidelines: const [],
    );
  });

  testWidgets('DailyOfferStack empty qua Golden Matrix', (tester) async {
    await runGoldenMatrix(
      tester,
      (context) => SingleChildScrollView(
        child: DailyOfferStack(offers: const [], onOpen: (_) {}),
      ),
      guidelines: const [],
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

const _offers = [
  DailyOffer(
    id: 'starter',
    title: 'Starter Pack',
    priceLabel: r'$1.99',
    subtitle: 'Great value for new players',
    badgeLabel: 'BEST VALUE',
  ),
  DailyOffer(
    id: 'coins',
    title: 'Coin Pouch',
    priceLabel: r'$0.99',
    subtitle: 'Limited time',
    icon: Icons.monetization_on_rounded,
  ),
];

Widget _subject({
  List<DailyOffer> offers = _offers,
  ValueChanged<String>? onOpen,
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SingleChildScrollView(
        child: DailyOfferStack(offers: offers, onOpen: onOpen ?? (_) {}),
      ),
    ),
  ),
);

void main() {
  group('DailyOfferStack validation', () {
    test('rejects duplicate IDs and empty required fields', () {
      expect(
        () => DailyOfferStack(
          offers: const [
            DailyOffer(id: 'duplicate', title: 'One', priceLabel: 'Free'),
            DailyOffer(id: 'duplicate', title: 'Two', priceLabel: 'Free'),
          ],
          onOpen: (_) {},
        ),
        throwsArgumentError,
      );
      expect(
        () => DailyOfferStack(
          offers: const [
            DailyOffer(id: ' ', title: 'Title', priceLabel: 'Free'),
          ],
          onOpen: (_) {},
        ),
        throwsArgumentError,
      );
      expect(
        () => DailyOfferStack(
          offers: const [DailyOffer(id: 'id', title: ' ', priceLabel: 'Free')],
          onOpen: (_) {},
        ),
        throwsArgumentError,
      );
      expect(
        () => DailyOfferStack(
          offers: const [DailyOffer(id: 'id', title: 'Title', priceLabel: ' ')],
          onOpen: (_) {},
        ),
        throwsArgumentError,
      );
    });

    test('rejects empty title and empty state message', () {
      expect(
        () => DailyOfferStack(offers: _offers, onOpen: (_) {}, title: ' '),
        throwsArgumentError,
      );
      expect(
        () =>
            DailyOfferStack(offers: const [], onOpen: (_) {}, emptyMessage: ''),
        throwsArgumentError,
      );
    });
  });

  group('DailyOfferStack UI', () {
    testWidgets('preserves caller order and routes offer id', (tester) async {
      String? opened;
      await tester.pumpWidget(_subject(onOpen: (id) => opened = id));

      expect(
        tester.getTopLeft(find.byKey(const ValueKey('dailyOffer_starter'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('dailyOffer_coins'))).dy,
        ),
      );
      expect(find.text('BEST VALUE'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('dailyOfferOpen_coins')));
      await tester.pump();
      expect(opened, 'coins');
    });

    testWidgets('expired offer is labeled and disabled', (tester) async {
      await tester.pumpWidget(
        _subject(
          offers: const [
            DailyOffer(
              id: 'expired',
              title: 'Old Offer',
              priceLabel: r'$1.00',
              isExpired: true,
            ),
          ],
        ),
      );
      final btn = tester.widget<CommonButton>(
        find.byKey(const ValueKey('dailyOfferOpen_expired')),
      );
      expect(btn.label, 'Expired');
      expect(btn.onTap, isNull);
    });

    testWidgets('empty state is shown', (tester) async {
      await tester.pumpWidget(_subject(offers: const []));
      expect(find.text('No offers available right now.'), findsOneWidget);
      expect(find.byKey(const ValueKey('dailyOfferList')), findsNothing);
    });

    testWidgets('semantics reports offer count', (tester) async {
      await tester.pumpWidget(_subject());
      final semantics = tester.widget<Semantics>(
        find.byKey(const ValueKey('dailyOfferStackSemantics')),
      );
      expect(semantics.properties.label, 'Daily Offers. 2 offers.');
    });

    testWidgets('no overflow at text scale 2.0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const SizedBox.shrink(),
        ),
      );
      await tester.pumpWidget(_subject());
      expect(tester.takeException(), isNull);
    });
  });
}

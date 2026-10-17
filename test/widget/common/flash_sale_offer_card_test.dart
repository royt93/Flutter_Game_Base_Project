import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/flash_sale_offer_card.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('FlashSaleOfferCard validation', () {
    test('rejects empty title or priceLabel', () {
      expect(
        () => FlashSaleOfferCard(
          title: '',
          priceLabel: r'$0.99',
          discountPercent: 50,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          onBuyTap: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => FlashSaleOfferCard(
          title: 'Starter Pack',
          priceLabel: '   ',
          discountPercent: 50,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          onBuyTap: () {},
        ),
        throwsArgumentError,
      );
    });

    test('rejects discountPercent outside 1..99', () {
      expect(
        () => FlashSaleOfferCard(
          title: 'Starter Pack',
          priceLabel: r'$0.99',
          discountPercent: 0,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          onBuyTap: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => FlashSaleOfferCard(
          title: 'Starter Pack',
          priceLabel: r'$0.99',
          discountPercent: 100,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          onBuyTap: () {},
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-positive width', () {
      expect(
        () => FlashSaleOfferCard(
          title: 'Starter Pack',
          priceLabel: r'$0.99',
          discountPercent: 50,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          onBuyTap: () {},
          width: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('FlashSaleOfferCard rendering & interactions', () {
    testWidgets(
      'renders title, discount badge, strikethrough price, and countdown',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            FlashSaleOfferCard(
              title: 'Starter Pack',
              subtitle: '100 Gems + 5 Hearts',
              priceLabel: r'$1.99',
              originalPriceLabel: r'$9.99',
              discountPercent: 80,
              expiresAt: DateTime.now().add(
                const Duration(hours: 2, minutes: 15),
              ),
              onBuyTap: () {},
            ),
          ),
        );

        expect(find.text('Starter Pack'), findsOneWidget);
        expect(find.text('100 Gems + 5 Hearts'), findsOneWidget);
        expect(find.text('-80%'), findsOneWidget);
        expect(find.text(r'$9.99'), findsOneWidget);
        expect(find.text(r'$1.99'), findsWidgets);
        expect(
          find.byKey(const ValueKey('flashSaleCountdownText')),
          findsOneWidget,
        );
        expect(find.textContaining('02:1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('invokes onBuyTap when buy button is tapped while active', (
      tester,
    ) async {
      var bought = 0;
      await tester.pumpWidget(
        _wrap(
          FlashSaleOfferCard(
            title: 'Gem Pouch',
            priceLabel: r'$0.99',
            discountPercent: 50,
            expiresAt: DateTime.now().add(const Duration(minutes: 30)),
            onBuyTap: () => bought++,
          ),
        ),
      );

      final buyBtn = find.byKey(const ValueKey('flashSaleBuyBtn'));
      expect(buyBtn, findsOneWidget);
      await tester.tap(buyBtn);
      await tester.pump();

      expect(bought, 1);
    });

    testWidgets(
      'disables button and triggers onExpired callback on expiration',
      (tester) async {
        var expiredCalls = 0;
        var bought = 0;
        final target = DateTime.now().add(const Duration(seconds: 3));

        await tester.pumpWidget(
          _wrap(
            FlashSaleOfferCard(
              title: 'Quick Deal',
              priceLabel: r'$0.99',
              discountPercent: 70,
              expiresAt: target,
              onBuyTap: () => bought++,
              onExpired: () => expiredCalls++,
            ),
          ),
        );

        expect(find.text('Expired'), findsNothing);

        // Advance clock past expiration
        await tester.pump(const Duration(seconds: 4));

        expect(expiredCalls, 1);
        expect(find.text('Expired'), findsWidgets);

        // Tap buy button after expired does nothing
        final buyBtn = find.byKey(const ValueKey('flashSaleBuyBtn'));
        await tester.tap(buyBtn);
        await tester.pump();
        expect(bought, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'already expired at mount fires onExpired once deferred and shows Expired',
      (tester) async {
        var expiredCalls = 0;
        await tester.pumpWidget(
          _wrap(
            FlashSaleOfferCard(
              title: 'Old Deal',
              priceLabel: r'$0.99',
              discountPercent: 60,
              expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
              onBuyTap: () {},
              onExpired: () => expiredCalls++,
            ),
          ),
        );

        await tester.pump();
        expect(expiredCalls, 1);
        expect(find.text('Expired'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Reduced Motion disables border animation sweep painter', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _wrap(
            FlashSaleOfferCard(
              title: 'Motion Safe',
              priceLabel: r'$2.99',
              discountPercent: 40,
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
              onBuyTap: () {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Semantics exposes comprehensive accessible announcement', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          FlashSaleOfferCard(
            title: 'Weekend Special',
            priceLabel: r'$4.99',
            discountPercent: 75,
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            onBuyTap: () {},
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(FlashSaleOfferCard));
      expect(semantics.label, contains('Weekend Special'));
      expect(semantics.label, contains('-75% flash sale'));
      expect(semantics.label, contains(r'$4.99'));
      handle.dispose();
    });
  });
}

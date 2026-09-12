import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/shop_item_card.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Material(child: Center(child: child)),
);

void main() {
  testWidgets('ShopItemCard basic layout', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ShopItemCard(
          icon: Icons.diamond_rounded,
          title: '100 Gems',
          priceLabel: r'$0.99',
          onBuy: () {},
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(ShopItemCard),
      matchesGoldenFile('shop_item_card_basic.png'),
    );
  });

  testWidgets('ShopItemCard with ribbon', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ShopItemCard(
          icon: Icons.diamond_rounded,
          title: 'Mega Pack',
          priceLabel: r'$4.99',
          ribbonText: 'BEST VALUE',
          ribbonColor: NeonTheme.gold,
          onBuy: () {},
        ),
      ),
    );
    // Chờ RibbonBadge's entrance pop-in (200ms, IDEA-27) settle trước khi
    // chụp golden.
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ShopItemCard),
      matchesGoldenFile('shop_item_card_ribbon.png'),
    );
  });
}

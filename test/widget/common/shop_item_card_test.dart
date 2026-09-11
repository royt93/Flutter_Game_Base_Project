import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/panel_card.dart';
import 'package:roy_casual_kit/presentation/widgets/common/ribbon_badge.dart';
import 'package:roy_casual_kit/presentation/widgets/common/shop_item_card.dart';

void main() {
  testWidgets('ShopItemCard shows title/priceLabel and reuses PanelCard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: ShopItemCard(
            icon: Icons.diamond_rounded,
            title: '100 Gems',
            priceLabel: r'$0.99',
            onBuy: () {},
          ),
        ),
      ),
    );

    expect(find.text('100 Gems'), findsOneWidget);
    expect(find.byType(PanelCard), findsOneWidget);
    expect(find.byType(CommonButton), findsOneWidget);
    expect(find.byType(RibbonBadge), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ShopItemCard with ribbonText wraps in a RibbonBadge', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: ShopItemCard(
            icon: Icons.diamond_rounded,
            title: '100 Gems',
            priceLabel: r'$0.99',
            ribbonText: 'SALE',
            onBuy: () {},
          ),
        ),
      ),
    );

    final ribbon = tester.widget<RibbonBadge>(find.byType(RibbonBadge));
    expect(ribbon.text, 'SALE');
    expect(tester.takeException(), isNull);
  });

  testWidgets('ShopItemCard tap calls onBuy', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: ShopItemCard(
            icon: Icons.diamond_rounded,
            title: '100 Gems',
            priceLabel: r'$0.99',
            onBuy: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CommonButton));
    await tester.pump();

    expect(tapped, true);
  });

  testWidgets('ShopItemCard onBuy == null disables the buy button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: ShopItemCard(
            icon: Icons.diamond_rounded,
            title: '100 Gems',
            priceLabel: r'$0.99',
            onBuy: null,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CommonButton));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('IDEA-26: icon có glow backdrop nhất quán với AvatarFrame', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: ShopItemCard(
            icon: Icons.diamond_rounded,
            title: '100 Gems',
            priceLabel: r'$0.99',
            onBuy: () {},
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.diamond_rounded),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration as BoxDecoration?;
    expect(decoration?.boxShadow, isNotNull);
    expect(decoration!.boxShadow!.isNotEmpty, true);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

  group('ENH-44: buttonColor/buttonVariant + merged semantics', () {
    testWidgets('mặc định (không truyền) → CommonButton vẫn primary, màu mặc định', (
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

      final button = tester.widget<CommonButton>(find.byType(CommonButton));
      expect(button.variant, CommonButtonVariant.primary);
      expect(button.color, isNull);
    });

    testWidgets('buttonColor/buttonVariant truyền vào áp dụng đúng cho CommonButton', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: ShopItemCard(
              icon: Icons.diamond_rounded,
              title: 'Best Value',
              priceLabel: r'$9.99',
              onBuy: () {},
              buttonColor: Colors.amber,
              buttonVariant: CommonButtonVariant.secondary,
            ),
          ),
        ),
      );

      final button = tester.widget<CommonButton>(find.byType(CommonButton));
      expect(button.variant, CommonButtonVariant.secondary);
      expect(button.color, Colors.amber);
    });

    testWidgets(
      'Semantics gộp title + priceLabel + ribbonText vào 1 node duy nhất '
      '(MergeSemantics), vẫn giữ được vai trò button/tap',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: ShopItemCard(
                icon: Icons.diamond_rounded,
                title: 'Mega Pack',
                priceLabel: r'$4.99',
                ribbonText: 'BEST VALUE',
                onBuy: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Toàn bộ card giờ chỉ có ĐÚNG 1 semantics node duy nhất chứa
        // action "tap" (thay vì rải rác nhiều node con) — MergeSemantics
        // đã gộp title/price/ribbon/button vào node này.
        final data = tester.getSemantics(find.byType(ShopItemCard));
        expect(data.label, contains('Mega Pack'));
        expect(data.label, contains(r'$4.99'));
        expect(data.label, contains('BEST VALUE'));
        expect(data.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        handle.dispose();
      },
    );

    testWidgets('Semantics không có ribbonText vẫn gộp title + priceLabel', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
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
      await tester.pumpAndSettle();

      final data = tester.getSemantics(find.byType(ShopItemCard));
      expect(data.label, contains('100 Gems'));
      expect(data.label, contains(r'$0.99'));
      expect(data.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });
  });

  group('ENH-66: loading', () {
    testWidgets('loading: true truyền đúng xuống CommonButton, hiện spinner', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: ShopItemCard(
              icon: Icons.diamond_rounded,
              title: '100 Gems',
              priceLabel: r'$0.99',
              loading: true,
              onBuy: () {},
            ),
          ),
        ),
      );

      final button = tester.widget<CommonButton>(find.byType(CommonButton));
      expect(button.loading, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('loading: true chặn onBuy (double-tap trong lúc chờ async)', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: ShopItemCard(
              icon: Icons.diamond_rounded,
              title: '100 Gems',
              priceLabel: r'$0.99',
              loading: true,
              onBuy: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CommonButton));
      await tester.pump();

      expect(tapped, isFalse);
    });

    testWidgets('loading: false (mặc định) hành vi y hệt trước đây', (
      tester,
    ) async {
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

      final button = tester.widget<CommonButton>(find.byType(CommonButton));
      expect(button.loading, isFalse);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.byType(CommonButton));
      expect(tapped, isTrue);
    });

    testWidgets('MergeSemantics label vẫn phản ánh đúng trạng thái loading', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: ShopItemCard(
              icon: Icons.diamond_rounded,
              title: '100 Gems',
              priceLabel: r'$0.99',
              loading: true,
              onBuy: () {},
            ),
          ),
        ),
      );
      // Không pumpAndSettle() — CircularProgressIndicator's animation chạy
      // vô thời hạn khi loading, sẽ không bao giờ settle.
      await tester.pump();

      final data = tester.getSemantics(find.byType(ShopItemCard));
      expect(data.label, contains('loading'));
      handle.dispose();
    });
  });
}

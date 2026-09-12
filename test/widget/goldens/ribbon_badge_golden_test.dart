import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/ribbon_badge.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Material(
    child: Center(
      child: SizedBox(
        width: 160,
        height: 120,
        child: Container(color: NeonTheme.cardAlt, child: child),
      ),
    ),
  ),
);

void main() {
  testWidgets('RibbonBadge default color', (tester) async {
    await tester.pumpWidget(
      _wrap(const RibbonBadge(text: 'SALE', child: SizedBox.expand())),
    );
    // Chờ entrance pop-in (200ms, ENH-27/IDEA-27) hoàn tất trước khi chụp —
    // golden phải phản ánh trạng thái đã settle (scale = 1.0), không phải
    // giữa chừng pop.
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(RibbonBadge),
      matchesGoldenFile('ribbon_badge_default.png'),
    );
  });

  testWidgets('RibbonBadge custom color', (tester) async {
    await tester.pumpWidget(
      _wrap(
        RibbonBadge(
          text: 'NEW',
          color: NeonTheme.cyan,
          child: const SizedBox.expand(),
        ),
      ),
    );
    // Chờ entrance pop-in (200ms, ENH-27/IDEA-27) hoàn tất trước khi chụp —
    // golden phải phản ánh trạng thái đã settle (scale = 1.0), không phải
    // giữa chừng pop.
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(RibbonBadge),
      matchesGoldenFile('ribbon_badge_custom_color.png'),
    );
  });

  testWidgets('RibbonBadge long text', (tester) async {
    await tester.pumpWidget(
      _wrap(
        RibbonBadge(
          text: 'BEST VALUE',
          color: NeonTheme.gold,
          child: const SizedBox.expand(),
        ),
      ),
    );
    // Chờ entrance pop-in (200ms, ENH-27/IDEA-27) hoàn tất trước khi chụp —
    // golden phải phản ánh trạng thái đã settle (scale = 1.0), không phải
    // giữa chừng pop.
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(RibbonBadge),
      matchesGoldenFile('ribbon_badge_long_text.png'),
    );
  });
}

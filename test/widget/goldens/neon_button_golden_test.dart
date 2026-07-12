import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/neon_theme.dart';
import 'package:pop_star_blast/presentation/widgets/neon_button.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Material(
    child: Center(child: SizedBox(width: 260, height: 80, child: child)),
  ),
);

void main() {
  testWidgets('NeonButton enabled', (tester) async {
    await tester.pumpWidget(
      _wrap(NeonButton(label: 'PLAY', color: NeonTheme.lime, onTap: () {})),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NeonButton),
      matchesGoldenFile('neon_button_enabled.png'),
    );
  });

  testWidgets('NeonButton disabled', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const NeonButton(label: 'PLAY', color: NeonTheme.lime, onTap: null),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NeonButton),
      matchesGoldenFile('neon_button_disabled.png'),
    );
  });

  testWidgets('NeonButton with icon', (tester) async {
    await tester.pumpWidget(
      _wrap(
        NeonButton(
          label: 'SHOP',
          color: NeonTheme.purple,
          icon: Icons.shopping_bag_rounded,
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NeonButton),
      matchesGoldenFile('neon_button_icon.png'),
    );
  });
}

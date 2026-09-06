import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_icon.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Material(
    child: Center(child: SizedBox(width: 80, height: 80, child: child)),
  ),
);

void main() {
  testWidgets('NeonIcon plain', (tester) async {
    await tester.pumpWidget(
      _wrap(
        NeonIcon(Icons.star_rounded, color: NeonTheme.gold, size: 40),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(NeonIcon),
      matchesGoldenFile('neon_icon.png'),
    );
  });

  testWidgets('NeonIconButton boxed enabled', (tester) async {
    await tester.pumpWidget(
      _wrap(
        NeonIconButton(
          Icons.settings_rounded,
          color: NeonTheme.cyan,
          onTap: () {},
          boxed: true,
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(NeonIconButton),
      matchesGoldenFile('neon_icon_button_boxed.png'),
    );
  });

  testWidgets('NeonIconButton boxed disabled', (tester) async {
    await tester.pumpWidget(
      _wrap(
        NeonIconButton(
          Icons.settings_rounded,
          color: NeonTheme.cyan,
          onTap: null,
          boxed: true,
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(NeonIconButton),
      matchesGoldenFile('neon_icon_button_boxed_disabled.png'),
    );
  });
}

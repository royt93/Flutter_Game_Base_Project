import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neon_jewels/core/neon_theme.dart';
import 'package:neon_jewels/presentation/widgets/neon_button.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('hiển thị nhãn', (tester) async {
    await tester.pumpWidget(wrap(
      NeonButton(label: 'CHƠI', color: NeonTheme.cyan, onTap: () {}),
    ));
    expect(find.text('CHƠI'), findsOneWidget);
  });

  testWidgets('tap gọi callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(
      NeonButton(label: 'GO', color: NeonTheme.lime, onTap: () => tapped = true),
    ));
    await tester.tap(find.text('GO'));
    expect(tapped, isTrue);
  });

  testWidgets('disabled (onTap null) không glow & không crash khi tap', (tester) async {
    await tester.pumpWidget(wrap(
      const NeonButton(label: 'OFF', color: NeonTheme.magenta, onTap: null),
    ));
    await tester.tap(find.text('OFF'));
    expect(find.text('OFF'), findsOneWidget);
  });

  testWidgets('hiển thị icon khi truyền vào', (tester) async {
    await tester.pumpWidget(wrap(
      NeonButton(
        label: 'PLAY',
        color: NeonTheme.cyan,
        icon: Icons.play_arrow_rounded,
        onTap: () {},
      ),
    ));
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });
}

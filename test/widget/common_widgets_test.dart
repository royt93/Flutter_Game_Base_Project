import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neon_jewels/core/neon_theme.dart';
import 'package:neon_jewels/presentation/widgets/neon_app_bar.dart';
import 'package:neon_jewels/presentation/widgets/neon_bg.dart';
import 'package:neon_jewels/presentation/widgets/neon_dialog.dart';
import 'package:neon_jewels/presentation/widgets/neon_icon.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('NeonBg bọc và hiển thị child', (tester) async {
    await tester.pumpWidget(wrap(const NeonBg(child: Text('xin chào'))));
    expect(find.text('xin chào'), findsOneWidget);
  });

  testWidgets('NeonAppBar hiển thị tiêu đề', (tester) async {
    await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: NeonAppBar(title: 'TIÊU ĐỀ'))));
    expect(find.text('TIÊU ĐỀ'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('NeonAppBar nút back gọi onBack', (tester) async {
    var tapped = false;
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
        body: NeonAppBar(
          title: 'X',
          color: NeonTheme.cyan,
          onBack: () => tapped = true,
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    expect(tapped, isTrue);
  });

  testWidgets('NeonIcon render được', (tester) async {
    await tester.pumpWidget(
        wrap(const NeonIcon(Icons.star, color: NeonTheme.lime)));
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('NeonDialog.show hiển thị dialog + nút', (tester) async {
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () => NeonDialog.show(
                title: 'QUIT?',
                color: NeonTheme.magenta,
                actions: [
                  NeonDialogAction(
                      label: 'CANCEL', color: NeonTheme.cyan, onTap: () {}),
                  NeonDialogAction(
                      label: 'OK', color: NeonTheme.magenta, onTap: () {}),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('QUIT?'), findsOneWidget);
    expect(find.text('CANCEL'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });
}

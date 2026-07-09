import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neon_jewels/core/neon_theme.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/widgets/coin_chip.dart';
import 'package:neon_jewels/presentation/widgets/neon_app_bar.dart';
import 'package:neon_jewels/presentation/widgets/neon_bg.dart';
import 'package:neon_jewels/presentation/widgets/neon_dialog.dart';
import 'package:neon_jewels/presentation/widgets/neon_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('NeonBg bọc và hiển thị child', (tester) async {
    await tester.pumpWidget(wrap(const NeonBg(child: Text('xin chào'))));
    expect(find.text('xin chào'), findsOneWidget);
  });

  testWidgets('NeonAppBar hiển thị tiêu đề', (tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(body: NeonAppBar(title: 'TIÊU ĐỀ')),
      ),
    );
    expect(find.text('TIÊU ĐỀ'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('NeonAppBar nút back gọi onBack', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: NeonAppBar(
            title: 'X',
            color: NeonTheme.cyan,
            onBack: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    expect(tapped, isTrue);
  });

  testWidgets('NeonIcon render được', (tester) async {
    await tester.pumpWidget(
      wrap(const NeonIcon(Icons.star, color: NeonTheme.lime)),
    );
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('NeonDialog.show hiển thị dialog + nút', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => NeonDialog.show(
                  context: ctx,
                  title: 'QUIT?',
                  color: NeonTheme.magenta,
                  actions: [
                    NeonDialogAction(
                      label: 'CANCEL',
                      color: NeonTheme.cyan,
                      onTap: () {},
                    ),
                    NeonDialogAction(
                      label: 'OK',
                      color: NeonTheme.magenta,
                      onTap: () {},
                    ),
                  ],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('QUIT?'), findsOneWidget);
    expect(find.text('CANCEL'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });

  // Audit gap: CoinChip (action bar Đền Neon/Thành tựu/Level Select/World
  // Map) 0 test trước bản vá này — không khoá render số xu + phản ứng
  // reactive khi coins đổi.
  group('CoinChip', () {
    late GameController c;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      Get.put(StorageService(await SharedPreferences.getInstance()));
      c = Get.put(GameController());
    });
    tearDown(Get.reset);

    testWidgets('hiển thị số xu hiện tại + icon vàng', (tester) async {
      c.coins.value = 1234;
      await tester.pumpWidget(wrap(CoinChip(c)));
      expect(find.text('1,234'), findsOneWidget);
      expect(find.byIcon(Icons.monetization_on_rounded), findsOneWidget);
    });

    testWidgets(
      'reactive: coins đổi → text cập nhật không cần pump lại widget',
      (tester) async {
        c.coins.value = 0;
        await tester.pumpWidget(wrap(CoinChip(c)));
        expect(find.text('0'), findsOneWidget);
        c.coins.value = 500;
        await tester.pump();
        expect(find.text('500'), findsOneWidget);
        expect(find.text('0'), findsNothing);
      },
    );
  });
}

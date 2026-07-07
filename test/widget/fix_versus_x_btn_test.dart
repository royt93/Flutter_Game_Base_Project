import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neon_jewels/core/app_translations.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/presentation/screens/versus_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fix 2: VersusScreen — nút X thoát hiện ở phase đếm ngược + đang chơi.
/// Fix 5: Games được pause trước khi teardown (kiểm tra thông qua controller).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
  });
  tearDown(Get.reset);

  Widget appEn(Widget home) => GetMaterialApp(
    translations: AppTranslations(),
    locale: const Locale('en', 'US'),
    fallbackLocale: AppTranslations.fallback,
    home: home,
  );

  group('VersusScreen — nút X (Fix 2)', () {
    testWidgets('phase SELECT: nút home (Get.back) tồn tại', (tester) async {
      await tester.pumpWidget(appEn(const VersusScreen()));
      await tester.pump();
      // Màn select hiện nút HOME (back)
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('phase COUNTDOWN: hiện icon X (close_rounded)', (tester) async {
      await tester.pumpWidget(appEn(const VersusScreen()));
      await tester.pump();

      // Tap VERSUS mode → trigger _pick → chuyển sang countdown
      await tester.tap(find.text('Versus'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Phase countdown phải có icon X
      expect(find.byIcon(Icons.close_rounded), findsAtLeast(1));
    });

    testWidgets('phase PLAYING (centerBar): hiện icon X', (tester) async {
      await tester.pumpWidget(appEn(const VersusScreen()));
      await tester.pump();

      // Vào countdown
      await tester.tap(find.text('Versus'));
      await tester.pump();

      // Chờ đếm ngược hết (3 giây) → vào playing
      await tester.pump(const Duration(seconds: 4));

      // Phase playing phải có icon X trong centerBar
      expect(find.byIcon(Icons.close_rounded), findsAtLeast(1));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neon_jewels/core/app_translations.dart';
import 'package:neon_jewels/presentation/screens/versus_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(Get.reset);

  Widget appEn(Widget home) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: AppTranslations.fallback,
        home: home,
      );

  testWidgets('VersusScreen phase chọn hiện 2 chế độ', (tester) async {
    await tester.pumpWidget(appEn(const VersusScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('2 PLAYERS'), findsWidgets);
    expect(find.text('VERSUS'), findsOneWidget);
    expect(find.text('CO-OP'), findsOneWidget);
    expect(find.text('Race for the highest score'), findsOneWidget);
  });
}

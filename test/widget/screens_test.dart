import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neon_jewels/core/app_translations.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/screens/guide_screen.dart';
import 'package:neon_jewels/presentation/screens/home_screen.dart';
import 'package:neon_jewels/presentation/screens/level_select_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
  });
  tearDown(Get.reset);

  // App giả lập với i18n English (default).
  Widget appEn(Widget home) => GetMaterialApp(
    translations: AppTranslations(),
    locale: const Locale('en', 'US'),
    fallbackLocale: AppTranslations.fallback,
    home: home,
  );

  testWidgets('HomeScreen hiển thị tiêu đề & nút chơi (English default)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(appEn(const HomeScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('NEON'), findsOneWidget);
    expect(find.text('JEWELS'), findsOneWidget);
    expect(find.text('PLAY NOW'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
  });

  testWidgets('LevelSelectScreen render đủ tile level', (tester) async {
    Get.put(GameController());
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(appEn(const LevelSelectScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('SELECT LEVEL'), findsOneWidget);
    expect(find.text('1'), findsWidgets); // emblem nổi bật + mini tile
  });

  testWidgets('LevelSelectScreen khóa level chưa unlock (hiện icon khóa)', (
    tester,
  ) async {
    Get.put(GameController());
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(appEn(const LevelSelectScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);
  });

  testWidgets('GuideScreen hiển thị các mục hướng dẫn', (tester) async {
    await tester.pumpWidget(appEn(const GuideScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('HOW TO PLAY'), findsWidgets);
    expect(find.text('Special Gems'), findsOneWidget);
    expect(find.text('Game Modes'), findsOneWidget);
  });
}

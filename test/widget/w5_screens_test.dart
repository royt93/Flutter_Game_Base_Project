import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neon_jewels/core/app_translations.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/screens/achievements_screen.dart';
import 'package:neon_jewels/presentation/screens/home_screen.dart';
import 'package:neon_jewels/presentation/screens/level_select_screen.dart';
import 'package:neon_jewels/presentation/screens/world_map_screen.dart';
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

  Widget appEn(Widget home) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: AppTranslations.fallback,
        home: home,
      );

  group('AchievementsScreen', () {
    testWidgets('render tiêu đề + thành tựu + icon khoá', (tester) async {
      Get.put(GameController());
      await tester.pumpWidget(appEn(const AchievementsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ACHIEVEMENTS'), findsOneWidget);
      expect(find.text('First Win'), findsOneWidget); // ach_first_win_t
      expect(find.byIcon(Icons.lock_rounded), findsWidgets); // chưa đạt → khoá
    });
  });

  group('WorldMapScreen', () {
    testWidgets('render bản đồ + node 1 + nút chuyển grid', (tester) async {
      Get.put(GameController());
      await tester.pumpWidget(appEn(const WorldMapScreen()));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('WORLD MAP'), findsOneWidget);
      expect(find.text('1'), findsWidgets); // node màn 1
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    });

    testWidgets('bấm nút grid → lưu viewMode = 1 (local)', (tester) async {
      Get.put(GameController());
      await tester.pumpWidget(appEn(const WorldMapScreen()));
      await tester.pump(const Duration(milliseconds: 120));
      // viewMode ghi NGAY trong onPressed (đồng bộ, trước điều hướng)
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      expect(StorageService.to.getInt(StorageKeys.viewMode, def: 0), 1);
      // pump nhiều frame để màn đích mount xong (timer flutter_animate fire hết)
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    });
  });

  group('LevelSelectScreen', () {
    testWidgets('bấm nút map → lưu viewMode = 0 (local)', (tester) async {
      Get.put(GameController());
      StorageService.to.setInt(StorageKeys.viewMode, 1); // đang ở grid
      await tester.pumpWidget(appEn(const LevelSelectScreen()));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(find.byIcon(Icons.map_rounded));
      expect(StorageService.to.getInt(StorageKeys.viewMode, def: 9), 0);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    });

    testWidgets('bấm chơi → mở pre-game panel (có booster mặc định)',
        (tester) async {
      Get.put(GameController());
      await tester.pumpWidget(appEn(const LevelSelectScreen()));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(find.text('PLAY NOW').first); // tile nổi bật
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('GET READY'), findsOneWidget); // pregame_title
      expect(find.text('+10 starting moves'), findsOneWidget);
    });
  });

  group('HomeScreen Wave 5', () {
    testWidgets('có nút thành tựu + icon vòng quay/quà', (tester) async {
      await tester.pumpWidget(appEn(const HomeScreen()));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('ACHIEVEMENTS'), findsOneWidget);
      expect(find.byIcon(Icons.casino_rounded), findsOneWidget); // wheel
      expect(find.byIcon(Icons.card_giftcard_rounded), findsOneWidget); // daily
    });

    testWidgets('bấm nút vòng quay → overlay Lucky Wheel', (tester) async {
      await tester.pumpWidget(appEn(const HomeScreen()));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(find.byIcon(Icons.casino_rounded));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('LUCKY WHEEL'), findsOneWidget);
      expect(find.text('SPIN'), findsOneWidget);
    });

    testWidgets('bấm thành tựu → mở AchievementsScreen', (tester) async {
      await tester.pumpWidget(appEn(const HomeScreen()));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(find.text('ACHIEVEMENTS'));
      await tester.pump(); // bắt đầu chuyển route
      await tester.pump(const Duration(milliseconds: 400));
      // màn thành tựu hiện coin chip + thẻ
      expect(find.text('First Win'), findsOneWidget);
    });
  });
}

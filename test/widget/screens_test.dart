import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neon_jewels/core/app_translations.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/screens/game_screen.dart';
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

  Widget appEnScaled(Widget home, double textScale) => GetMaterialApp(
    translations: AppTranslations(),
    locale: const Locale('en', 'US'),
    fallbackLocale: AppTranslations.fallback,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
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
    expect(find.text('Play Now'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('HomeScreen thử thách dùng 13 card cùng size', (tester) async {
    tester.view.physicalSize = const Size(720, 1612);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(appEn(const HomeScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    final cards = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith('home_mode_card_');
    });
    expect(cards, findsNWidgets(13));

    final first = tester.getSize(cards.at(0));
    expect(first.height / first.width, lessThanOrEqualTo(1.45));
    for (var i = 1; i < 13; i++) {
      final size = tester.getSize(cards.at(i));
      expect(size.width, closeTo(first.width, 0.01), reason: 'card $i width');
      expect(
        size.height,
        closeTo(first.height, 0.01),
        reason: 'card $i height',
      );
    }
  });

  testWidgets('HomeScreen không crash/overflow ở font scale 1.5', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1612);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(appEnScaled(const HomeScreen(), 1.5));
    await tester.pump(const Duration(milliseconds: 120));

    expect(tester.takeException(), isNull);
    expect(find.text('NEON'), findsOneWidget);
    final cards = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith('home_mode_card_');
    });
    expect(cards, findsNWidgets(13));
  });

  testWidgets('LevelSelectScreen render đủ tile level', (tester) async {
    Get.put(GameController());
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(appEn(const LevelSelectScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Select Level'), findsOneWidget);
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
    expect(find.text('How To Play'), findsWidgets);
    expect(find.text('Special Gems'), findsOneWidget);
    expect(find.text('Game Modes'), findsOneWidget);
  });

  testWidgets('GameScreen Boss HUD render không crash trên màn hẹp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1612);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final g = Get.put(GameController());
    await tester.pump(const Duration(milliseconds: 30));
    g.startBoss(1);

    await tester.pumpWidget(appEn(const GameScreen()));
    await tester.pump(const Duration(milliseconds: 160));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Boss'), findsWidgets);
    expect(find.text('Phase 1'), findsOneWidget);
    expect(find.textContaining('Weak'), findsOneWidget);
    expect(find.text('x2'), findsWidgets);
  });

  testWidgets('GameScreen Boss HUD không crash ở font scale 1.5', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1612);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final g = Get.put(GameController());
    await tester.pump(const Duration(milliseconds: 30));
    g.startBoss(1);

    await tester.pumpWidget(appEnScaled(const GameScreen(), 1.5));
    await tester.pump(const Duration(milliseconds: 160));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Boss'), findsWidgets);
    expect(find.text('Phase 1'), findsOneWidget);
  });
}

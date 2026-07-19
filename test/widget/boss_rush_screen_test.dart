import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/boss_rush_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget home) => GetMaterialApp(
  translations: AppTranslations(),
  locale: const Locale('en', 'US'),
  home: home,
);

// I43 Boss Rush: lobby hiện best streak + banner no-booster + nút bắt đầu.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    Get.put(GameController(), permanent: true);
  });

  tearDown(Get.reset);

  testWidgets('lobby hiện best streak, banner no-booster, nút bắt đầu', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const BossRushScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    // StrokeText vẽ 2 lớp (stroke + fill) cho cùng 1 chuỗi → findsWidgets.
    expect(find.text('Boss Rush'), findsWidgets);
    expect(find.textContaining('Best streak'), findsWidgets);
    expect(find.text('Boosters are disabled in Boss Rush'), findsOneWidget);
    expect(find.text('Start run'), findsWidgets);
  });

  testWidgets('nhấn nút bắt đầu chuyển sang màn chơi (Stage 1)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const BossRushScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Start run').first);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Stage 1'), findsWidgets);
  });
}

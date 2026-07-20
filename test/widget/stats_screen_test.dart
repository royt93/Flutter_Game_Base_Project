import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/stats_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('I35 Stats screen: hiển thị đúng 5 số liệu trọn đời', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    final gameCtrl = Get.put(GameController(), permanent: true);
    gameCtrl.totalGemsPopped.value = 1234;
    gameCtrl.maxComboEver.value = 8;
    gameCtrl.levelsThreeStarred.value = 42;
    gameCtrl.boardsFullyCleared.value = 17;
    gameCtrl.totalBoostersUsed.value = 5;

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        home: const StatsScreen(),
      ),
    );
    // NeonBg có AnimationController.repeat() vô hạn — pumpAndSettle sẽ treo.
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    // Title đi qua NeonAppBar -> StrokeText, vẽ 2 lớp (stroke + fill).
    expect(find.text('Lifetime Stats'), findsNWidgets(2));
    expect(find.text('1234'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    Get.reset();
  });

  testWidgets('I35 Stats screen: giá trị 0 mặc định vẫn render đúng', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    Get.put(GameController(), permanent: true);

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        home: const StatsScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('0'), findsNWidgets(5));

    Get.reset();
  });
}

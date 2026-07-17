import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/achievements.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/achievements_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('hiển thị đủ 25 thành tựu, khoá hết khi chưa đạt mốc nào', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    Get.put(GameController(), permanent: true);

    // ListView chỉ build item trong viewport — cần viewport đủ cao để cả 25
    // thành tựu được build cùng lúc (khớp quy ước home_screen_test.dart).
    tester.view.physicalSize = const Size(1080, 20000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(GetMaterialApp(home: const AchievementsScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byIcon(Icons.lock_rounded),
      findsNWidgets(kAchievements.length),
    );
    expect(find.byIcon(Icons.emoji_events_rounded), findsNothing);
    // Mốc thấp nhất (combo_3, threshold 3) hiện đúng "0/3".
    expect(find.text('0/3'), findsOneWidget);

    Get.reset();
  });

  testWidgets('mở khoá 1 mốc → icon cúp + text "achievements_done"', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    final gameCtrl = Get.put(GameController(), permanent: true);
    gameCtrl.startLevel(1);
    gameCtrl.registerPop(10); // comboCount=1
    gameCtrl.registerPop(10); // comboCount=2
    gameCtrl.registerPop(10); // comboCount=3 → mở khoá combo_3

    tester.view.physicalSize = const Size(1080, 20000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(GetMaterialApp(home: const AchievementsScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
    expect(
      find.byIcon(Icons.lock_rounded),
      findsNWidgets(kAchievements.length - 1),
    );
    expect(find.text('achievements_done'), findsOneWidget);

    Get.reset();
  });
}

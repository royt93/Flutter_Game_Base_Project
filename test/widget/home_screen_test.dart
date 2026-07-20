import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_info.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/worlds.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/home_screen.dart';
import 'package:pop_star_blast/presentation/widgets/neon_bg.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('render không lỗi, hiện tên app + nút PLAY', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    Get.put(GameController(), permanent: true);

    // Viewport mặc định 800x600 (ngang) hẹp hơn mọi điện thoại thật (luôn cao
    // hơn rộng) — HomeScreen nhồi nhiều hàng nút nên tràn RenderFlex giả tạo ở
    // canvas test, dù không bao giờ xảy ra trên thiết bị. Dùng tỉ lệ dọc thật.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(GetMaterialApp(home: const HomeScreen()));
    // StarMascot có AnimationController.repeat() vô hạn — pump theo bước cố
    // định thay vì pumpAndSettle (sẽ treo test).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    // StrokeText vẽ 2 lớp (stroke + fill) chồng nhau cho cùng 1 chuỗi.
    expect(find.text(kAppName), findsNWidgets(2));
    Get.reset();
  });

  testWidgets('I53: nền home đổi accent/weather đúng theo world đã unlock', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    final gameCtrl = Get.put(GameController(), permanent: true);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(GetMaterialApp(home: const HomeScreen()));

    // Mốc world 1 (level 1) — giá trị mặc định của unlockedLevel.
    gameCtrl.unlockedLevel.value = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
    var bg = tester.widget<NeonBg>(find.byType(NeonBg));
    expect(bg.accent, worldForLevel(1).color);
    expect(bg.weather, worldForLevel(1).weather);

    // Mốc world giữa (level 90 -> world 5).
    gameCtrl.unlockedLevel.value = 90;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
    bg = tester.widget<NeonBg>(find.byType(NeonBg));
    expect(bg.accent, worldForLevel(90).color);
    expect(bg.weather, worldForLevel(90).weather);

    // Mốc world cuối (level 220 -> kWorlds.last).
    gameCtrl.unlockedLevel.value = 220;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
    bg = tester.widget<NeonBg>(find.byType(NeonBg));
    expect(bg.accent, kWorlds.last.color);
    expect(bg.weather, kWorlds.last.weather);

    Get.reset();
  });
}

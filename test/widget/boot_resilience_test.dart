import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_info.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/home_screen.dart';

void main() {
  testWidgets(
    'X4: boot storage lỗi (StorageService(null) fallback in-memory) → app vẫn build, không crash',
    (tester) async {
      // Giả lập nhánh catch của `_loadPrefs()` trong main.dart: khi
      // SharedPreferences.getInstance() throw, app truyền null cho
      // StorageService thay vì crash — mọi getter/setter fallback về map
      // in-memory (xem storage_service.dart).
      Get.put(StorageService(null), permanent: true);
      Get.put(GameController(), permanent: true);

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(GetMaterialApp(home: const HomeScreen()));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
      expect(find.text(kAppName), findsNWidgets(2));
      Get.reset();
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_info.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('render không lỗi, hiện tên app + nút PLAY', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    Get.put(GameController(), permanent: true);

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
}

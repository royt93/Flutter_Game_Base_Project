import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('I18: bật colorblind mode render board không crash, tắt vẫn ổn', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    final gameCtrl = Get.put(GameController(), permanent: true)..startLevel(1);
    gameCtrl.toggleColorblindMode();
    expect(gameCtrl.colorblindMode.value, isTrue);

    await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(tester.takeException(), isNull);

    // Tắt lại → vẫn render bình thường, không lỗi.
    gameCtrl.toggleColorblindMode();
    expect(gameCtrl.colorblindMode.value, isFalse);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    Get.reset();
  });
}

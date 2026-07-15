import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/shop_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('mua bomb: đủ xu thì trừ xu + cộng số lượng booster', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    final gameCtrl = Get.put(GameController(), permanent: true);
    gameCtrl.coins.value = 1000;

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        home: const ShopScreen(),
      ),
    );
    // NeonBg có AnimationController.repeat() vô hạn — pumpAndSettle sẽ treo.
    await tester.pump(const Duration(milliseconds: 100));

    final countBefore = gameCtrl.bombCount.value;
    expect(find.text('Bomb  ×$countBefore'), findsOneWidget);
    await tester.tap(find.text(GameController.bombPrice.toString()));
    // A9: label số lượng giờ đếm dần 250ms — pump rỗng để rebuild+forward()
    // chạy trước, rồi pump đủ 250ms để animation hoàn tất.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(gameCtrl.bombCount.value, countBefore + 1);
    expect(gameCtrl.coins.value, 1000 - GameController.bombPrice);
    expect(find.text('Bomb  ×${countBefore + 1}'), findsOneWidget);
    Get.reset();
  });
}

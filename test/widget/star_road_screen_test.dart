import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/star_road_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('claim rương khi đủ sao: cộng xu + đánh dấu đã nhận', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    final gameCtrl = Get.put(GameController(), permanent: true);
    gameCtrl.totalStars.value = GameController.starRoadMilestones[0];

    await tester.pumpWidget(GetMaterialApp(home: const StarRoadScreen()));
    // NeonBg có AnimationController.repeat() vô hạn — pumpAndSettle sẽ treo.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('DAILY_CLAIM'), findsWidgets);
    final coinsBefore = gameCtrl.coins.value;

    await tester.tap(find.text('DAILY_CLAIM').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2)); // chờ CoinFlyOverlay xong

    expect(tester.takeException(), isNull);
    expect(
      gameCtrl.coins.value,
      coinsBefore +
          GameController.starRoadRewards[0] * gameCtrl.weekendCoinMultiplier,
    );
    expect(gameCtrl.isChestClaimed(0), isTrue);
    Get.reset();
  });
}

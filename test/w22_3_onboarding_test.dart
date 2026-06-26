import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/home_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 22.3 — Onboarding tour Home: mở 1 lần, leo bước, đóng → set seen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController g;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs));
    g = Get.put(GameController());
  });
  tearDown(Get.reset);

  test('onReady mở tour khi chưa xem', () {
    final hc = Get.put(HomeController(g));
    hc.onReady();
    expect(hc.introOpen.value, isTrue);
    expect(hc.introStep.value, 0);
  });

  test('onReady KHÔNG mở nếu đã xem', () {
    StorageService.to.setInt(StorageKeys.homeTourSeen, 1);
    final hc = Get.put(HomeController(g));
    hc.onReady();
    expect(hc.introOpen.value, isFalse);
  });

  test('introNext leo hết bước rồi đóng + set homeTourSeen=1', () {
    final hc = Get.put(HomeController(g));
    hc.introOpen.value = true;
    for (var i = 0; i < HomeController.introSteps - 1; i++) {
      hc.introNext();
      expect(hc.introStep.value, i + 1);
      expect(hc.introOpen.value, isTrue); // chưa đóng giữa chừng
    }
    hc.introNext(); // bước cuối → đóng
    expect(hc.introOpen.value, isFalse);
    expect(StorageService.to.getInt(StorageKeys.homeTourSeen), 1);
  });

  test('closeIntro (Skip) đóng ngay + set seen', () {
    final hc = Get.put(HomeController(g));
    hc.introOpen.value = true;
    hc.introStep.value = 1;
    hc.closeIntro();
    expect(hc.introOpen.value, isFalse);
    expect(StorageService.to.getInt(StorageKeys.homeTourSeen), 1);
  });

  test('resetProgress xoá homeTourSeen → tour hiện lại', () async {
    StorageService.to.setInt(StorageKeys.homeTourSeen, 1);
    await g.resetProgress();
    expect(StorageService.to.getInt(StorageKeys.homeTourSeen, def: 0), 0);
  });
}

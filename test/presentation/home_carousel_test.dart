import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/perks.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/widgets/home_carousel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController ctrl;

  // Đưa controller về baseline "không có gì đáng chú ý": qua hết world có
  // perk (unlockedLevel sau world 3, endId=60) + active hết perk đã mở khoá
  // (perk luôn đáng chú ý ở trạng thái mới toanh vì world kế tiếp luôn cách
  // đúng 1 world — xem `_perkCard` trong home_carousel.dart).
  void neutralize() {
    ctrl.unlockedLevel.value = 61;
    ctrl.activePerkIds.assignAll(kPerks.map((p) => p.id));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    ctrl = Get.put(GameController(), permanent: true);
    neutralize();
  });

  tearDown(Get.reset);

  group('buildHomeCards — thứ tự & điều kiện đáng chú ý', () {
    test('không có gì đáng chú ý -> chỉ có greeting card', () {
      final cards = buildHomeCards(ctrl);
      expect(cards.map((c) => c.type), [HomeCardType.greeting]);
    });

    test('starRoad đáng chú ý khi có rương khả nhận (canClaimChest)', () {
      ctrl.totalStars.value = GameController.starRoadMilestones[0];
      final cards = buildHomeCards(ctrl);
      expect(cards.map((c) => c.type), [
        HomeCardType.greeting,
        HomeCardType.starRoad,
      ]);
    });

    test('starRoad đáng chú ý khi còn ≤3 sao tới mốc kế tiếp', () {
      ctrl.totalStars.value = GameController.starRoadMilestones[0] - 3;
      final cards = buildHomeCards(ctrl);
      expect(cards.map((c) => c.type), [
        HomeCardType.greeting,
        HomeCardType.starRoad,
      ]);
    });

    test('starRoad không đáng chú ý khi còn xa mốc và chưa có gì để nhận', () {
      ctrl.totalStars.value = 0;
      final cards = buildHomeCards(ctrl);
      expect(cards.map((c) => c.type), [HomeCardType.greeting]);
    });

    test('seasonPass đáng chú ý khi có mốc khả nhận (canClaimSeason)', () {
      ctrl.seasonPoints.value = GameController.seasonMilestones[0];
      final cards = buildHomeCards(ctrl);
      expect(cards.map((c) => c.type), [
        HomeCardType.greeting,
        HomeCardType.seasonPass,
      ]);
    });

    test('seasonPass đáng chú ý khi còn ≤20 điểm tới mốc kế tiếp', () {
      ctrl.seasonPoints.value = GameController.seasonMilestones[0] - 20;
      final cards = buildHomeCards(ctrl);
      expect(cards.map((c) => c.type), [
        HomeCardType.greeting,
        HomeCardType.seasonPass,
      ]);
    });

    test('achievement đáng chú ý khi vừa unlock (justUnlockedAchievement)', () {
      ctrl.registerPop(10, groupSize: 500); // mở khoá gems_500
      final cards = buildHomeCards(ctrl);
      expect(cards.map((c) => c.type), [
        HomeCardType.greeting,
        HomeCardType.achievement,
      ]);
    });

    test('achievement đáng chú ý khi đạt ≥80% ngưỡng chưa unlock', () {
      ctrl.totalGemsPopped.value = (500 * 0.8).ceil();
      final cards = buildHomeCards(ctrl);
      expect(cards.map((c) => c.type), [
        HomeCardType.greeting,
        HomeCardType.achievement,
      ]);
    });

    test('perk đáng chú ý khi có perk đã mở khoá nhưng chưa active', () {
      ctrl.activePerkIds.clear(); // đã unlock cả 3 perk nhưng chưa kích hoạt
      final cards = buildHomeCards(ctrl);
      expect(cards.map((c) => c.type), [
        HomeCardType.greeting,
        HomeCardType.perk,
      ]);
    });

    test('perk đáng chú ý khi world kế tiếp cách đúng 1 world', () {
      ctrl.unlockedLevel.value = 1; // done=0, perk đầu unlockAfterWorld=1
      ctrl.activePerkIds.clear();
      final cards = buildHomeCards(ctrl);
      expect(cards.map((c) => c.type), [
        HomeCardType.greeting,
        HomeCardType.perk,
      ]);
    });

    test('nhiều nhóm đáng chú ý cùng lúc -> giữ đúng thứ tự cố định', () {
      ctrl.totalStars.value = GameController.starRoadMilestones[0];
      ctrl.seasonPoints.value = GameController.seasonMilestones[0];
      ctrl.registerPop(10, groupSize: 500);
      ctrl.activePerkIds.clear();
      final cards = buildHomeCards(ctrl);
      expect(cards.map((c) => c.type), [
        HomeCardType.greeting,
        HomeCardType.starRoad,
        HomeCardType.seasonPass,
        HomeCardType.achievement,
        HomeCardType.perk,
      ]);
    });
  });
}

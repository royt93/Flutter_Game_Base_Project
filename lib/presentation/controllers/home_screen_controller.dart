import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/reminder_service.dart';
import '../../core/storage_service.dart';
import '../widgets/home_carousel.dart';
import 'game_controller.dart';

/// X14: điều khiển carousel tiến độ thật trên Home — tách khỏi widget để
/// unit-test hàm thuần [buildHomeCards] độc lập, nhất quán pattern
/// `GameScreenController`. Refresh lại danh sách card mỗi khi app resume
/// (vd quay lại từ Settings/StarRoad sau khi state đổi).
class HomeScreenController extends GetxController with WidgetsBindingObserver {
  final RxList<HomeCardData> cards = <HomeCardData>[].obs;
  final RxInt currentIndex = 0.obs;

  /// Round-7 Tutorial: coach-mark trỏ vào nút Shop/Daily Challenge ở hàng
  /// truy cập nhanh trên Home — mỗi cái chỉ hiện 1 lần, tuần tự (Daily
  /// Challenge chỉ hiện sau khi Shop đã được xem, tránh chồng 2 tooltip).
  final RxBool showShopTutorial = false.obs;
  final RxBool showDailyChallengeTutorial = false.obs;

  void refreshCards(GameController gameCtrl) {
    cards.assignAll(buildHomeCards(gameCtrl));
    if (currentIndex.value >= cards.length) currentIndex.value = 0;
  }

  void _refreshTutorials() {
    final seenShop = StorageService.to.getBool(StorageKeys.hasSeenShopTutorial);
    showShopTutorial.value = !seenShop;
    showDailyChallengeTutorial.value =
        seenShop &&
        !StorageService.to.getBool(StorageKeys.hasSeenDailyChallengeTutorial);
  }

  void dismissShopTutorial() {
    if (!showShopTutorial.value) return;
    showShopTutorial.value = false;
    StorageService.to.setBool(StorageKeys.hasSeenShopTutorial, true);
    // Daily Challenge chỉ hiện sau khi Shop đã dismiss — đánh giá lại ngay
    // trong session này thay vì đợi tới lần mở app kế tiếp mới thấy.
    if (!StorageService.to.getBool(StorageKeys.hasSeenDailyChallengeTutorial)) {
      showDailyChallengeTutorial.value = true;
    }
  }

  void dismissDailyChallengeTutorial() {
    if (!showDailyChallengeTutorial.value) return;
    showDailyChallengeTutorial.value = false;
    StorageService.to.setBool(StorageKeys.hasSeenDailyChallengeTutorial, true);
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _refreshTutorials();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final gameCtrl = Get.find<GameController>();
      refreshCards(gameCtrl);
      // I56: quay lại app cũng tính là "mở app" — reschedule reminder theo
      // state mới nhất (đã claim spin/streak/weekly-goal chưa).
      ReminderService.maybe?.scheduleNext();
      // I73: khung theo mùa có thể vừa hết hạn trong lúc app ở background —
      // sửa lại activeBoardFrameId nếu cần để storage khớp với hiển thị.
      gameCtrl.revalidateActiveBoardFrame();
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}

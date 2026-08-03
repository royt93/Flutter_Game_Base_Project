import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/reminder_service.dart';
import '../widgets/home_carousel.dart';
import 'game_controller.dart';

/// X14: điều khiển carousel tiến độ thật trên Home — tách khỏi widget để
/// unit-test hàm thuần [buildHomeCards] độc lập, nhất quán pattern
/// `GameScreenController`. Refresh lại danh sách card mỗi khi app resume
/// (vd quay lại từ Settings/StarRoad sau khi state đổi).
class HomeScreenController extends GetxController with WidgetsBindingObserver {
  final RxList<HomeCardData> cards = <HomeCardData>[].obs;
  final RxInt currentIndex = 0.obs;

  void refreshCards(GameController gameCtrl) {
    cards.assignAll(buildHomeCards(gameCtrl));
    if (currentIndex.value >= cards.length) currentIndex.value = 0;
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshCards(Get.find<GameController>());
      // I56: quay lại app cũng tính là "mở app" — reschedule reminder theo
      // state mới nhất (đã claim spin/streak/weekly-goal chưa).
      ReminderService.maybe?.scheduleNext();
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}

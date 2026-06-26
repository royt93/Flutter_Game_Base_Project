import 'package:get/get.dart';
import '../../core/storage_service.dart';
import 'game_controller.dart';

/// Trạng thái UI màn Home: overlay daily reward (route dialog no-op ở
/// full-screen nên dùng overlay trong cây).
class HomeController extends GetxController {
  final GameController game;
  HomeController(this.game);

  final RxBool dailyOpen = false.obs;

  // W22.3 — tour giới thiệu Home lần đầu (carousel trong cây).
  final RxBool introOpen = false.obs;
  final RxInt introStep = 0.obs;
  static const int introSteps = 4;

  @override
  void onReady() {
    super.onReady();
    // onReady chạy SAU frame đầu → an toàn mutate Rx (tránh markNeedsBuild during build).
    if (StorageService.to.getInt(StorageKeys.homeTourSeen, def: 0) == 0) {
      introOpen.value = true;
    }
  }

  void introNext() {
    if (introStep.value < introSteps - 1) {
      introStep.value++;
    } else {
      closeIntro();
    }
  }

  void closeIntro() {
    introOpen.value = false;
    StorageService.to.setInt(StorageKeys.homeTourSeen, 1);
  }

  final RxInt lastReward =
      0.obs; // xu vừa nhận trong phiên mở overlay (0 = chưa)

  final RxBool livesBuyOpen = false.obs;
  final RxBool buyFailed = false.obs; // thiếu xu khi mua mạng

  /// Giá nạp đầy mạng (xu).
  static const int refillPrice = 60;

  void openDaily() {
    lastReward.value = 0;
    dailyOpen.value = true;
  }

  void closeDaily() => dailyOpen.value = false;

  void claim() => lastReward.value = game.claimDaily();

  void openLivesBuy() {
    buyFailed.value = false;
    livesBuyOpen.value = true;
  }

  void closeLivesBuy() => livesBuyOpen.value = false;

  void buyLives() {
    if (game.buyRefillLives(price: refillPrice)) {
      livesBuyOpen.value = false;
    } else {
      buyFailed.value = true;
    }
  }
}

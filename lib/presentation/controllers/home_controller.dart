import 'package:get/get.dart';
import 'game_controller.dart';

/// Trạng thái UI màn Home: overlay daily reward (route dialog no-op ở
/// full-screen nên dùng overlay trong cây).
class HomeController extends GetxController {
  final GameController game;
  HomeController(this.game);

  final RxBool dailyOpen = false.obs;
  final RxInt lastReward = 0.obs; // xu vừa nhận trong phiên mở overlay (0 = chưa)

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

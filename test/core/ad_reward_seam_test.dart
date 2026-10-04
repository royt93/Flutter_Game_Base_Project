import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/ad_reward_seam.dart';

class _FakeAdRewardSeam implements AdRewardSeam {
  bool rewarded = true;
  int showCalls = 0;
  String? lastPlacement;

  @override
  bool get isReady => true;

  @override
  Future<bool> showRewardedAd({String? placement}) async {
    showCalls++;
    lastPlacement = placement;
    return rewarded;
  }
}

void main() {
  tearDown(Get.reset);

  group('AdRewardSeam.maybe (IDEA-71)', () {
    test('trả về null khi chưa có adapter nào đăng ký', () {
      expect(AdRewardSeam.maybe, isNull);
    });

    test('trả về đúng instance đã đăng ký, vendor-neutral', () async {
      final seam = _FakeAdRewardSeam();
      Get.put<AdRewardSeam>(seam, permanent: true);

      expect(AdRewardSeam.maybe, same(seam));
      expect(AdRewardSeam.maybe!.isReady, isTrue);

      final result = await AdRewardSeam.maybe!.showRewardedAd(
        placement: 'double_coins',
      );
      expect(result, isTrue);
      expect(seam.showCalls, 1);
      expect(seam.lastPlacement, 'double_coins');
    });

    test('showRewardedAd trả false khi người chơi bỏ xem giữa chừng', () async {
      final seam = _FakeAdRewardSeam()..rewarded = false;
      Get.put<AdRewardSeam>(seam, permanent: true);

      expect(await AdRewardSeam.maybe!.showRewardedAd(), isFalse);
    });
  });
}

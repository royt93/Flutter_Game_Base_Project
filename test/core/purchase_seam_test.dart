import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/purchase_seam.dart';

class _FakePurchaseSeam implements PurchaseSeam {
  final Set<String> owned = {};
  int restoreCalls = 0;

  @override
  Future<bool> buy(String productId) async {
    owned.add(productId);
    return true;
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalls++;
  }

  @override
  bool isOwned(String productId) => owned.contains(productId);
}

void main() {
  tearDown(Get.reset);

  test('maybe trả về null khi chưa đăng ký implementation nào', () {
    expect(PurchaseSeam.maybe, isNull);
  });

  test('maybe trả về đúng instance khi đã đăng ký', () {
    final seam = _FakePurchaseSeam();
    Get.put<PurchaseSeam>(seam, permanent: true);

    expect(PurchaseSeam.maybe, same(seam));
  });

  test('buy() cập nhật isOwned đúng theo productId đã mua', () async {
    final seam = _FakePurchaseSeam();
    Get.put<PurchaseSeam>(seam, permanent: true);

    expect(PurchaseSeam.maybe!.isOwned('remove_ads'), isFalse);

    final ok = await PurchaseSeam.maybe!.buy('remove_ads');

    expect(ok, isTrue);
    expect(PurchaseSeam.maybe!.isOwned('remove_ads'), isTrue);
    expect(PurchaseSeam.maybe!.isOwned('mega_gem_pack'), isFalse);
  });

  test('restorePurchases() gọi được qua interface', () async {
    final seam = _FakePurchaseSeam();
    Get.put<PurchaseSeam>(seam, permanent: true);

    await PurchaseSeam.maybe!.restorePurchases();

    expect(seam.restoreCalls, 1);
  });
}

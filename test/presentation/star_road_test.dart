import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController ctrl;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    ctrl = Get.put(GameController(), permanent: true);
  });

  tearDown(Get.reset);

  test('chưa đủ sao → không claim được mốc đầu', () {
    expect(ctrl.totalStars.value, 0);
    expect(ctrl.canClaimChest(0), isFalse);
    expect(ctrl.claimChest(0), isFalse);
    expect(ctrl.coins.value, 0);
  });

  test('đủ sao → claim mốc đầu cộng đúng xu, mốc sau vẫn khoá', () async {
    await StorageService.to.setInt(StorageKeys.star(1), 3);
    await StorageService.to.setInt(StorageKeys.star(2), 2);
    // ignore: invalid_use_of_protected_member
    ctrl.onInit(); // reload từ storage sau khi set thủ công

    expect(ctrl.totalStars.value, 5);
    expect(ctrl.canClaimChest(0), isTrue);
    expect(ctrl.claimChest(0), isTrue);
    expect(
      ctrl.coins.value,
      GameController.starRoadRewards[0] * ctrl.weekendCoinMultiplier,
    );
    expect(ctrl.isChestClaimed(0), isTrue);
    expect(ctrl.canClaimChest(1), isFalse); // mốc 15 sao chưa tới
  });

  test('claim rồi không cho re-claim lại (kể cả sau reload)', () async {
    await StorageService.to.setInt(StorageKeys.star(1), 3);
    await StorageService.to.setInt(StorageKeys.star(2), 2);
    // ignore: invalid_use_of_protected_member
    ctrl.onInit();
    expect(ctrl.claimChest(0), isTrue);
    final coinsAfterFirstClaim = ctrl.coins.value;

    expect(ctrl.claimChest(0), isFalse);
    expect(ctrl.coins.value, coinsAfterFirstClaim);

    // ignore: invalid_use_of_protected_member
    ctrl.onInit(); // giả lập reload app
    expect(ctrl.isChestClaimed(0), isTrue);
    expect(ctrl.claimChest(0), isFalse);
  });

  test('resetProgress xoá hết chest đã claim + về 0 sao', () async {
    await StorageService.to.setInt(StorageKeys.star(1), 3);
    await StorageService.to.setInt(StorageKeys.star(2), 2);
    // ignore: invalid_use_of_protected_member
    ctrl.onInit();
    ctrl.claimChest(0);

    await ctrl.resetProgress();
    expect(ctrl.totalStars.value, 0);
    expect(ctrl.isChestClaimed(0), isFalse);
  });
}

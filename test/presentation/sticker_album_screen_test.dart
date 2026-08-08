import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/board_frames.dart';
import 'package:pop_star_blast/data/burst_styles.dart';
import 'package:pop_star_blast/data/combo_text_styles.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// I77: test tầng controller cho Sticker Album — codebase chưa có tiền lệ
/// widget-pump test cho màn cosmetic (xem `star_road_test.dart`), nên áp
/// dụng đúng khuôn mẫu đó: gọi thẳng API public trên [GameController] thay
/// vì dựng cây widget.
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

  test('mặc định sở hữu đúng 4 cosmetic (1 mỗi hệ, mốc đầu chưa đạt)', () {
    // 1 mascot skin mặc định (kMascotSkins.first) + 1 board frame luôn mở
    // (classic) + 1 burst style ngưỡng 0 (spark) + 1 combo text ngưỡng 0
    // (neon) — khớp isBoardFrameUnlocked/isBurstStyleUnlocked/
    // isComboTextStyleUnlocked đọc trực tiếp từ data file.
    expect(ctrl.totalCosmeticsOwned, 4);
    expect(ctrl.claimedStickerMilestoneMask.value, 0);
    expect(
      isBoardFrameUnlocked(
        kBoardFrames.first,
        ctrl.prestigeTier.value,
        ctrl.unlockedAchievementIds,
        treasureMapCompleted: ctrl.treasureMapCompleted.value,
      ),
      isTrue,
    );
    expect(
      isBurstStyleUnlocked(kBurstStyles.first, ctrl.totalGemsPopped.value),
      isTrue,
    );
    expect(
      isComboTextStyleUnlocked(kComboTextStyles.first, ctrl.maxComboEver.value),
      isTrue,
    );
  });

  test('vượt mốc 5 cosmetic → cộng đúng xu 1 lần, không double-grant', () {
    ctrl.unlockedMascotSkinIds.add('ruby'); // 4 -> 5, chạm mốc đầu tiên.
    expect(ctrl.totalCosmeticsOwned, 5);

    ctrl.registerPop(0); // trigger _checkStickerMilestones() qua API public.

    expect(ctrl.claimedStickerMilestoneMask.value & 1, 1);
    expect(
      ctrl.coins.value,
      GameController.stickerAlbumRewards[0] * ctrl.weekendCoinMultiplier,
    );

    final coinsAfterFirstClaim = ctrl.coins.value;
    ctrl.registerPop(0); // vẫn ở mức 5 cosmetic, không cộng thêm lần nữa.
    expect(ctrl.coins.value, coinsAfterFirstClaim);
  });

  test('mốc sau vẫn khoá khi chưa đủ cosmetic', () {
    ctrl.unlockedMascotSkinIds.add('ruby'); // 5 cosmetic, chỉ đạt mốc 1.
    ctrl.registerPop(0);

    expect(ctrl.claimedStickerMilestoneMask.value & 1, 1);
    expect(ctrl.claimedStickerMilestoneMask.value & 2, 0); // mốc 10 chưa tới.
  });

  test('claimedStickerMilestoneMask được lưu và nạp lại sau reload', () async {
    ctrl.unlockedMascotSkinIds.add('ruby');
    ctrl.registerPop(0);
    final maskAfterClaim = ctrl.claimedStickerMilestoneMask.value;
    expect(maskAfterClaim, isNot(0));

    // ignore: invalid_use_of_protected_member
    ctrl.onInit(); // giả lập reload app.
    expect(ctrl.claimedStickerMilestoneMask.value, maskAfterClaim);
  });
}

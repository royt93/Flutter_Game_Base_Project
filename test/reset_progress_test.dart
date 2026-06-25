import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

// TC-12-09 (automation phần host): resetProgress phải xoá CẢ đĩa LẪN in-memory về fresh.
// Bug từng gặp (xem CLAUDE.md): chỉ xoá đĩa mà quên reset in-memory → re-claim thưởng
// sau restart; hoặc quên xoá coins/booster → "reset" nhưng xu vẫn còn.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  testWidgets('resetProgress: đĩa + in-memory về fresh, không giữ tiến trình cũ', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    final store = StorageService(await SharedPreferences.getInstance());
    Get.put(store);

    // Gieo tiến trình cũ trước khi controller load.
    await store.setInt(StorageKeys.unlockedLevel, 50);
    await store.setInt(StorageKeys.coins, 9999);

    final g = Get.put(GameController());
    await tester.pump(const Duration(milliseconds: 50));

    // Precondition: controller đã load đúng data cũ.
    expect(
      g.unlockedLevel.value,
      50,
      reason: 'phải load unlock cũ trước reset',
    );
    expect(g.coins.value, 9999, reason: 'phải load coins cũ trước reset');

    await g.resetProgress();
    await tester.pump(const Duration(milliseconds: 50));

    // In-memory về fresh = tài khoản mới: unlock 1, coins về xu khởi đầu mặc định
    // (KHÔNG giữ 9999 cũ). Starter = kDebugMode?10000:100 (khớp def lúc load).
    final starterCoins = kDebugMode ? 10000 : 100;
    expect(
      g.unlockedLevel.value,
      1,
      reason: 'in-memory unlock phải reset về 1',
    );
    expect(
      g.coins.value,
      starterCoins,
      reason: 'coins phải về xu khởi đầu, không giữ 9999 cũ',
    );

    // Đĩa đã xoá (getInt trả default → chống re-claim/giữ tiến trình sau restart).
    expect(store.getInt(StorageKeys.unlockedLevel, def: 1), 1);
    expect(store.getInt(StorageKeys.coins, def: 0), 0);
    expect(store.getInt(StorageKeys.coinsEarned, def: 0), 0);
  });
}

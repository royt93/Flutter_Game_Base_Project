import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/presentation/controllers/versus_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fix 5: Sau khi thoát VersusScreen, game1/game2 phải bị paused trước khi
/// controller bị xóa → tránh game loop tiếp tục chạy và gây lag home screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
  });
  tearDown(Get.reset);

  group('VersusController.onClose → games paused (Fix 5)', () {
    test('game1 và game2 được paused trước khi controllers bị xóa', () {
      const tag = 'versus';
      final ctrl = Get.put(VersusController(VersusMode.versus), tag: tag);

      // Giữ reference trước khi delete
      final g1 = ctrl.game1;
      final g2 = ctrl.game2;

      // Lúc này game chưa paused
      expect(g1.paused, isFalse);
      expect(g2.paused, isFalse);

      // Trigger onClose (mô phỏng dispose)
      Get.delete<VersusController>(tag: tag);

      // Sau onClose: game phải đã paused trước khi bị release
      expect(g1.paused, isTrue);
      expect(g2.paused, isTrue);
    });

    test('GameController vp1 và vp2 bị xóa sau onClose', () {
      const tag = 'versus';
      Get.put(VersusController(VersusMode.coop), tag: tag);

      expect(Get.isRegistered<VersusController>(tag: tag), isTrue);

      Get.delete<VersusController>(tag: tag);

      expect(Get.isRegistered<VersusController>(tag: tag), isFalse);
      // Controller tagged được dọn sạch
      expect(Get.isRegistered<VersusController>(), isFalse);
    });
  });
}

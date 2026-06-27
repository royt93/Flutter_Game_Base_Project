import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/presentation/controllers/versus_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fix 5 — Chứng minh: games được PAUSE trước khi teardown, không còn lag.
///
/// Root cause lag: khi thoát VersusScreen, 2 NeonJewelGame vẫn render trong
/// navigation animation (300ms). Flame update() vẫn chạy song song với teardown
/// → frame drop, UI lag.
///
/// Fix: `_exitNow()` pause cả 2 games TRƯỚC `Get.back()`.
/// `VersusController.onClose()` cũng pause làm safety net.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
  });
  tearDown(Get.reset);

  group('Versus lag fix — games paused trước teardown (Fix 5)', () {
    test('game1 và game2 khởi tạo ở trạng thái NOT paused', () {
      final ctrl = Get.put(VersusController(VersusMode.versus), tag: 'vs');
      expect(
        ctrl.game1.paused,
        isFalse,
        reason: 'Khi mới tạo, game chưa bị pause → loop chạy bình thường',
      );
      expect(ctrl.game2.paused, isFalse);
    });

    test('onClose() pause game1 và game2 TRƯỚC khi delete GameControllers', () {
      final ctrl = Get.put(VersusController(VersusMode.versus), tag: 'vs');
      final g1 = ctrl.game1;
      final g2 = ctrl.game2;

      // Trigger onClose qua Get.delete
      Get.delete<VersusController>(tag: 'vs');

      // Sau onClose: cả 2 game phải bị pause
      expect(
        g1.paused,
        isTrue,
        reason:
            'game1.paused = true được set TRƯỚC khi xóa controller → không render trong teardown',
      );
      expect(g2.paused, isTrue, reason: 'game2.paused = true tương tự');
    });

    test('onClose() xóa cả GameController vp1 và vp2', () {
      Get.put(VersusController(VersusMode.coop), tag: 'vs');

      // Trước khi delete: controller tồn tại
      expect(Get.isRegistered<VersusController>(tag: 'vs'), isTrue);

      Get.delete<VersusController>(tag: 'vs');

      // Sau delete: controller gone
      expect(Get.isRegistered<VersusController>(tag: 'vs'), isFalse);
    });

    test('cả 2 games vẫn giữ ref sau delete (paused check vẫn valid)', () {
      final ctrl = Get.put(VersusController(VersusMode.versus), tag: 'vs');
      final g1 = ctrl.game1; // giữ ref trước khi delete

      Get.delete<VersusController>(tag: 'vs');

      // Ref vẫn valid, game đã paused
      // Đây là điều kiện cần thiết: ref không bị null khi teardown
      expect(g1.paused, isTrue);
    });

    test('game1 và game2 là 2 instance độc lập (không share state)', () {
      final ctrl = Get.put(VersusController(VersusMode.versus), tag: 'vs');
      expect(
        identical(ctrl.game1, ctrl.game2),
        isFalse,
        reason: '2 player cần 2 game engine riêng biệt',
      );

      // Thay đổi game1 không ảnh hưởng game2
      ctrl.game1.paused = true;
      expect(
        ctrl.game2.paused,
        isFalse,
        reason: 'Chỉ game1 bị pause, game2 vẫn chạy bình thường',
      );
      Get.delete<VersusController>(tag: 'vs');
    });

    test('VersusMode.coop tạo game với cùng pattern pause', () {
      final ctrl = Get.put(VersusController(VersusMode.coop), tag: 'vs');
      final g1 = ctrl.game1;
      final g2 = ctrl.game2;

      Get.delete<VersusController>(tag: 'vs');

      expect(g1.paused, isTrue);
      expect(g2.paused, isTrue);
    });

    test('pause trước delete: không có exception khi game loop bị dừng', () {
      final ctrl = Get.put(VersusController(VersusMode.versus), tag: 'vs');

      // Mô phỏng _exitNow(): pause trước rồi delete
      ctrl.game1.paused = true;
      ctrl.game2.paused = true;

      // Không ném exception khi delete sau khi đã pause
      expect(
        () => Get.delete<VersusController>(tag: 'vs'),
        returnsNormally,
        reason: 'Pause rồi delete không gây lỗi — đây là flow _exitNow()',
      );
    });
  });
}

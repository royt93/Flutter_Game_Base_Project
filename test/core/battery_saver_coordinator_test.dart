import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/battery_saver_coordinator.dart';
import 'package:roy_casual_kit/core/performance_tier_service.dart';

void main() {
  tearDown(Get.reset);

  test('pin dưới ngưỡng -> tier bị ép xuống low', () async {
    final performanceTier = PerformanceTierService();
    final coordinator = BatterySaverCoordinator(
      performanceTier: performanceTier,
      batteryLevelProvider: () async => 10,
      lowBatteryThreshold: 20,
    );

    await coordinator.check();

    expect(performanceTier.tier.value, PerformanceTier.low);
    expect(coordinator.isForcingLow, isTrue);
  });

  test(
    'pin trên ngưỡng, chưa từng bị ép -> KHÔNG đụng vào tier, để '
    'PerformanceTierService tự quyết theo FPS',
    () async {
      final performanceTier = PerformanceTierService();
      final coordinator = BatterySaverCoordinator(
        performanceTier: performanceTier,
        batteryLevelProvider: () async => 80,
        lowBatteryThreshold: 20,
      );

      await coordinator.check();

      expect(performanceTier.tier.value, PerformanceTier.high);
      expect(coordinator.isForcingLow, isFalse);
    },
  );

  test(
    'pin phục hồi trên ngưỡng sau khi đã ép low -> khôi phục đúng theo '
    'measuredTier THẬT (không mặc định về high)',
    () async {
      final tracker = FrameBudgetTracker(windowSize: 5);
      final performanceTier = PerformanceTierService(tracker: tracker);
      // FPS thực đo hiện đang low — bất kể battery saver có ép hay không,
      // đây là "sự thật" mà measuredTier phải phản ánh.
      for (var i = 0; i < 5; i++) {
        performanceTier.recordFrame(40); // ~25fps, dưới downgrade threshold
      }
      expect(performanceTier.tier.value, PerformanceTier.low);

      var batteryLevel = 10;
      final coordinator = BatterySaverCoordinator(
        performanceTier: performanceTier,
        batteryLevelProvider: () async => batteryLevel,
        lowBatteryThreshold: 20,
      );

      await coordinator.check(); // pin thấp -> ép low (vốn đã low sẵn)
      expect(coordinator.isForcingLow, isTrue);

      batteryLevel = 80; // pin phục hồi
      await coordinator.check();

      expect(coordinator.isForcingLow, isFalse);
      // Khôi phục về đúng measuredTier (vẫn low vì FPS thực vẫn tệ), KHÔNG
      // phải PerformanceTier.high mặc định.
      expect(performanceTier.tier.value, PerformanceTier.low);
    },
  );

  test(
    'battery reading null -> no-op hoàn toàn, không ép cũng không nhả',
    () async {
      final performanceTier = PerformanceTierService();
      var callCount = 0;
      final coordinator = BatterySaverCoordinator(
        performanceTier: performanceTier,
        batteryLevelProvider: () async {
          callCount++;
          return null;
        },
      );

      await coordinator.check();

      expect(callCount, 1);
      expect(performanceTier.tier.value, PerformanceTier.high);
      expect(coordinator.isForcingLow, isFalse);
    },
  );

  test(
    'null reading trong lúc ĐANG ép low -> KHÔNG tự ý nhả override (lỗi đọc '
    'pin tạm thời không được coi là "pin đã hồi phục")',
    () async {
      final performanceTier = PerformanceTierService();
      int? batteryLevel = 10;
      final coordinator = BatterySaverCoordinator(
        performanceTier: performanceTier,
        batteryLevelProvider: () async => batteryLevel,
      );

      await coordinator.check();
      expect(coordinator.isForcingLow, isTrue);

      batteryLevel = null; // lỗi đọc pin tạm thời
      await coordinator.check();

      expect(coordinator.isForcingLow, isTrue, reason: 'vẫn còn đang ép');
      expect(performanceTier.tier.value, PerformanceTier.low);
    },
  );

  test('ngưỡng tuỳ chỉnh được dùng đúng (không hardcode 20)', () async {
    final performanceTier = PerformanceTierService();
    final coordinator = BatterySaverCoordinator(
      performanceTier: performanceTier,
      batteryLevelProvider: () async => 45,
      lowBatteryThreshold: 50,
    );

    await coordinator.check();

    expect(performanceTier.tier.value, PerformanceTier.low);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/performance_tier_service.dart';

void main() {
  tearDown(Get.reset);

  group('FrameBudgetTracker', () {
    test('mặc định windowSize=60, downgrade=40fps, upgrade=55fps', () {
      final tracker = FrameBudgetTracker();
      expect(tracker.windowSize, 60);
      expect(tracker.downgradeFpsThreshold, 40);
      expect(tracker.upgradeFpsThreshold, 55);
      expect(tracker.tier, PerformanceTier.high);
    });

    test('giữ nguyên high khi 60 khung ~60fps (chưa đủ window để hạ)', () {
      final tracker = FrameBudgetTracker(windowSize: 60);
      var changed = false;
      for (var i = 0; i < 60; i++) {
        changed = tracker.recordFrameMs(16.6) || changed;
      }
      expect(tracker.tier, PerformanceTier.high);
      expect(changed, isFalse);
    });

    test('không hạ cấp trước khi window đầy dù frame rất chậm', () {
      final tracker = FrameBudgetTracker(windowSize: 60);
      // Chỉ feed 59 frame chậm (40ms ~ 25fps) — chưa đủ window.
      for (var i = 0; i < 59; i++) {
        final changed = tracker.recordFrameMs(40);
        expect(changed, isFalse);
      }
      expect(tracker.tier, PerformanceTier.high);
    });

    test('hạ cấp xuống low khi FPS trung bình tụt dưới downgrade threshold', () {
      final tracker = FrameBudgetTracker(windowSize: 60);
      for (var i = 0; i < 60; i++) {
        tracker.recordFrameMs(16.6); // ~60fps, lấp đầy window trước.
      }
      expect(tracker.tier, PerformanceTier.high);

      var sawTransition = false;
      for (var i = 0; i < 60; i++) {
        final changed = tracker.recordFrameMs(40); // ~25fps.
        if (changed) sawTransition = true;
      }
      expect(tracker.tier, PerformanceTier.low);
      expect(sawTransition, isTrue);
    });

    test('nâng cấp lại high khi FPS trung bình vượt upgrade threshold', () {
      final tracker = FrameBudgetTracker(windowSize: 60);
      for (var i = 0; i < 60; i++) {
        tracker.recordFrameMs(16.6);
      }
      for (var i = 0; i < 60; i++) {
        tracker.recordFrameMs(40); // hạ xuống low.
      }
      expect(tracker.tier, PerformanceTier.low);

      var sawTransition = false;
      for (var i = 0; i < 60; i++) {
        final changed = tracker.recordFrameMs(14); // ~71fps.
        if (changed) sawTransition = true;
      }
      expect(tracker.tier, PerformanceTier.high);
      expect(sawTransition, isTrue);
    });

    test('hysteresis: FPS ở giữa 2 ngưỡng không gây flapping', () {
      final tracker = FrameBudgetTracker(windowSize: 60);
      // 45fps ~ 22.22ms — nằm giữa downgrade(40) và upgrade(55).
      for (var i = 0; i < 120; i++) {
        final changed = tracker.recordFrameMs(1000 / 45);
        expect(changed, isFalse);
      }
      expect(tracker.tier, PerformanceTier.high);

      // Hạ xuống low trước bằng khung thật sự chậm...
      final downTracker = FrameBudgetTracker(windowSize: 60);
      for (var i = 0; i < 60; i++) {
        downTracker.recordFrameMs(40);
      }
      expect(downTracker.tier, PerformanceTier.low);
      // ...rồi feed FPS 45 (giữa 2 ngưỡng) — không đủ để nâng cấp lại.
      for (var i = 0; i < 120; i++) {
        final changed = downTracker.recordFrameMs(1000 / 45);
        expect(changed, isFalse);
      }
      expect(downTracker.tier, PerformanceTier.low);
    });

    test('recordFrameMs chỉ trả về true đúng lúc tier thật sự đổi', () {
      final tracker = FrameBudgetTracker(windowSize: 60);
      var transitionCount = 0;
      for (var i = 0; i < 60; i++) {
        if (tracker.recordFrameMs(16.6)) transitionCount++;
      }
      // Đã ở high từ đầu, 60fps không đổi tier -> không transition nào.
      expect(transitionCount, 0);

      for (var i = 0; i < 60; i++) {
        if (tracker.recordFrameMs(40)) transitionCount++;
      }
      // Đúng 1 lần chuyển sang low.
      expect(transitionCount, 1);
      expect(tracker.tier, PerformanceTier.low);
    });

    test('tham số windowSize/threshold tùy chỉnh qua constructor', () {
      final tracker = FrameBudgetTracker(
        windowSize: 5,
        downgradeFpsThreshold: 20,
        upgradeFpsThreshold: 30,
      );
      expect(tracker.windowSize, 5);
      var changed = false;
      for (var i = 0; i < 5; i++) {
        changed = tracker.recordFrameMs(100) || changed; // 10fps.
      }
      expect(changed, isTrue);
      expect(tracker.tier, PerformanceTier.low);
    });

    group('BUG-23: validate cấu hình + bỏ qua mẫu đầu độc', () {
      test('windowSize <= 0 → ArgumentError ngay lúc tạo', () {
        expect(() => FrameBudgetTracker(windowSize: 0), throwsArgumentError);
        expect(() => FrameBudgetTracker(windowSize: -1), throwsArgumentError);
      });

      test(
        'downgradeFpsThreshold không hữu hạn hoặc âm → ArgumentError',
        () {
          expect(
            () => FrameBudgetTracker(downgradeFpsThreshold: double.nan),
            throwsArgumentError,
          );
          expect(
            () => FrameBudgetTracker(downgradeFpsThreshold: -1),
            throwsArgumentError,
          );
        },
      );

      test(
        'upgradeFpsThreshold không hữu hạn hoặc âm → ArgumentError',
        () {
          expect(
            () => FrameBudgetTracker(upgradeFpsThreshold: double.infinity),
            throwsArgumentError,
          );
          expect(
            () => FrameBudgetTracker(upgradeFpsThreshold: -1),
            throwsArgumentError,
          );
        },
      );

      test(
        'downgradeFpsThreshold >= upgradeFpsThreshold → ArgumentError '
        '(tier sẽ không bao giờ hồi phục được nếu cho phép)',
        () {
          expect(
            () => FrameBudgetTracker(
              downgradeFpsThreshold: 50,
              upgradeFpsThreshold: 50,
            ),
            throwsArgumentError,
          );
          expect(
            () => FrameBudgetTracker(
              downgradeFpsThreshold: 60,
              upgradeFpsThreshold: 40,
            ),
            throwsArgumentError,
          );
        },
      );

      test(
        'mẫu frameDurationMs NaN/Infinity/âm bị bỏ qua, không đầu độc '
        'rolling average vĩnh viễn',
        () {
          final tracker = FrameBudgetTracker(windowSize: 3);

          expect(tracker.recordFrameMs(double.nan), isFalse);
          expect(tracker.recordFrameMs(double.infinity), isFalse);
          expect(tracker.recordFrameMs(-5), isFalse);

          // Sau 3 mẫu HỢP LỆ (16ms ~ 60fps), window phải đầy và tier vẫn ở
          // high — nếu 3 mẫu xấu ở trên lọt vào window, avg sẽ là NaN/vô lý
          // và phép so sánh FPS phía dưới sẽ sai lệch không đoán trước được.
          tracker.recordFrameMs(16);
          tracker.recordFrameMs(16);
          final changed = tracker.recordFrameMs(16);

          expect(changed, isFalse);
          expect(tracker.tier, PerformanceTier.high);
        },
      );
    });
  });

  group('PerformanceTierService', () {
    test('maybe trả về null khi chưa Get.put', () {
      expect(PerformanceTierService.maybe, isNull);
    });

    test('maybe trả về đúng instance khi đã đăng ký', () {
      final service = PerformanceTierService();
      Get.put(service, permanent: true);
      expect(PerformanceTierService.maybe, same(service));
    });

    test('tier bắt đầu ở high', () {
      final service = PerformanceTierService();
      expect(service.tier.value, PerformanceTier.high);
    });

    test('tier.value cập nhật khi feed đủ khung chậm qua recordFrame', () {
      final service = PerformanceTierService(
        tracker: FrameBudgetTracker(windowSize: 10),
      );
      for (var i = 0; i < 10; i++) {
        service.recordFrame(40); // ~25fps < 40 downgrade threshold.
      }
      expect(service.tier.value, PerformanceTier.low);
    });

    test('tier.value quay lại high khi khung nhanh trở lại', () {
      final service = PerformanceTierService(
        tracker: FrameBudgetTracker(windowSize: 10),
      );
      for (var i = 0; i < 10; i++) {
        service.recordFrame(40);
      }
      expect(service.tier.value, PerformanceTier.low);
      for (var i = 0; i < 10; i++) {
        service.recordFrame(10); // ~100fps > 55 upgrade threshold.
      }
      expect(service.tier.value, PerformanceTier.high);
    });

    test('stopListening không throw kể cả khi chưa start()', () {
      final service = PerformanceTierService();
      expect(service.stopListening, returnsNormally);
    });
  });
}

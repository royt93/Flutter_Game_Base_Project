import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/game_session_controller.dart';
import 'package:roy_casual_kit/core/game_time_controller.dart';

void main() {
  tearDown(Get.reset);

  group('GameClock: pure, deterministic', () {
    test('advance() cộng dồn elapsed theo delta * scale', () {
      final clock = GameClock();
      clock.advance(const Duration(milliseconds: 100));
      clock.advance(const Duration(milliseconds: 50));
      expect(clock.elapsed, const Duration(milliseconds: 150));
    });

    test('scale 2.0: advance() cộng gấp đôi thời gian thực', () {
      final clock = GameClock();
      clock.setScale(2);
      clock.advance(const Duration(milliseconds: 100));
      expect(clock.elapsed, const Duration(milliseconds: 200));
    });

    test('paused: advance() không cộng elapsed', () {
      final clock = GameClock();
      clock.advance(const Duration(milliseconds: 100));
      clock.paused = true;
      clock.advance(const Duration(milliseconds: 500));
      expect(clock.elapsed, const Duration(milliseconds: 100));
    });

    test('resume sau pause: thời gian lúc pause không được cộng bù lại', () {
      final clock = GameClock();
      clock.paused = true;
      clock.advance(const Duration(seconds: 10)); // giả lập nền lâu
      clock.paused = false;
      clock.advance(const Duration(milliseconds: 16));
      expect(clock.elapsed, const Duration(milliseconds: 16));
    });

    test('delta âm bị clamp về 0, không làm elapsed lùi', () {
      final clock = GameClock();
      clock.advance(const Duration(milliseconds: 100));
      clock.advance(const Duration(milliseconds: -50));
      expect(clock.elapsed, const Duration(milliseconds: 100));
    });

    test('delta khổng lồ (app từ background quay lại) bị clamp maxDeltaPerTick', () {
      final clock = GameClock(maxDeltaPerTick: const Duration(milliseconds: 250));
      clock.advance(const Duration(minutes: 5));
      expect(clock.elapsed, const Duration(milliseconds: 250));
    });

    test('setScale từ chối NaN/Infinity/0/âm, giữ nguyên scale cũ', () {
      final clock = GameClock();
      expect(clock.setScale(double.nan).isSuccess, isFalse);
      expect(clock.setScale(double.infinity).isSuccess, isFalse);
      expect(clock.setScale(0).isSuccess, isFalse);
      expect(clock.setScale(-1).isSuccess, isFalse);

      clock.advance(const Duration(milliseconds: 100));
      expect(clock.elapsed, const Duration(milliseconds: 100)); // scale vẫn 1.0
    });

    test('fixed-step: chỉ advance đúng bội số fixedStep, phần dư giữ lại cho lần sau', () {
      final clock = GameClock(fixedStep: const Duration(milliseconds: 20));
      final steps1 = clock.advance(const Duration(milliseconds: 45));
      expect(steps1, 2); // 40ms trong 45ms -> 2 step, dư 5ms
      expect(clock.elapsed, const Duration(milliseconds: 40));

      final steps2 = clock.advance(const Duration(milliseconds: 16));
      // dư 5ms + 16ms = 21ms -> thêm đúng 1 step (20ms), dư 1ms
      expect(steps2, 1);
      expect(clock.elapsed, const Duration(milliseconds: 60));
    });

    test('deterministic: cùng chuỗi advance() luôn ra cùng elapsed/step count', () {
      List<int> run() {
        final clock = GameClock(fixedStep: const Duration(milliseconds: 20));
        final steps = <int>[];
        for (final ms in [45, 16, 33, 7, 100]) {
          steps.add(clock.advance(Duration(milliseconds: ms)));
        }
        steps.add(clock.elapsed.inMilliseconds);
        return steps;
      }

      expect(run(), run());
    });
  });

  group('GameTimeController: bridge Flame/Flutter, pause ownership', () {
    test('tick(dt) (giây, kiểu Flame) cộng đúng elapsed quan sát được qua Rx', () {
      final controller = GameTimeController();
      controller.tick(0.1);
      controller.tick(0.05);
      expect(controller.elapsed.value, const Duration(milliseconds: 150));
    });

    test('setScale hợp lệ/không hợp lệ trả SdkResult đúng', () {
      final controller = GameTimeController();
      expect(controller.setScale(2).isSuccess, isTrue);
      expect(controller.setScale(double.nan).isSuccess, isFalse);
    });

    test('không wire GameSessionController: dùng setPaused riêng', () {
      final controller = GameTimeController();
      controller.setPaused(true);
      controller.tick(1);
      expect(controller.elapsed.value, Duration.zero);
    });

    test(
      'có wire GameSessionController: pause qua session là NGUỒN DUY NHẤT, '
      'GameTimeController không tự pause/resume song song',
      () {
        final session = GameSessionController()
          ..markReady()
          ..start();
        final controller = GameTimeController(
          session: session,
          maxDeltaPerTick: const Duration(seconds: 10),
        );

        controller.tick(0.5);
        expect(controller.elapsed.value, const Duration(milliseconds: 500));

        session.pause(GamePauseReason.user);
        controller.tick(1);
        expect(
          controller.elapsed.value,
          const Duration(milliseconds: 500),
        ); // đứng yên vì session paused

        session.resume(GamePauseReason.user);
        controller.tick(0.25);
        expect(controller.elapsed.value, const Duration(milliseconds: 750));
      },
    );

    test('.maybe: null khi chưa đăng ký', () {
      expect(GameTimeController.maybe, isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/player_progression_service.dart';
import 'package:roy_casual_kit/core/reward_transaction_pipeline.dart';
import 'package:roy_casual_kit/presentation/widgets/common/level_up_overlay.dart';

const _fastDurations = (
  xpFill: Duration(milliseconds: 5),
  levelPop: Duration(milliseconds: 5),
  rewardReveal: Duration(milliseconds: 5),
);

LevelUpOverlayController _controller() => LevelUpOverlayController(
  xpFillDuration: _fastDurations.xpFill,
  levelPopDuration: _fastDurations.levelPop,
  rewardRevealDuration: _fastDurations.rewardReveal,
);

LevelUpCelebration _event(int level) => LevelUpCelebration(
  event: LevelUpEvent(
    level: level,
    rewardLines: [RewardLine(currency: 'gem', amount: level * 10)],
  ),
);

void main() {
  group('LevelUpOverlayController: single level-up', () {
    test(
      'phase đi đúng thứ tự xpFill -> levelPop -> rewardReveal -> idle',
      () async {
        final controller = _controller();
        final phases = <LevelUpPhase>[];
        controller.phase.listen(phases.add);

        await controller.show([_event(2)]);

        expect(phases, [
          LevelUpPhase.xpFill,
          LevelUpPhase.levelPop,
          LevelUpPhase.rewardReveal,
          LevelUpPhase.idle,
        ]);
        expect(controller.isActive, isFalse);
      },
    );

    test('onComplete gọi đúng đúng 1 lần sau khi xong', () async {
      final controller = _controller();
      var completeCount = 0;

      await controller.show([_event(2)], onComplete: () => completeCount++);

      expect(completeCount, 1);
    });

    test('events rỗng: gọi onComplete ngay, không đổi phase', () async {
      final controller = _controller();
      var completeCount = 0;

      await controller.show([], onComplete: () => completeCount++);

      expect(completeCount, 1);
      expect(controller.phase.value, LevelUpPhase.idle);
    });
  });

  group('LevelUpOverlayController: multi-level queue', () {
    test(
      'nhiều level lên cùng lúc: hiện đúng thứ tự tăng dần, mỗi level đủ 3 phase',
      () async {
        final controller = _controller();
        final seenLevels = <int>[];
        controller.phase.listen((phase) {
          if (phase == LevelUpPhase.xpFill) {
            seenLevels.add(controller.current!.event.level);
          }
        });

        await controller.show([_event(2), _event(3), _event(4)]);

        expect(seenLevels, [2, 3, 4]);
      },
    );

    test(
      'onComplete chỉ gọi đúng 1 lần ở CUỐI toàn bộ queue, không phải mỗi level',
      () async {
        final controller = _controller();
        var completeCount = 0;

        await controller.show([
          _event(2),
          _event(3),
          _event(4),
        ], onComplete: () => completeCount++);

        expect(completeCount, 1);
      },
    );
  });

  group('LevelUpOverlayController: skip', () {
    test(
      'skip() giữa chừng: nhảy thẳng về idle, onComplete gọi đúng 1 lần',
      () async {
        final controller = LevelUpOverlayController(
          xpFillDuration: const Duration(
            seconds: 10,
          ), // đủ dài để skip kịp giữa chừng
          levelPopDuration: const Duration(seconds: 10),
          rewardRevealDuration: const Duration(seconds: 10),
        );
        var completeCount = 0;

        final future = controller.show([
          _event(2),
          _event(3),
        ], onComplete: () => completeCount++);

        // Đợi 1 microtask để show() kịp set phase = xpFill trước khi skip.
        await Future<void>.delayed(Duration.zero);
        expect(controller.phase.value, LevelUpPhase.xpFill);

        controller.skip();
        await future;

        expect(controller.phase.value, LevelUpPhase.idle);
        expect(completeCount, 1);
      },
    );

    test('skip() rồi gọi lại nhiều lần: không gọi onComplete trùng', () async {
      final controller = _controller();
      var completeCount = 0;

      final future = controller.show([
        _event(2),
      ], onComplete: () => completeCount++);
      await Future<void>.delayed(Duration.zero);
      controller.skip();
      controller.skip();
      controller.skip();
      await future;

      expect(completeCount, 1);
    });
  });

  group('LevelUpOverlayController: dispose', () {
    test(
      'dispose() giữa chừng: không mutate phase thêm, không gọi onComplete',
      () async {
        final controller = LevelUpOverlayController(
          xpFillDuration: const Duration(seconds: 10),
          levelPopDuration: const Duration(seconds: 10),
          rewardRevealDuration: const Duration(seconds: 10),
        );
        var completeCount = 0;

        // ignore: unawaited_futures
        controller.show([_event(2)], onComplete: () => completeCount++);
        await Future<void>.delayed(Duration.zero);
        final phaseAtDispose = controller.phase.value;

        controller.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          controller.phase.value,
          phaseAtDispose,
        ); // không đổi thêm sau dispose
        expect(completeCount, 0);
      },
    );

    test('show() sau khi đã dispose: no-op an toàn, không throw', () async {
      final controller = _controller();
      controller.dispose();

      expect(() => controller.show([_event(2)]), returnsNormally);
    });
  });

  group('LevelUpOverlayController: rebuild không gọi lại/không trùng', () {
    test(
      'gọi show() lần 2 khi lần 1 đã xong: chạy đúng bình thường, không kế thừa completion cũ',
      () async {
        final controller = _controller();
        var firstComplete = 0;
        var secondComplete = 0;

        await controller.show([_event(2)], onComplete: () => firstComplete++);
        await controller.show([_event(3)], onComplete: () => secondComplete++);

        expect(firstComplete, 1);
        expect(secondComplete, 1);
      },
    );

    test(
      'gọi show() mới trong khi show() cũ CHƯA xong: show cũ bị supersede, chỉ onComplete mới được gọi',
      () async {
        final controller = LevelUpOverlayController(
          xpFillDuration: const Duration(milliseconds: 200),
          levelPopDuration: const Duration(milliseconds: 5),
          rewardRevealDuration: const Duration(milliseconds: 5),
        );
        var oldComplete = 0;
        var newComplete = 0;

        // ignore: unawaited_futures
        controller.show([_event(2)], onComplete: () => oldComplete++);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await controller.show([_event(3)], onComplete: () => newComplete++);

        expect(oldComplete, 0);
        expect(newComplete, 1);
      },
    );
  });
}

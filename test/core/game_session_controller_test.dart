import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/game_session_controller.dart';
import 'package:roy_casual_kit/core/lifecycle_coordinator.dart';

void main() {
  tearDown(() => Get.reset());

  test('valid flow reaches terminal state and rejects terminal exit', () {
    final c = GameSessionController();
    expect(c.markReady().isSuccess, isTrue);
    expect(c.start().isSuccess, isTrue);
    expect(c.win().isSuccess, isTrue);
    expect(c.start().isSuccess, isFalse);
    expect(c.pause(GamePauseReason.user).isSuccess, isFalse);
  });

  test('nested system/user pause resumes only after both reasons clear', () {
    final c = GameSessionController();
    c.markReady();
    c.start();
    c.pause(GamePauseReason.user);
    c.pause(GamePauseReason.system);
    expect(c.snapshot.value.pauseReasons, {
      GamePauseReason.user,
      GamePauseReason.system,
    });
    c.resume(GamePauseReason.system);
    expect(c.snapshot.value.phase, GameSessionPhase.paused);
    c.resume(GamePauseReason.user);
    expect(c.snapshot.value.phase, GameSessionPhase.playing);
  });

  test('lifecycle bridge and dispose remove callback', () async {
    final lifecycle = RoyLifecycleCoordinator();
    final c = GameSessionController(lifecycle: lifecycle);
    Get.put(c);
    c.markReady();
    c.start();
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);
    expect(c.snapshot.value.phase, GameSessionPhase.paused);
    Get.delete<GameSessionController>();
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(c.snapshot.value.phase, GameSessionPhase.paused);
  });

  testWidgets('consumer can render session state', (tester) async {
    final c = GameSessionController();
    await tester.pumpWidget(
      MaterialApp(home: Obx(() => Text(c.snapshot.value.phase.name))),
    );
    expect(find.text('loading'), findsOneWidget);
    c.markReady();
    await tester.pump();
    expect(find.text('ready'), findsOneWidget);
  });

  group('ENH-61: restart() resets events instead of appending forever', () {
    test('restart() resets events to just [loading], không giữ lịch sử cũ', () {
      final c = GameSessionController();
      c.markReady();
      c.start();
      c.win();
      expect(c.events, [
        GameSessionPhase.ready,
        GameSessionPhase.playing,
        GameSessionPhase.won,
      ]);

      c.restart();

      expect(c.events, [GameSessionPhase.loading]);
    });

    test('restart() reset đúng snapshot', () {
      final c = GameSessionController();
      c.markReady();
      c.start();
      c.restart();
      expect(c.snapshot.value.phase, GameSessionPhase.loading);
    });

    test(
      '100 lần restart() liên tiếp: events không phình to theo số lần gọi',
      () {
        final c = GameSessionController();
        for (var i = 0; i < 100; i++) {
          c.restart();
        }
        expect(c.events.length, 1);
        expect(c.events, [GameSessionPhase.loading]);
      },
    );

    test('hành vi các transition khác không đổi sau khi restart()', () {
      final c = GameSessionController();
      c.markReady();
      c.start();
      c.restart();

      expect(c.markReady().isSuccess, isTrue);
      expect(c.start().isSuccess, isTrue);
      expect(c.win().isSuccess, isTrue);
      expect(c.events, [
        GameSessionPhase.loading,
        GameSessionPhase.ready,
        GameSessionPhase.playing,
        GameSessionPhase.won,
      ]);
    });
  });

  group('BUG-93 audit: hookName collision', () {
    test(
      'default constructor: 2 instance CÙNG lifecycle -> đóng instance A '
      '(onClose) xoá nhầm hook của B vì cả 2 dùng chung hookName mặc định '
      '"game-session" (removeHook match theo tên, không theo instance)',
      () async {
        final lifecycle = RoyLifecycleCoordinator();
        final a = Get.put<GameSessionController>(
          GameSessionController(lifecycle: lifecycle),
          tag: 'a',
        );
        final b = Get.put<GameSessionController>(
          GameSessionController(lifecycle: lifecycle),
          tag: 'b',
        );
        a.markReady();
        a.start();
        b.markReady();
        b.start();

        Get.delete<GameSessionController>(tag: 'a', force: true);

        lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
        await Future<void>.delayed(Duration.zero);
        expect(b.snapshot.value.phase, GameSessionPhase.playing);

        Get.delete<GameSessionController>(tag: 'b', force: true);
      },
    );

    test('withHookName: 2 instance CÙNG lifecycle nhưng hookName KHÁC nhau -> '
        'đóng instance A không ảnh hưởng hook của B', () async {
      final lifecycle = RoyLifecycleCoordinator();
      final a = Get.put<GameSessionController>(
        GameSessionController.withHookName(
          lifecycle: lifecycle,
          hookName: 'session-a',
        ),
        tag: 'a',
      );
      final b = Get.put<GameSessionController>(
        GameSessionController.withHookName(
          lifecycle: lifecycle,
          hookName: 'session-b',
        ),
        tag: 'b',
      );
      a.markReady();
      a.start();
      b.markReady();
      b.start();

      Get.delete<GameSessionController>(tag: 'a', force: true);

      lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(b.snapshot.value.phase, GameSessionPhase.paused);

      Get.delete<GameSessionController>(tag: 'b', force: true);
    });

    test('withHookName: hookName rỗng -> ArgumentError tại constructor', () {
      expect(
        () => GameSessionController.withHookName(hookName: ''),
        throwsArgumentError,
      );
    });
  });

  group('ENH-65: .maybe', () {
    test('trả về null khi chưa Get.put', () {
      expect(GameSessionController.maybe, isNull);
    });

    test('trả về đúng instance khi đã đăng ký', () {
      final c = GameSessionController();
      Get.put(c);
      expect(GameSessionController.maybe, same(c));
    });
  });

  group('BUG-90: lifecycle wiring observability + pause/resume history', () {
    test(
      'constructor với lifecycle == null in cảnh báo dlog, không im lặng',
      () {
        final messages = <String>[];
        final original = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) messages.add(message);
        };
        addTearDown(() => debugPrint = original);

        GameSessionController();

        expect(
          messages.any((m) => m.contains('lifecycle') && m.contains('null')),
          isTrue,
        );
      },
    );

    test(
      'constructor với lifecycle thật -> KHÔNG cảnh báo (wiring đã đúng)',
      () {
        final messages = <String>[];
        final original = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) messages.add(message);
        };
        addTearDown(() => debugPrint = original);

        GameSessionController(lifecycle: RoyLifecycleCoordinator());

        expect(
          messages.any((m) => m.contains('lifecycle') && m.contains('null')),
          isFalse,
        );
      },
    );

    test(
      'pause()/resume() ghi nhận vào events, không chỉ markReady/start/...',
      () {
        final c = GameSessionController();
        c.markReady();
        c.start();
        c.pause(GamePauseReason.user);
        c.resume(GamePauseReason.user);

        expect(c.events, [
          GameSessionPhase.ready,
          GameSessionPhase.playing,
          GameSessionPhase.paused,
          GameSessionPhase.playing,
        ]);
      },
    );

    test(
      'nested pause (user+system) chỉ ghi 1 event mỗi lần resume thực sự '
      'đổi phase, không ghi khi vẫn còn pause reason khác giữ trạng thái',
      () {
        final c = GameSessionController();
        c.markReady();
        c.start();
        c.pause(GamePauseReason.user);
        c.pause(GamePauseReason.system);
        c.resume(GamePauseReason.system);

        expect(c.events, [
          GameSessionPhase.ready,
          GameSessionPhase.playing,
          GameSessionPhase.paused,
        ]);

        c.resume(GamePauseReason.user);
        expect(c.events, [
          GameSessionPhase.ready,
          GameSessionPhase.playing,
          GameSessionPhase.paused,
          GameSessionPhase.playing,
        ]);
      },
    );
  });
}

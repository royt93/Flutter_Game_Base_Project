import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/game_session_controller.dart';
import 'package:roy_casual_kit/core/lifecycle_coordinator.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';

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

  group('ENH-96: GameSessionController.withTimeline', () {
    test('timelineCapacity <= 0 -> ArgumentError tại constructor', () {
      expect(
        () => GameSessionController.withTimeline(timelineCapacity: 0),
        throwsArgumentError,
      );
    });

    test('legacy win()/lose() và constructors mặc định KHÔNG đổi hành vi — '
        'events/snapshot y hệt trước ENH-96', () {
      final c = GameSessionController();
      c.markReady();
      c.start();
      expect(c.win().isSuccess, isTrue);
      expect(c.events, [
        GameSessionPhase.ready,
        GameSessionPhase.playing,
        GameSessionPhase.won,
      ]);
    });

    test('withTimeline dùng fake Stopwatch — offsetMs ghi đúng, đơn điệu tăng, '
        'không phụ thuộc wall-clock', () {
      var elapsed = 0;
      final fakeStopwatch = _FakeStopwatch(() => elapsed);
      final c = GameSessionController.withTimeline(
        createStopwatch: () => fakeStopwatch,
      );
      c.markReady();
      elapsed = 100;
      c.start();
      elapsed = 250;
      c.winWithMetadata({});

      // Entry 0 is the implicit `loading@0` every session starts with
      // (same as `events` always starting with `loading`).
      expect(c.timeline.map((e) => e.offsetMs), [0, 0, 100, 250]);
      expect(c.timeline.map((e) => e.phase), [
        GameSessionPhase.loading,
        GameSessionPhase.ready,
        GameSessionPhase.playing,
        GameSessionPhase.won,
      ]);
    });

    test('pause ghi lại đầy đủ pauseReasons hiện tại trong entry, outcome '
        '(win/lose) ghi lại metadata đã sanitize', () {
      final c = GameSessionController.withTimeline(
        allowedMetadataKeys: {'combo', 'userId'},
      );
      c.markReady();
      c.start();
      c.pause(GamePauseReason.user);
      c.pause(GamePauseReason.system);
      c.resume(GamePauseReason.system);
      c.resume(GamePauseReason.user);
      c.loseWithMetadata({'combo': 7, 'userId': 'should-be-blacklisted'});

      // Timeline records every pause-reason change as its own entry
      // (unlike `events`, which only logs the overall phase); the entry
      // where BOTH reasons were simultaneously active is the one with 2
      // reasons recorded.
      final bothReasonsEntry = c.timeline.firstWhere(
        (e) => e.phase == GameSessionPhase.paused && e.pauseReasons.length == 2,
      );
      expect(bothReasonsEntry.pauseReasons, {
        GamePauseReason.user,
        GamePauseReason.system,
      });

      final lostEntry = c.timeline.last;
      expect(lostEntry.phase, GameSessionPhase.lost);
      // 'combo' is allowlisted and not PII -> kept. 'userId' is
      // allowlisted but IS in ReproductionCapsule.defaultRedactedKeys ->
      // dropped despite being explicitly allowlisted (blacklist wins).
      expect(lostEntry.metadata, {'combo': 7});
    });

    test('metadata key không nằm trong allowedMetadataKeys bị bỏ qua, dù '
        'không phải PII', () {
      final c = GameSessionController.withTimeline(
        allowedMetadataKeys: {'combo'},
      );
      c.markReady();
      c.start();
      c.winWithMetadata({'combo': 3, 'notAllowed': 'dropped'});

      expect(c.timeline.last.metadata, {'combo': 3});
    });

    test('timelineCapacity evicts oldest entry khi vượt quá, không bao giờ '
        'vượt cap', () {
      final c = GameSessionController.withTimeline(timelineCapacity: 2);
      c.markReady();
      c.start();
      c.pause(GamePauseReason.user);

      expect(c.timeline, hasLength(2));
      expect(c.timeline.map((e) => e.phase), [
        GameSessionPhase.playing,
        GameSessionPhase.paused,
      ]);
    });

    test('restart() reset cả events lẫn timeline/stopwatch — timeline chỉ còn '
        '1 entry loading@0', () {
      var elapsed = 500;
      final fakeStopwatch = _FakeStopwatch(() => elapsed);
      final c = GameSessionController.withTimeline(
        createStopwatch: () => fakeStopwatch,
      );
      c.markReady();
      c.start();
      c.restart();

      expect(c.timeline, hasLength(1));
      expect(c.timeline.single.phase, GameSessionPhase.loading);
      expect(c.timeline.single.offsetMs, 0);
    });

    test('exportTimeline() round-trip JSON chính xác, không chứa trường '
        'wall-clock/device/user identifier nào ngoài metadata đã sanitize', () {
      final c = GameSessionController.withTimeline(
        allowedMetadataKeys: {'combo'},
      );
      c.markReady();
      c.start();
      c.winWithMetadata({'combo': 9});

      final export = c.exportTimeline();
      final json = export.toJson();
      final encoded = jsonEncode(json);
      final decoded = GameSessionTimelineExport.fromJson(
        jsonDecode(encoded) as Map<String, Object?>,
      );

      expect(decoded.schemaVersion, export.schemaVersion);
      expect(decoded.terminalPhase, GameSessionPhase.won);
      expect(decoded.entries.length, export.entries.length);
      expect(decoded.entries.last.metadata, {'combo': 9});
      expect(encoded, isNot(contains('deviceId')));
      expect(encoded, isNot(contains('userId')));
    });

    test('withTimeline rejects an empty lifecycle hook name', () {
      expect(
        () => GameSessionController.withTimeline(hookName: ''),
        throwsArgumentError,
      );
    });

    test('paused timeline round-trips recognized pause reasons only', () {
      final c = GameSessionController.withTimeline();
      c.markReady();
      c.start();
      c.pause(GamePauseReason.user);
      c.pause(GamePauseReason.system);
      final raw = c.exportTimeline().toJson();
      final parsed = GameSessionTimelineExport.fromJson(
        jsonDecode(jsonEncode(raw)) as Map<String, Object?>,
      );
      expect(parsed.terminalPhase, isNull);
      expect(parsed.entries.last.pauseReasons, {
        GamePauseReason.user,
        GamePauseReason.system,
      });
      final entry = GameSessionTimelineEntry.fromJson({
        'pauseReasons': ['user', 'alien', 12, 'system'],
        'metadata': {'combo': 1},
      });
      expect(entry.pauseReasons, {
        GamePauseReason.user,
        GamePauseReason.system,
      });
      expect(entry.metadata, {'combo': 1});
      expect(
        () => entry.pauseReasons.add(GamePauseReason.user),
        throwsUnsupportedError,
      );
      expect(() => entry.metadata['combo'] = 2, throwsUnsupportedError);
    });

    test(
      'snapshot copyWith retains unspecified state and immutable reasons',
      () {
        const original = GameSessionSnapshot(
          GameSessionPhase.paused,
          pauseReasons: {GamePauseReason.user},
        );
        final same = original.copyWith();
        expect(same.phase, GameSessionPhase.paused);
        expect(same.pauseReasons, {GamePauseReason.user});
        final changed = original.copyWith(
          phase: GameSessionPhase.playing,
          pauseReasons: {},
        );
        expect(changed.phase, GameSessionPhase.playing);
        expect(changed.pauseReasons, isEmpty);
        expect(original.pauseReasons, {GamePauseReason.user});
        expect(() => same.pauseReasons.clear(), throwsUnsupportedError);
      },
    );

    test('foreground lifecycle clears only system pause reason', () async {
      final lifecycle = RoyLifecycleCoordinator();
      final c = Get.put(GameSessionController(lifecycle: lifecycle));
      c.markReady();
      c.start();
      c.pause(GamePauseReason.user);
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(c.snapshot.value.pauseReasons, {
        GamePauseReason.user,
        GamePauseReason.system,
      });
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(c.snapshot.value.phase, GameSessionPhase.paused);
      expect(c.snapshot.value.pauseReasons, {GamePauseReason.user});
      expect(c.resume(GamePauseReason.user).isSuccess, isTrue);
      expect(c.snapshot.value.phase, GameSessionPhase.playing);
    });

    test(
      'lost session cannot pause or resume and retains terminal timeline',
      () {
        final c = GameSessionController();
        c.markReady();
        c.start();
        c.lose();
        final events = c.events.toList();
        final timeline = c.timeline;
        expect(c.pause(GamePauseReason.system).isSuccess, isFalse);
        expect(c.resume(GamePauseReason.system).isSuccess, isFalse);
        expect(c.snapshot.value.phase, GameSessionPhase.lost);
        expect(c.events, events);
        expect(c.timeline, timeline);
      },
    );

    test(
      'timeline entries and export handle corrupted/unusual json gracefully',
      () {
        final entry = GameSessionTimelineEntry.fromJson({
          'offsetMs': 'not an int',
          'phase': 'unknown_phase',
          'pauseReasons': ['not_a_valid_reason', 123],
          'metadata': 'not a map',
        });
        expect(entry.offsetMs, 0);
        expect(entry.phase, GameSessionPhase.loading);
        expect(entry.pauseReasons, isEmpty);
        expect(entry.metadata, isEmpty);

        final export = GameSessionTimelineExport.fromJson({
          'schemaVersion': 'not an int',
          'durationMs': 'not an int',
          'terminalPhase': null,
          'entries': 'not a list',
        });
        expect(export.schemaVersion, 0);
        expect(export.durationMs, 0);
        expect(export.terminalPhase, isNull);
        expect(export.entries, isEmpty);

        final exportWithCorruptedList = GameSessionTimelineExport.fromJson({
          'terminalPhase': 'alien_phase',
          'entries': [
            'not a map',
            {'offsetMs': 10, 'phase': 'won'},
          ],
        });
        expect(exportWithCorruptedList.terminalPhase, GameSessionPhase.loading);
        expect(exportWithCorruptedList.entries, hasLength(1));
      },
    );

    test('invalid phase transitions reject appropriately', () {
      final c = GameSessionController();
      // loading state cannot pause
      final resPause = c.pause(GamePauseReason.user);
      expect(resPause.isSuccess, isFalse);
      expect(
        (resPause as SdkFailure<GameSessionSnapshot>).message,
        contains('not playing'),
      );

      // cannot resume if not paused
      final resResume = c.resume(GamePauseReason.user);
      expect(resResume.isSuccess, isFalse);
      expect(
        (resResume as SdkFailure<GameSessionSnapshot>).message,
        contains('not active'),
      );

      // resume unheld reason while paused
      c.markReady();
      c.start();
      c.pause(GamePauseReason.user);
      final unheldResume = c.resume(GamePauseReason.system);
      expect(unheldResume.isSuccess, isFalse);
      expect(
        (unheldResume as SdkFailure<GameSessionSnapshot>).message,
        contains('not active'),
      );
    });
  });
}

class _FakeStopwatch implements Stopwatch {
  _FakeStopwatch(this._elapsed);
  final int Function() _elapsed;

  @override
  int get elapsedMilliseconds => _elapsed();

  @override
  Duration get elapsed => Duration(milliseconds: _elapsed());

  @override
  void start() {}

  @override
  void stop() {}

  @override
  void reset() {}

  @override
  bool get isRunning => true;

  @override
  int get elapsedMicroseconds => _elapsed() * 1000;

  @override
  int get elapsedTicks => _elapsed();

  @override
  int get frequency => 1000;
}

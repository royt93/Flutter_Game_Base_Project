import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/haptic_choreographer.dart';
import 'package:roy_casual_kit/core/haptics.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTimer implements Timer {
  _FakeTimer(this.callback);
  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HapticPattern: validation', () {
    test('danh sách pulses rỗng throw ArgumentError', () {
      expect(() => HapticPattern(const []), throwsArgumentError);
    });

    test('vượt quá maxPulses throw ArgumentError', () {
      final tooMany = List.generate(
        HapticPattern.maxPulses + 1,
        (_) => const HapticPulse(level: HapticLevel.light),
      );
      expect(() => HapticPattern(tooMany), throwsArgumentError);
    });

    test('đúng bằng maxPulses không throw', () {
      final exact = List.generate(
        HapticPattern.maxPulses,
        (_) => const HapticPulse(level: HapticLevel.light),
      );
      expect(() => HapticPattern(exact), returnsNormally);
    });

    test('delayAfter âm throw ArgumentError', () {
      expect(
        () => HapticPattern([
          const HapticPulse(
            level: HapticLevel.light,
            delayAfter: Duration(milliseconds: -1),
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('delayAfter vượt maxDelayPerPulse throw ArgumentError', () {
      expect(
        () => HapticPattern([
          HapticPulse(
            level: HapticLevel.light,
            delayAfter:
                HapticPattern.maxDelayPerPulse +
                const Duration(milliseconds: 1),
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('tổng thời lượng vượt maxTotalDuration throw ArgumentError', () {
      final perPulse = Duration(
        milliseconds:
            HapticPattern.maxTotalDuration.inMilliseconds ~/
                (HapticPattern.maxPulses - 1) +
            10,
      );
      final pulses = List.generate(
        HapticPattern.maxPulses,
        (i) => HapticPulse(
          level: HapticLevel.light,
          delayAfter: i == HapticPattern.maxPulses - 1
              ? Duration.zero
              : perPulse,
        ),
      );
      expect(() => HapticPattern(pulses), throwsArgumentError);
    });
  });

  group('HapticPattern: presets', () {
    test('reward/combo/error đều construct hợp lệ, không throw', () {
      expect(HapticPattern.reward.pulses, isNotEmpty);
      expect(HapticPattern.combo.pulses, isNotEmpty);
      expect(HapticPattern.error.pulses, isNotEmpty);
    });

    test(
      'error preset là 2 pulse heavy tách biệt bằng khoảng nghỉ rõ ràng',
      () {
        final pulses = HapticPattern.error.pulses;
        expect(pulses, hasLength(2));
        expect(pulses[0].level, HapticLevel.heavy);
        expect(pulses[1].level, HapticLevel.heavy);
        expect(pulses[0].delayAfter, greaterThan(Duration.zero));
      },
    );
  });

  group('HapticChoreographer: playback xác định', () {
    late List<HapticLevel> fired;
    late List<_FakeTimer> scheduled;
    late HapticChoreographer choreographer;

    setUp(() {
      fired = [];
      scheduled = [];
      choreographer = HapticChoreographer(
        fire: fired.add,
        createTimer: (delay, callback) {
          final timer = _FakeTimer(callback);
          scheduled.add(timer);
          return timer;
        },
      );
    });

    test('play() fire ngay pulse đầu tiên, đồng bộ (không chờ timer)', () {
      choreographer.play(
        HapticPattern([const HapticPulse(level: HapticLevel.medium)]),
      );

      expect(fired, [HapticLevel.medium]);
    });

    test(
      'pattern 1 pulse không schedule timer nào (không có pulse kế tiếp)',
      () {
        choreographer.play(
          HapticPattern([const HapticPulse(level: HapticLevel.light)]),
        );

        expect(scheduled, isEmpty);
      },
    );

    test('pattern nhiều pulse: đúng thứ tự, đúng số timer được schedule', () {
      choreographer.play(
        HapticPattern([
          const HapticPulse(
            level: HapticLevel.light,
            delayAfter: Duration(milliseconds: 50),
          ),
          const HapticPulse(
            level: HapticLevel.medium,
            delayAfter: Duration(milliseconds: 50),
          ),
          const HapticPulse(level: HapticLevel.heavy),
        ]),
      );

      expect(fired, [HapticLevel.light]);
      expect(scheduled, hasLength(1));

      scheduled[0].callback();
      expect(fired, [HapticLevel.light, HapticLevel.medium]);
      expect(scheduled, hasLength(2));

      scheduled[1].callback();
      expect(fired, [HapticLevel.light, HapticLevel.medium, HapticLevel.heavy]);
      // Pulse cuối không có pulse kế tiếp -> không schedule thêm timer.
      expect(scheduled, hasLength(2));
    });

    test(
      'cancel() trước khi timer đã schedule kịp chạy: pulse kế tiếp KHÔNG bao giờ fire',
      () {
        choreographer.play(
          HapticPattern([
            const HapticPulse(
              level: HapticLevel.light,
              delayAfter: Duration(milliseconds: 50),
            ),
            const HapticPulse(level: HapticLevel.heavy),
          ]),
        );
        expect(fired, [HapticLevel.light]);

        choreographer.cancel();
        expect(scheduled.single.cancelled, isTrue);

        // Mô phỏng timer vẫn còn "callback" tồn tại đâu đó (race) và bị
        // gọi nhầm sau cancel() — generation guard phải chặn được, không
        // chỉ dựa vào Timer.cancel() của Dart thật.
        scheduled.single.callback();
        expect(fired, [HapticLevel.light]);
      },
    );

    test(
      'play() gọi lại (pattern mới) trong khi pattern cũ còn đang chờ: KHÔNG chồng lấn — chỉ pattern mới chạy (rate-limit rage tap)',
      () {
        choreographer.play(
          HapticPattern([
            const HapticPulse(
              level: HapticLevel.light,
              delayAfter: Duration(milliseconds: 50),
            ),
            const HapticPulse(level: HapticLevel.heavy),
          ]),
        );
        expect(fired, [HapticLevel.light]);
        final staleTimer = scheduled.single;

        // "Rage tap" — gọi play() lại NGAY, trước khi timer cũ kịp chạy.
        choreographer.play(
          HapticPattern([const HapticPulse(level: HapticLevel.medium)]),
        );

        expect(fired, [HapticLevel.light, HapticLevel.medium]);
        expect(staleTimer.cancelled, isTrue);

        // Dù timer cũ (đã bị cancel) vẫn bị gọi nhầm, pulse "heavy" của
        // pattern CŨ không được phép lọt vào danh sách đã fire.
        staleTimer.callback();
        expect(fired, [HapticLevel.light, HapticLevel.medium]);
      },
    );

    test(
      'cùng 1 pattern chạy lại nhiều lần cho kết quả xác định giống hệt nhau',
      () {
        final pattern = HapticPattern([
          const HapticPulse(
            level: HapticLevel.light,
            delayAfter: Duration(milliseconds: 10),
          ),
          const HapticPulse(level: HapticLevel.heavy),
        ]);

        choreographer.play(pattern);
        scheduled.single.callback();
        final firstRun = List.of(fired);

        fired.clear();
        scheduled.clear();
        choreographer.play(pattern);
        scheduled.single.callback();

        expect(fired, firstRun);
      },
    );

    test('cancel() khi chưa play() gì là no-op an toàn, không throw', () {
      expect(() => choreographer.cancel(), returnsNormally);
    });

    test(
      'cancel() sau khi pattern đã chạy xong hoàn toàn là no-op an toàn',
      () {
        choreographer.play(
          HapticPattern([const HapticPulse(level: HapticLevel.light)]),
        );
        expect(() => choreographer.cancel(), returnsNormally);
      },
    );
  });

  group('HapticChoreographer: tích hợp với fireHaptic thật (mặc định)', () {
    final calls = <MethodCall>[];
    late StorageService store;

    setUp(() async {
      calls.clear();
      SharedPreferences.setMockInitialValues({});
      store = StorageService(await SharedPreferences.getInstance());
      Get.put(store, permanent: true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      Get.reset();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test(
      'mặc định play() gọi thẳng fireHaptic thật, tôn trọng hapticsEnabled=false',
      () async {
        await store.setBool(StorageKeys.hapticsEnabled, false);
        final choreographer = HapticChoreographer();

        choreographer.play(HapticPattern.reward);
        await Future<void>.delayed(Duration.zero);

        expect(calls, isEmpty);
      },
    );

    test(
      'mặc định play() gọi platform method khi haptics bật (mặc định)',
      () async {
        final choreographer = HapticChoreographer();

        choreographer.play(
          HapticPattern([const HapticPulse(level: HapticLevel.heavy)]),
        );
        await Future<void>.delayed(Duration.zero);

        expect(calls, isNotEmpty);
      },
    );
  });

  group('IDEA-67: comboSyncHapticPattern', () {
    test('tạo đúng số pulse bằng steps truyền vào', () {
      final pattern = comboSyncHapticPattern(
        steps: 4,
        stepInterval: const Duration(milliseconds: 150),
      );

      expect(pattern.pulses, hasLength(4));
    });

    test('mỗi pulse có đúng delayAfter = stepInterval', () {
      const interval = Duration(milliseconds: 200);
      final pattern = comboSyncHapticPattern(steps: 3, stepInterval: interval);

      for (final pulse in pattern.pulses) {
        expect(pulse.delayAfter, interval);
      }
    });

    test(
      'mặc định dùng hapticLevelForGroupSize -> leo thang light -> medium -> heavy',
      () {
        final pattern = comboSyncHapticPattern(
          steps: 10,
          stepInterval: const Duration(milliseconds: 100),
        );

        // hapticLevelForGroupSize: <4 light, 4-7 medium, >=8 heavy.
        expect(pattern.pulses[0].level, HapticLevel.light); // step 1
        expect(pattern.pulses[3].level, HapticLevel.medium); // step 4
        expect(pattern.pulses[7].level, HapticLevel.heavy); // step 8
      },
    );

    test('levelForStep tuỳ chỉnh được dùng thay vì mặc định', () {
      final pattern = comboSyncHapticPattern(
        steps: 3,
        stepInterval: const Duration(milliseconds: 100),
        levelForStep: (step) => HapticLevel.heavy,
      );

      expect(
        pattern.pulses.every((p) => p.level == HapticLevel.heavy),
        isTrue,
      );
    });

    test('steps: 0 hoặc âm -> throw ArgumentError, không tạo pattern rỗng', () {
      expect(
        () => comboSyncHapticPattern(
          steps: 0,
          stepInterval: const Duration(milliseconds: 100),
        ),
        throwsArgumentError,
      );
      expect(
        () => comboSyncHapticPattern(
          steps: -1,
          stepInterval: const Duration(milliseconds: 100),
        ),
        throwsArgumentError,
      );
    });

    test(
      'steps vượt quá HapticPattern.maxPulses -> vẫn throw đúng (không '
      'bypass validation có sẵn của HapticPattern)',
      () {
        expect(
          () => comboSyncHapticPattern(
            steps: HapticPattern.maxPulses + 1,
            stepInterval: const Duration(milliseconds: 100),
          ),
          throwsArgumentError,
        );
      },
    );

    test('pattern trả về chơi được thật qua HapticChoreographer.play()', () async {
      final calls = <MethodCall>[];
      SharedPreferences.setMockInitialValues({});
      final store = StorageService(await SharedPreferences.getInstance());
      Get.put(store, permanent: true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        Get.reset();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final choreographer = HapticChoreographer();
      choreographer.play(
        comboSyncHapticPattern(
          steps: 2,
          stepInterval: const Duration(milliseconds: 10),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(calls, isNotEmpty);
    });
  });
}

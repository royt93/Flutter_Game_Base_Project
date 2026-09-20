import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_session_tracker.dart';
import 'package:roy_casual_kit/core/consent_state_service.dart';
import 'package:roy_casual_kit/core/lifecycle_coordinator.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real `Stopwatch` measures actual wall time — inject a fake one so
/// foreground-duration tests are instant and deterministic (same
/// seam-injection convention as `createTimer`).
class _FakeStopwatch implements Stopwatch {
  bool _running = false;
  Duration _elapsed = Duration.zero;

  @override
  void start() => _running = true;

  @override
  void stop() => _running = false;

  @override
  void reset() => _elapsed = Duration.zero;

  @override
  bool get isRunning => _running;

  @override
  Duration get elapsed => _elapsed;

  void advance(Duration d) {
    if (_running) _elapsed += d;
  }

  @override
  int get elapsedMicroseconds => elapsed.inMicroseconds;

  @override
  int get elapsedMilliseconds => elapsed.inMilliseconds;

  @override
  int get elapsedTicks => elapsedMicroseconds;

  @override
  int get frequency => 1000000;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  late StorageService store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = StorageService(await SharedPreferences.getInstance());
    Get.put(store, permanent: true);
  });

  group('AppSessionTracker: accessor', () {
    test('maybe trả về null khi chưa Get.put', () {
      expect(AppSessionTracker.maybe, isNull);
    });
  });

  group('AppSessionTracker: cold start', () {
    test('cold start đầu tiên: sequence = 1, installTimeMs được set', () {
      final tracker = AppSessionTracker();
      expect(tracker.current.sequence, 1);
      expect(tracker.current.installTimeMs, greaterThan(0));
    });

    test(
      'cold start lần 2 (cùng storage): sequence tăng đúng 1, installTimeMs GIỮ NGUYÊN',
      () {
        final first = AppSessionTracker();
        final installTimeMs = first.current.installTimeMs;

        final second = AppSessionTracker();

        expect(second.current.sequence, 2);
        expect(second.current.installTimeMs, installTimeMs);
      },
    );

    test('2 lần cold start cho 2 sessionId khác nhau', () {
      final first = AppSessionTracker();
      final second = AppSessionTracker();

      expect(first.current.sessionId, isNot(second.current.sessionId));
    });

    test(
      'sequence persisted âm/hỏng (hand-edited): clamp về 0 trước khi +1, không throw',
      () async {
        await store.setInt(StorageKeys.appSessionSequence, -5);

        final tracker = AppSessionTracker();

        expect(tracker.current.sequence, 1);
      },
    );
  });

  group('AppSessionTracker: foreground duration', () {
    test('mới cold start: bắt đầu đếm foreground ngay', () {
      final fake = _FakeStopwatch();
      final tracker = AppSessionTracker(createStopwatch: () => fake);

      fake.advance(const Duration(seconds: 5));

      expect(tracker.foregroundDuration, const Duration(seconds: 5));
    });

    test('background: dừng đếm, thời gian background KHÔNG được tính', () {
      final fake = _FakeStopwatch();
      final tracker = AppSessionTracker(createStopwatch: () => fake);
      fake.advance(const Duration(seconds: 3));

      tracker.handleLifecycleEvent(RoyLifecycleEvent.background);
      fake.advance(const Duration(seconds: 100)); // vẫn "trôi" nhưng đã stop

      expect(tracker.foregroundDuration, const Duration(seconds: 3));
    });

    test(
      'resume trong sessionTimeout: tiếp tục CÙNG session, cộng dồn foreground',
      () {
        final fake = _FakeStopwatch();
        final tracker = AppSessionTracker(
          createStopwatch: () => fake,
          sessionTimeout: const Duration(minutes: 30),
        );
        final originalSessionId = tracker.current.sessionId;
        fake.advance(const Duration(seconds: 3));

        tracker.handleLifecycleEvent(RoyLifecycleEvent.background);
        tracker.handleLifecycleEvent(RoyLifecycleEvent.resumed);
        fake.advance(const Duration(seconds: 2));

        expect(tracker.current.sessionId, originalSessionId);
        expect(tracker.foregroundDuration, const Duration(seconds: 5));
      },
    );
  });

  group(
    'AppSessionTracker: resume ngoài policy (sessionTimeout) tạo session mới',
    () {
      test(
        'background lâu hơn sessionTimeout: resume tạo session mới, reset foreground',
        () async {
          final fake = _FakeStopwatch();
          final tracker = AppSessionTracker(
            createStopwatch: () => fake,
            sessionTimeout: const Duration(minutes: 30),
          );
          final originalSessionId = tracker.current.sessionId;
          final originalSequence = tracker.current.sequence;
          fake.advance(const Duration(seconds: 3));

          tracker.handleLifecycleEvent(RoyLifecycleEvent.background);
          // Mô phỏng trôi qua 31 phút thật bằng maxMsSeen (nowMsClamped
          // dùng để tính khoảng cách backgroundedAtMs -> resume).
          final realMs = DateTime.now().toUtc().millisecondsSinceEpoch;
          store.setInt(
            StorageKeys.maxMsSeen,
            realMs + const Duration(minutes: 31).inMilliseconds,
          );
          tracker.handleLifecycleEvent(RoyLifecycleEvent.resumed);

          expect(tracker.current.sessionId, isNot(originalSessionId));
          expect(tracker.current.sequence, originalSequence + 1);
          expect(tracker.foregroundDuration, Duration.zero);
        },
      );
    },
  );

  group('AppSessionTracker: consent gate cho analytics context', () {
    test('chưa có ConsentStateService: analyticsContext() rỗng', () {
      final tracker = AppSessionTracker();
      expect(tracker.analyticsContext(), isEmpty);
    });

    test('consent chưa quyết định/denied: analyticsContext() rỗng', () {
      Get.put(ConsentStateService(policyVersion: 1), permanent: true);
      final tracker = AppSessionTracker();

      expect(tracker.analyticsContext(), isEmpty);
    });

    test(
      'consent granted: analyticsContext() có đúng field, không rò field lạ',
      () {
        final consent = ConsentStateService(policyVersion: 1);
        Get.put(consent, permanent: true);
        consent.grant(ConsentCategory.analytics);
        final tracker = AppSessionTracker();

        final context = tracker.analyticsContext();

        expect(context['sessionId'], tracker.current.sessionId);
        expect(context['sessionSequence'], tracker.current.sequence);
        expect(context.containsKey('installTimeMs'), isTrue);
        expect(context.containsKey('foregroundDurationMs'), isTrue);
      },
    );
  });

  group(
    'AppSessionTracker: lifecycle hook tích hợp RoyLifecycleCoordinator',
    () {
      test(
        'đăng ký hook đúng vào RoyLifecycleCoordinator khi có sẵn',
        () async {
          final lifecycle = RoyLifecycleCoordinator();
          Get.put(lifecycle, permanent: true);
          final fake = _FakeStopwatch();
          final tracker = AppSessionTracker(createStopwatch: () => fake);
          fake.advance(const Duration(seconds: 1));

          lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
          await Future<void>.delayed(Duration.zero);

          expect(tracker.foregroundDuration, const Duration(seconds: 1));
        },
      );
    },
  );
}

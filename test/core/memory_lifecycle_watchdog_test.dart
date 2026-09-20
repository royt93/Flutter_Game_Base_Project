import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/memory_lifecycle_watchdog.dart';

void main() {
  setUp(MemoryWatchdog.reset);
  tearDown(() {
    MemoryWatchdog.nowMs = () => DateTime.now().millisecondsSinceEpoch;
    MemoryWatchdog.reset();
  });

  group('track/release: happy path', () {
    test('track rồi release ngay -> không còn orphan', () {
      final id = MemoryWatchdog.track(WatchdogKind.overlay, owner: 'X');
      expect(MemoryWatchdog.orphans(), hasLength(1));
      MemoryWatchdog.release(id);
      expect(MemoryWatchdog.orphans(), isEmpty);
    });

    test('release id không tồn tại/đã release rồi -> no-op, không throw', () {
      expect(() => MemoryWatchdog.release(9999), returnsNormally);
      final id = MemoryWatchdog.track(WatchdogKind.overlay, owner: 'X');
      MemoryWatchdog.release(id);
      expect(() => MemoryWatchdog.release(id), returnsNormally);
    });

    test('release ghi lại lịch sử recentlyDisposed kèm disposedAtMs', () {
      MemoryWatchdog.nowMs = () => 100;
      final id = MemoryWatchdog.track(
        WatchdogKind.subscription,
        owner: 'Y',
        label: 'sub1',
      );
      MemoryWatchdog.nowMs = () => 200;
      MemoryWatchdog.release(id);

      final history = MemoryWatchdog.recentlyDisposed();
      expect(history, hasLength(1));
      expect(history.single.entry.owner, 'Y');
      expect(history.single.entry.label, 'sub1');
      expect(history.single.disposedAtMs, 200);
    });
  });

  group('orphans: fixture leak thật bị bắt', () {
    testWidgets(
      'AnimationController không dispose -> báo orphan; dispose xong -> hết',
      (tester) async {
        final controller = AnimationController(
          vsync: tester,
          duration: const Duration(seconds: 1),
        );
        final id = MemoryWatchdog.track(
          WatchdogKind.controller,
          owner: 'MyWidgetState',
        );

        expect(MemoryWatchdog.orphans(), hasLength(1));
        expect(MemoryWatchdog.orphans().single.kind, WatchdogKind.controller);

        controller.dispose();
        MemoryWatchdog.release(id);

        expect(MemoryWatchdog.orphans(), isEmpty);
      },
    );

    test(
      'StreamSubscription không cancel -> báo orphan; cancel xong -> hết',
      () async {
        final controller = StreamController<int>();
        final sub = controller.stream.listen((_) {});
        final id = MemoryWatchdog.track(
          WatchdogKind.subscription,
          owner: 'MyService',
        );

        expect(MemoryWatchdog.orphans(), hasLength(1));

        await sub.cancel();
        MemoryWatchdog.release(id);
        await controller.close();

        expect(MemoryWatchdog.orphans(), isEmpty);
      },
    );

    test('nhiều resource leak cùng lúc đều bị liệt kê đủ, không chỉ 1', () {
      MemoryWatchdog.track(WatchdogKind.ticker, owner: 'A');
      MemoryWatchdog.track(WatchdogKind.overlay, owner: 'B');
      MemoryWatchdog.track(WatchdogKind.flameComponent, owner: 'C');

      final orphans = MemoryWatchdog.orphans();
      expect(orphans, hasLength(3));
      expect(
        orphans.map((e) => e.kind),
        containsAll([
          WatchdogKind.ticker,
          WatchdogKind.overlay,
          WatchdogKind.flameComponent,
        ]),
      );
    });
  });

  group('allowlist: false positive được kiểm soát', () {
    test(
      'label được allow không bị báo orphan dù không bao giờ release '
      '(vd NeonBg permanent ticker — Ticker cố ý sống suốt vòng đời widget)',
      () {
        MemoryWatchdog.allow('NeonBg.ticker');
        MemoryWatchdog.track(
          WatchdogKind.ticker,
          owner: 'NeonBg',
          label: 'NeonBg.ticker',
        );

        expect(MemoryWatchdog.orphans(), isEmpty);
      },
    );

    test('label không nằm trong allowlist vẫn bị báo orphan bình thường', () {
      MemoryWatchdog.allow('SomeOtherLabel');
      MemoryWatchdog.track(
        WatchdogKind.ticker,
        owner: 'NeonBg',
        label: 'NeonBg.ticker',
      );

      expect(MemoryWatchdog.orphans(), hasLength(1));
    });

    test(
      'track không có label -> allowlist không áp dụng được, luôn báo orphan',
      () {
        MemoryWatchdog.allow('anything');
        MemoryWatchdog.track(WatchdogKind.ticker, owner: 'X');

        expect(MemoryWatchdog.orphans(), hasLength(1));
      },
    );

    test(
      'disallow gỡ đúng 1 label khỏi allowlist, label khác không ảnh hưởng',
      () {
        MemoryWatchdog.allow('a');
        MemoryWatchdog.allow('b');
        MemoryWatchdog.track(WatchdogKind.ticker, owner: 'X', label: 'a');
        MemoryWatchdog.track(WatchdogKind.ticker, owner: 'Y', label: 'b');
        expect(MemoryWatchdog.orphans(), isEmpty);

        MemoryWatchdog.disallow('a');
        final orphans = MemoryWatchdog.orphans();
        expect(orphans, hasLength(1));
        expect(orphans.single.label, 'a');
      },
    );
  });

  group('minAge: lọc theo tuổi entry', () {
    test('entry vừa tạo, chưa đủ minAge -> không tính là orphan', () {
      var fakeNow = 1000;
      MemoryWatchdog.nowMs = () => fakeNow;
      MemoryWatchdog.track(WatchdogKind.overlay, owner: 'X');

      expect(
        MemoryWatchdog.orphans(minAge: const Duration(seconds: 5)),
        isEmpty,
      );

      fakeNow += 6000;
      expect(
        MemoryWatchdog.orphans(minAge: const Duration(seconds: 5)),
        hasLength(1),
      );
    });

    test('không truyền minAge -> báo orphan ngay cả khi vừa tạo', () {
      MemoryWatchdog.track(WatchdogKind.overlay, owner: 'X');
      expect(MemoryWatchdog.orphans(), hasLength(1));
    });
  });

  group('reset: dọn sạch mọi state', () {
    test('reset xoá live entries, history và allowlist', () {
      MemoryWatchdog.allow('a');
      final id = MemoryWatchdog.track(
        WatchdogKind.ticker,
        owner: 'X',
        label: 'a',
      );
      MemoryWatchdog.release(id);
      MemoryWatchdog.track(WatchdogKind.overlay, owner: 'Y');

      MemoryWatchdog.reset();

      expect(MemoryWatchdog.orphans(), isEmpty);
      expect(MemoryWatchdog.recentlyDisposed(), isEmpty);
      // allowlist bị xoá: track lại label 'a' phải báo orphan lại.
      MemoryWatchdog.track(WatchdogKind.ticker, owner: 'X', label: 'a');
      expect(MemoryWatchdog.orphans(), hasLength(1));
    });
  });

  group('memoryWatchdogHealthCollector', () {
    test('không có orphan -> orphanCount 0, orphanKinds rỗng', () async {
      final spec = memoryWatchdogHealthCollector();
      final result = await spec.collect();
      expect(result['orphanCount'], 0);
      expect(result['orphanKinds'], isEmpty);
    });

    test('có orphan -> đúng count và đúng kind (sort ổn định)', () async {
      MemoryWatchdog.track(WatchdogKind.ticker, owner: 'A');
      MemoryWatchdog.track(WatchdogKind.overlay, owner: 'B');
      MemoryWatchdog.track(WatchdogKind.overlay, owner: 'C');

      final spec = memoryWatchdogHealthCollector();
      final result = await spec.collect();
      expect(result['orphanCount'], 3);
      expect(result['orphanKinds'], ['overlay', 'ticker']);
    });

    test('allowedKeys chỉ đúng 2 field, không leak owner/label ra ngoài', () {
      final spec = memoryWatchdogHealthCollector();
      expect(spec.allowedKeys, {'orphanCount', 'orphanKinds'});
    });
  });
}

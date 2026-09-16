import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/async_action_guard.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';

void main() {
  test(
    'single flight shares one future per key and cleans up on error',
    () async {
      final guard = AsyncActionGuard();
      final gate = Completer<int>();
      var calls = 0;
      final first = guard.runSingleFlight('save', () {
        calls++;
        return gate.future;
      });
      final second = guard.runSingleFlight('save', () {
        calls++;
        return 99;
      });
      final other = guard.runSingleFlight('other', () async => 7);
      expect(await other, 7);
      gate.complete(42);
      expect(await first, 42);
      expect(await second, 42);
      expect(calls, 1);
      expect(guard.pendingCount, 0);
      await expectLater(
        guard.runSingleFlight('bad', () => Future<int>.error(StateError('x'))),
        throwsStateError,
      );
      expect(guard.pendingCount, 0);
    },
  );

  test(
    'exclusive queues same key, isolates exceptions, and allows recovery',
    () async {
      final guard = AsyncActionGuard();
      final order = <String>[];
      final first = guard.runExclusive('wallet', () async {
        order.add('a:start');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        order.add('a:end');
        return 1;
      });
      final second = guard.runExclusive('wallet', () async {
        order.add('b');
        return 2;
      });
      final bad = guard.runExclusive('wallet', () async {
        throw StateError('bad');
      });
      final recovery = guard.runExclusive('wallet', () async {
        order.add('recovered');
        return 4;
      });
      expect(await first, 1);
      expect(await second, 2);
      await expectLater(bad, throwsStateError);
      expect(await recovery, 4);
      expect(order, ['a:start', 'a:end', 'b', 'recovered']);
      expect(guard.pendingCount, 0);
    },
  );

  testWidgets('CommonButton can disable duplicate async action', (
    tester,
  ) async {
    final guard = AsyncActionGuard();
    var calls = 0;
    var busy = false;
    late StateSetter setState;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setter) {
            setState = setter;
            return CommonButton(
              label: busy ? 'Loading' : 'Save',
              onTap: busy
                  ? null
                  : () {
                      setState(() => busy = true);
                      unawaited(
                        guard.runSingleFlight('save', () async {
                          calls++;
                          await Future<void>.delayed(
                            const Duration(milliseconds: 20),
                          );
                          setState(() => busy = false);
                        }),
                      );
                    },
            );
          },
        ),
      ),
    );
    await tester.tap(find.byType(CommonButton));
    await tester.pump();
    expect(find.text('Loading').evaluate(), isNotEmpty);
    expect(calls, 1);
    await tester.pump(const Duration(milliseconds: 30));
    expect(guard.pendingCount, 0);
  });

  group('ENH-63: maxQueueWait', () {
    testWidgets(
      'lệnh gọi chờ hàng đợi lâu hơn maxQueueWait nhận đúng TimeoutException, không treo vô hạn',
      (tester) async {
        final guard = AsyncActionGuard(
          maxQueueWait: const Duration(milliseconds: 50),
        );
        final blocker = Completer<void>();
        // Chiếm key 'k' bằng 1 action không bao giờ tự hoàn thành (mô
        // phỏng "kẹt") — đúng kịch bản maxQueueWait được thiết kế để xử lý.
        final first = guard.runExclusive('k', () => blocker.future);

        Object? caught;
        final second = guard
            .runExclusive('k', () async => 2)
            .catchError((Object e) {
              caught = e;
              return -1;
            });

        await tester.pump(const Duration(milliseconds: 60));
        await second;

        expect(caught, isA<TimeoutException>());

        blocker.complete();
        await first;
        await tester.pump();
      },
    );

    testWidgets(
      'sau 1 lệnh gọi timeout, runExclusive MỚI cho ĐÚNG key vẫn chạy được, không bị kẹt bởi hàng đợi cũ đã timeout',
      (tester) async {
        final guard = AsyncActionGuard(
          maxQueueWait: const Duration(milliseconds: 50),
        );
        final blocker = Completer<void>();
        final order = <String>[];
        final first = guard.runExclusive('k', () => blocker.future);
        final second = guard
            .runExclusive('k', () async => 2)
            .catchError((Object _) => -1);

        await tester.pump(const Duration(milliseconds: 60));
        await second; // second đã timeout và tự dọn dẹp xong

        // 'third' KHÔNG liên quan gì tới 'first'/'second' — theo đúng thiết
        // kế của maxQueueWait, không được chờ 'first' (vốn vẫn đang treo)
        // mới chạy được.
        final third = guard.runExclusive('k', () async {
          order.add('third:ran');
          return 3;
        });
        await tester.pump();

        expect(order, ['third:ran']);
        expect(await third, 3);

        blocker.complete();
        await first;
        await tester.pump();
      },
    );

    testWidgets('pendingCount không bị rò rỉ/sai lệch sau khi có lệnh gọi timeout', (
      tester,
    ) async {
      final guard = AsyncActionGuard(
        maxQueueWait: const Duration(milliseconds: 50),
      );
      final blocker = Completer<void>();
      final first = guard.runExclusive('k', () => blocker.future);
      expect(guard.pendingCount, 1);

      final second = guard
          .runExclusive('k', () async => 2)
          .catchError((Object _) => -1);
      expect(guard.pendingCount, 1); // second thay thế chỗ của first trong map

      await tester.pump(const Duration(milliseconds: 60));
      await second;
      expect(guard.pendingCount, 0); // second timeout, tự dọn dẹp, không rò rỉ

      blocker.complete();
      await first;
      await tester.pump();
      expect(guard.pendingCount, 0);
    });

    testWidgets(
      'maxQueueWait == null (mặc định): vẫn chờ vô thời hạn như cũ, không throw (hồi quy)',
      (tester) async {
        final guard = AsyncActionGuard(); // maxQueueWait mặc định null
        final order = <String>[];
        final first = guard.runExclusive('k', () async {
          order.add('first:start');
          await Future<void>.delayed(const Duration(milliseconds: 200));
          order.add('first:end');
          return 1;
        });
        final second = guard.runExclusive('k', () async {
          order.add('second:ran');
          return 2;
        });

        // Vượt xa khoảng thời gian đã dùng làm maxQueueWait ở các test
        // trên (50ms) — nếu implementation lỡ áp dụng 1 timeout ngầm nào
        // đó dù maxQueueWait là null, test này sẽ bắt được ngay.
        await tester.pump(const Duration(milliseconds: 250));

        expect(await first, 1);
        expect(await second, 2);
        expect(order, ['first:start', 'first:end', 'second:ran']);
        expect(guard.pendingCount, 0);
      },
    );
  });
}

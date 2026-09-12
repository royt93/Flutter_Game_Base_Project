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
}

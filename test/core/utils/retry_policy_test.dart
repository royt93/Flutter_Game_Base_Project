import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/retry_policy.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';

void main() {
  group('RetryPolicy.delayBeforeAttempt', () {
    const policy = RetryPolicy(
      baseDelay: Duration(milliseconds: 100),
      maxDelay: Duration(seconds: 2),
      jitterFraction: 0.2,
    );

    test('attempt 1: không delay (lần thử đầu tiên)', () {
      expect(policy.delayBeforeAttempt(1, 0.5), Duration.zero);
    });

    test('attempt 2, randomValue=0.5 (giữa): đúng bằng baseDelay, không jitter', () {
      expect(
        policy.delayBeforeAttempt(2, 0.5),
        const Duration(milliseconds: 100),
      );
    });

    test('attempt 3: tăng gấp đôi so với attempt 2 (exponential)', () {
      expect(
        policy.delayBeforeAttempt(3, 0.5),
        const Duration(milliseconds: 200),
      );
    });

    test('jitter randomValue=0 -> thấp hơn base; randomValue=1 -> cao hơn base', () {
      final low = policy.delayBeforeAttempt(2, 0);
      final high = policy.delayBeforeAttempt(2, 1);
      expect(low, lessThan(const Duration(milliseconds: 100)));
      expect(high, greaterThan(const Duration(milliseconds: 100)));
    });

    test('attempt rất lớn: cap đúng ở maxDelay, không overflow/NaN', () {
      final delay = policy.delayBeforeAttempt(50, 0.5);
      expect(delay, const Duration(seconds: 2));
      expect(delay.isNegative, isFalse);
    });

    test('maxAttempts/jitterFraction biên hợp lệ không throw lúc construct', () {
      expect(
        () => const RetryPolicy(maxAttempts: 1, jitterFraction: 0),
        returnsNormally,
      );
      expect(
        () => const RetryPolicy(jitterFraction: 1),
        returnsNormally,
      );
    });
  });

  group('RetryExecutor.run', () {
    late List<Duration> delaysUsed;
    late List<RetryAttemptEvent> events;
    late RetryExecutor executor;

    setUp(() {
      delaysUsed = [];
      events = [];
      executor = RetryExecutor(
        delayFn: (d) async => delaysUsed.add(d),
        randomFn: () => 0.5, // deterministic, không jitter
      );
    });

    Future<SdkResult<T>> run<T>(
      Future<T> Function() action, {
      RetryPolicy policy = const RetryPolicy(maxAttempts: 3, baseDelay: Duration(milliseconds: 10)),
      bool Function(Object error)? retryIf,
      bool Function()? isCancelled,
    }) => executor.run(
      action,
      policy: policy,
      retryIf: retryIf,
      onAttempt: events.add,
      isCancelled: isCancelled,
    );

    test('thành công ngay lần đầu: không delay, không retry', () async {
      var calls = 0;
      final result = await run(() async {
        calls++;
        return 42;
      });

      expect(result.isSuccess, isTrue);
      expect(result.value, 42);
      expect(calls, 1);
      expect(delaysUsed, isEmpty);
    });

    test('fail 2 lần rồi thành công lần 3: phục hồi đúng sau lỗi transient', () async {
      var calls = 0;
      final result = await run(() async {
        calls++;
        if (calls < 3) throw Exception('transient');
        return 'ok';
      });

      expect(result.isSuccess, isTrue);
      expect(result.value, 'ok');
      expect(calls, 3);
      expect(delaysUsed.length, 2); // delay trước attempt 2 và 3
      expect(
        events.map((e) => e.outcome),
        [RetryOutcome.retrying, RetryOutcome.retrying, RetryOutcome.success],
      );
    });

    test('lỗi không được phép retry (retryIf=false): dừng ngay ở lần đầu', () async {
      var calls = 0;
      final result = await run(
        () async {
          calls++;
          throw const FormatException('bad data');
        },
        retryIf: (error) => error is! FormatException,
      );

      expect(result.isSuccess, isFalse);
      expect(calls, 1);
      expect(delaysUsed, isEmpty);
      expect(events.single.outcome, RetryOutcome.failedNonRetryable);
    });

    test('hết maxAttempts vẫn lỗi: dừng đúng, không retry vô hạn, giữ cause/stackTrace cuối', () async {
      var calls = 0;
      final result = await run(() async {
        calls++;
        throw StateError('always fails');
      });

      expect(result.isSuccess, isFalse);
      expect(calls, 3); // đúng bằng maxAttempts, không hơn
      final failure = result as SdkFailure;
      expect(failure.cause, isA<StateError>());
      expect(failure.stackTrace, isNotNull);
      expect(failure.retryable, isFalse); // đã hết attempt, retry lại vô ích
      expect(events.last.outcome, RetryOutcome.failedExhausted);
    });

    test('cancel giữa chừng: dừng ngay, không chạy tiếp attempt sau', () async {
      var calls = 0;
      var cancelled = false;
      final result = await run(
        () async {
          calls++;
          if (calls == 1) cancelled = true; // huỷ ngay sau lần thử đầu
          throw Exception('transient');
        },
        isCancelled: () => cancelled,
      );

      expect(result.isSuccess, isFalse);
      expect(calls, 1);
      expect(events.last.outcome, RetryOutcome.cancelled);
    });

    test('timeout per-attempt: TimeoutException đi qua đúng logic retry (mặc định retryable)', () async {
      var calls = 0;
      final result = await run(
        () async {
          calls++;
          if (calls == 1) {
            await Future<void>.delayed(const Duration(seconds: 10));
          }
          return 'done';
        },
        policy: const RetryPolicy(
          maxAttempts: 2,
          baseDelay: Duration(milliseconds: 10),
          timeout: Duration(milliseconds: 1),
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.value, 'done');
      expect(calls, 2);
    });

    test('delay/random đều đi qua hàm inject được, không dùng Future.delayed/Random thật', () async {
      final policy = const RetryPolicy(maxAttempts: 2, baseDelay: Duration(seconds: 999));
      var randomCalled = false;
      final injected = RetryExecutor(
        delayFn: (d) async {}, // no-op, không thật sự chờ 999s
        randomFn: () {
          randomCalled = true;
          return 0.5;
        },
      );

      final result = await injected.run(
        () async {
          throw Exception('x');
        },
        policy: policy,
        retryIf: (_) => true,
      );

      expect(result.isSuccess, isFalse);
      expect(randomCalled, isTrue);
    });
  });
}

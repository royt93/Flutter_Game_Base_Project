import 'dart:async';
import 'dart:math';

import 'sdk_result.dart';

/// Immutable exponential-backoff-with-jitter configuration — no timers, no
/// randomness of its own, just the math. [RetryExecutor] is what actually
/// runs a retry loop against it.
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 200),
    this.maxDelay = const Duration(seconds: 10),
    this.timeout,
    this.jitterFraction = 0.2,
  }) : assert(maxAttempts >= 1, 'maxAttempts must be >= 1'),
       assert(
         jitterFraction >= 0 && jitterFraction <= 1,
         'jitterFraction must be within [0, 1]',
       );

  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;

  /// Per-attempt timeout — `null` means an attempt can run indefinitely.
  final Duration? timeout;

  /// Fraction of the (pre-jitter) delay randomized in either direction —
  /// `0.2` means the actual delay lands within ±20% of the exponential
  /// value, capped to [maxDelay] either way.
  final double jitterFraction;

  /// Delay before attempt [attemptNumber] (1-indexed — attempt 1 is the
  /// first try, so it's always [Duration.zero]). [randomValue] must be in
  /// `[0, 1]`; callers needing determinism (tests, or [RetryExecutor]'s own
  /// injected `randomFn`) supply it directly instead of this class reaching
  /// for `dart:math`'s `Random` itself.
  ///
  /// Computed entirely in `double` microseconds so a very large
  /// [attemptNumber] (2^exponent overflowing toward infinity) still clamps
  /// correctly to [maxDelay] via [min] instead of overflowing/throwing —
  /// `min(double.infinity, x) == x`.
  Duration delayBeforeAttempt(int attemptNumber, double randomValue) {
    if (attemptNumber <= 1) return Duration.zero;
    final exponent = attemptNumber - 2;
    final rawMicros = baseDelay.inMicroseconds.toDouble() * pow(2, exponent);
    final cappedMicros = min(rawMicros, maxDelay.inMicroseconds.toDouble());
    final jitterRange = cappedMicros * jitterFraction;
    final jittered = cappedMicros + (randomValue * 2 - 1) * jitterRange;
    final safeMicros = jittered.clamp(0, maxDelay.inMicroseconds.toDouble());
    return Duration(microseconds: safeMicros.round());
  }
}

/// Why a single attempt/the whole [RetryExecutor.run] call ended the way it
/// did — passed to `onAttempt` for observability (logging, a debug
/// overlay, ...).
enum RetryOutcome {
  success,
  retrying,
  failedNonRetryable,
  failedExhausted,
  cancelled,
}

class RetryAttemptEvent {
  const RetryAttemptEvent({
    required this.attemptNumber,
    required this.outcome,
    this.error,
    this.stackTrace,
    this.nextDelay,
  });

  final int attemptNumber;
  final RetryOutcome outcome;
  final Object? error;
  final StackTrace? stackTrace;

  /// Set only on [RetryOutcome.retrying] — how long before the next attempt.
  final Duration? nextDelay;
}

/// Runs an action against a [RetryPolicy]. [delayFn]/[randomFn] are
/// injectable (default to real `Future.delayed`/`Random().nextDouble()`) so
/// a test drives the whole retry loop deterministically and instantly,
/// never actually waiting real backoff delays — same seam-injection
/// convention as `HapticChoreographer`'s `createTimer`.
///
/// Typical integration — `RemoteConfigService.fetchRemote` (or a
/// `CloudSaveProvider` call) is exactly the kind of "one flaky network
/// call" this wraps, without `RemoteConfigService` itself knowing anything
/// about retries:
/// ```dart
/// RemoteConfigService(
///   assetPath: 'assets/remote_config_defaults.json',
///   fetchRemote: () async {
///     final result = await RetryExecutor().run(
///       () => myHttpClient.fetchConfigJson(),
///       policy: const RetryPolicy(maxAttempts: 3),
///       retryIf: (error) => error is! FormatException, // bad payload: don't retry
///     );
///     return result.value ?? {}; // RemoteConfigService treats {} as "no override"
///   },
/// );
/// ```
class RetryExecutor {
  RetryExecutor({
    Future<void> Function(Duration delay)? delayFn,
    double Function()? randomFn,
  }) : _delayFn = delayFn ?? Future<void>.delayed,
       _randomFn = randomFn ?? (() => Random().nextDouble());

  final Future<void> Function(Duration delay) _delayFn;
  final double Function() _randomFn;

  /// Runs [action] under [policy]. [retryIf] decides whether a thrown
  /// error is worth retrying (default: always retryable) — a caller
  /// checking e.g. `error is! FormatException` can stop immediately on a
  /// non-transient error instead of burning through every attempt.
  /// [isCancelled] is polled before the first attempt and after every
  /// delay; once it returns `true` the loop stops without starting another
  /// attempt. The final failure's `cause`/`stackTrace` are always
  /// preserved in the returned [SdkFailure] — a retry loop giving up never
  /// silently drops the last real error.
  Future<SdkResult<T>> run<T>(
    Future<T> Function() action, {
    RetryPolicy policy = const RetryPolicy(),
    bool Function(Object error)? retryIf,
    void Function(RetryAttemptEvent event)? onAttempt,
    bool Function()? isCancelled,
  }) async {
    for (var attempt = 1; attempt <= policy.maxAttempts; attempt++) {
      if (attempt > 1) {
        final delay = policy.delayBeforeAttempt(attempt, _randomFn());
        await _delayFn(delay);
      }
      if (isCancelled?.call() ?? false) {
        onAttempt?.call(
          RetryAttemptEvent(
            attemptNumber: attempt,
            outcome: RetryOutcome.cancelled,
          ),
        );
        return const SdkFailure(
          kind: SdkErrorKind.unknown,
          message: 'Retry cancelled',
        );
      }
      try {
        final future = action();
        final timeout = policy.timeout;
        final value = timeout == null
            ? await future
            : await future.timeout(timeout);
        onAttempt?.call(
          RetryAttemptEvent(
            attemptNumber: attempt,
            outcome: RetryOutcome.success,
          ),
        );
        return SdkSuccess(value);
      } catch (error, stack) {
        final retryable = retryIf?.call(error) ?? true;
        final exhausted = attempt >= policy.maxAttempts;
        if (!retryable) {
          onAttempt?.call(
            RetryAttemptEvent(
              attemptNumber: attempt,
              outcome: RetryOutcome.failedNonRetryable,
              error: error,
              stackTrace: stack,
            ),
          );
          return SdkFailure(
            kind: SdkErrorKind.unknown,
            message: 'Non-retryable error',
            cause: error,
            stackTrace: stack,
          );
        }
        if (exhausted) {
          onAttempt?.call(
            RetryAttemptEvent(
              attemptNumber: attempt,
              outcome: RetryOutcome.failedExhausted,
              error: error,
              stackTrace: stack,
            ),
          );
          return SdkFailure(
            kind: SdkErrorKind.unknown,
            message: 'Retries exhausted',
            cause: error,
            stackTrace: stack,
          );
        }
        onAttempt?.call(
          RetryAttemptEvent(
            attemptNumber: attempt,
            outcome: RetryOutcome.retrying,
            error: error,
            stackTrace: stack,
            nextDelay: policy.delayBeforeAttempt(attempt + 1, 0),
          ),
        );
      }
    }
    // Unreachable: the loop above always returns before exhausting its
    // range (the last iteration's `exhausted` branch always returns).
    throw StateError('unreachable');
  }
}

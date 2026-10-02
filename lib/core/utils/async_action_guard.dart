import 'dart:async';

/// Coordinates asynchronous actions by logical key.
class AsyncActionGuard {
  AsyncActionGuard({this.maxQueueWait});

  final Duration? maxQueueWait;
  final _singleFlights = <Object, Future<Object?>>{};
  final _exclusiveTails = <Object, Future<void>>{};

  int get pendingCount => _singleFlights.length + _exclusiveTails.length;

  Future<T> runSingleFlight<T>(Object key, FutureOr<T> Function() action) {
    final existing = _singleFlights[key];
    if (existing != null) return existing.then((value) => value as T);
    final future = Future<T>.sync(action);
    _singleFlights[key] = future;
    void cleanup() {
      if (identical(_singleFlights[key], future)) _singleFlights.remove(key);
    }

    future.then<void>((_) => cleanup(), onError: (error, stack) => cleanup());
    return future;
  }

  Future<T> runExclusive<T>(Object key, FutureOr<T> Function() action) async {
    final previous = _exclusiveTails[key] ?? Future<void>.value();
    final myTurn = Completer<void>();
    // BUG-96: the barrier this waiter publishes for the NEXT caller must
    // stay pending until `previous` (the ACTUAL holder, however long that
    // takes) really finishes — not until this waiter's own `maxQueueWait`
    // timeout gives up on it. Chaining onto `previous` (rather than
    // completing a fresh tail immediately) is what keeps a C queued behind
    // this B still correctly blocked on A while A is still running, even
    // though B itself returns (with a TimeoutException) long before A does.
    // `previous` never itself throws (its own `finally` below always
    // completes successfully), but guard with `onError` anyway so a waiter
    // that somehow still throws can't wedge the chain for later callers.
    final tail = previous.then<void>(
      (_) => myTurn.future,
      onError: (_, _) => myTurn.future,
    );
    _exclusiveTails[key] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_exclusiveTails[key], tail)) _exclusiveTails.remove(key);
      }),
    );
    var acquired = false;
    try {
      final wait = maxQueueWait;
      if (wait == null) {
        await previous;
      } else {
        await previous.timeout(wait);
      }
      acquired = true;
      return await Future<T>.sync(action);
    } finally {
      if (!myTurn.isCompleted) myTurn.complete();
      if (acquired) {
        // Preserve the pre-BUG-96 observable contract for the normal path:
        // once this call's returned Future completes, its keyed barrier has
        // already been cleaned up (`pendingCount == 0` when it was last).
        // A timed-out waiter MUST NOT await [tail] here, because [tail] is
        // intentionally still chained to the stuck predecessor — awaiting it
        // would make maxQueueWait stop returning promptly.
        await tail;
        if (identical(_exclusiveTails[key], tail)) {
          _exclusiveTails.remove(key);
        }
      }
    }
  }
}

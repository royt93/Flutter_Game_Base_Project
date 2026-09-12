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
    final completer = Completer<void>();
    _exclusiveTails[key] = completer.future;
    try {
      final wait = maxQueueWait;
      if (wait == null) {
        await previous;
      } else {
        await previous.timeout(wait);
      }
      return await Future<T>.sync(action);
    } finally {
      if (!completer.isCompleted) completer.complete();
      if (identical(_exclusiveTails[key], completer.future)) {
        _exclusiveTails.remove(key);
      }
    }
  }
}

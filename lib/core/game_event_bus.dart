import 'dart:async';

/// Base type for every event flowing through a [GameEventBus]. Extend this
/// to add a new gameplay event — the bus itself never needs to change.
/// Deliberately a plain abstract class, not `sealed`: a `sealed` hierarchy
/// must live entirely inside this package, but a consuming game needs to
/// define its own event subtypes (e.g. `EntityDefeated`, `LevelCompleted`)
/// outside it.
abstract class GameEvent {
  const GameEvent();
}

/// Lightweight typed pub/sub bus bridging gameplay events (fired from a
/// Flame [Component]/game loop) to business-logic services
/// (`EconomyWallet`, `AchievementService`, `AnalyticsProvider`, ...) that
/// want to react to them — without every new event type requiring a manual
/// wire-up at each interested service.
///
/// Entirely optional: nothing in this package requires a [GameEventBus] to
/// exist. A game built on [RoyGame] that never creates one behaves exactly
/// as before.
class GameEventBus {
  final _controller = StreamController<GameEvent>.broadcast();

  /// Emits [event] to every current subscriber whose type matches. A no-op
  /// once [dispose] has run — a gameplay callback racing a screen's own
  /// teardown shouldn't crash on a stale bus reference.
  void emit(GameEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }

  /// Subscribes to events of type [T] (or a subtype). If [onEvent] throws,
  /// the error is caught and passed to [onError] (if given) rather than
  /// rethrown — one failing subscriber never crashes the bus or any other
  /// subscriber.
  StreamSubscription<GameEvent> subscribe<T extends GameEvent>(
    void Function(T event) onEvent, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    return _controller.stream.where((event) => event is T).listen((event) {
      try {
        onEvent(event as T);
      } catch (error, stackTrace) {
        onError?.call(error, stackTrace);
      }
    });
  }

  /// Closes the underlying stream. Call from the owner's `dispose()`.
  Future<void> dispose() => _controller.close();
}

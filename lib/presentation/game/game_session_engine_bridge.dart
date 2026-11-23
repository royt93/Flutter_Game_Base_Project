import 'package:flame/game.dart';
import 'package:get/get.dart';

import '../../core/game_session_controller.dart';

/// Keeps a Flame [Game]'s update loop in step with a [GameSessionController]:
/// the engine is paused while the session is `paused` and resumed when it
/// returns to `playing`.
///
/// Listening to the session's phase (not to a particular pause button) means
/// every source is covered uniformly: a pause overlay, a manual call, and the
/// controller's own `RoyLifecycleCoordinator` hook that pauses on app
/// background all end up as the same phase change.
///
/// Other phases leave the engine alone on purpose: `loading` and `ready` are
/// owned by whoever boots the game, and `won`/`lost` are terminal states the
/// caller decides how to present (a result card usually wants the scene
/// frozen or animating, which is the game's call, not this bridge's).
///
/// Call [dispose] before the session is deleted; it stops listening.
class GameSessionEngineBridge {
  GameSessionEngineBridge({required this.session, required this.game}) {
    _sync(session.snapshot.value);
    _worker = ever<GameSessionSnapshot>(session.snapshot, _sync);
  }

  final GameSessionController session;
  final Game game;
  late final Worker _worker;
  bool _disposed = false;

  void _sync(GameSessionSnapshot snapshot) {
    if (_disposed) return;
    if (snapshot.phase == GameSessionPhase.paused && !game.paused) {
      game.pauseEngine();
    } else if (snapshot.phase == GameSessionPhase.playing && game.paused) {
      game.resumeEngine();
    }
  }

  /// Stops listening. Safe to call more than once. Does not touch the
  /// engine's current paused state.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _worker.dispose();
  }
}

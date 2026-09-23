import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Color, Paint;

import '../../core/game_event_bus.dart';
import '../../core/neon_theme.dart';
import '../../core/utils/object_pool.dart';
import 'pooled_component.dart';

/// Minimal Flame starter template (FEAT-14): proves `FlameGame`/`Component`/
/// `GameWidget` actually wire up end-to-end in this package — the `flame`
/// dependency existed but nothing used the game-loop engine before this.
/// Deliberately not a real game: one background color + one tappable
/// [TappableCircle]. A consumer app building a real game should extend this
/// rather than reading it as a template to copy-paste from scratch.
class RoyGame extends FlameGame {
  RoyGame({this.eventBus});

  late final TappableCircle circle;

  // FEAT-88: optional — a game that never passes one behaves exactly as
  // before (TappableCircle's null-check below is a no-op). Lets a consumer
  // bridge gameplay events (tap, defeat, combo, ...) to business-logic
  // services (EconomyWallet, AchievementService, AnalyticsProvider, ...)
  // without RoyGame itself knowing about any of them.
  final GameEventBus? eventBus;

  // ENH-81: proves ObjectPool (`core/utils/object_pool.dart`)/PooledComponent
  // (`pooled_component.dart`) actually wired into a REAL Flame component
  // lifecycle — both existed in the package with only unit-test coverage,
  // no usage a consumer could copy. Reused for every tap-triggered sparkle
  // burst instead of creating+disposing N components per tap. `maxCapacity`
  // covers several overlapping bursts (rapid taps) without unbounded growth
  // — see ObjectPool's own doc comment for the overflow policy (acquire()
  // always succeeds; release() disposes the excess instead of retaining
  // it).
  final ObjectPool<SparkleParticle> sparklePool = ObjectPool<SparkleParticle>(
    create: SparkleParticle.new,
    maxCapacity: 24,
  );

  @override
  Color backgroundColor() => NeonTheme.bgMid;

  @override
  Future<void> onLoad() async {
    // Flame's auto-created CameraComponent defaults to Anchor.center — world
    // (0,0) maps to the viewport's CENTER, not its top-left corner. This
    // template (and anything positioning components via traditional
    // top-left world coordinates, e.g. `circle.position = size / 2` below)
    // assumes world space maps 1:1 to screen pixels instead — without this,
    // `camera.localToGlobal(...)` (used by FlameTrackedOverlay, IDEA-07)
    // silently doubles any position that happens to equal size / 2.
    camera.viewfinder.anchor = Anchor.topLeft;
    circle = TappableCircle()..position = size / 2;
    add(circle);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) circle.position = size / 2;
  }

  /// Acquires [count] [SparkleParticle]s from [sparklePool], fans them out
  /// radially from [at], and adds them to the component tree. Each one
  /// returns itself to the pool automatically (via [PooledComponent])
  /// once its own lifetime ends and Flame removes it — no manual release
  /// bookkeeping needed at the call site.
  void spawnSparkleBurst(Vector2 at, {int count = 8}) {
    for (var i = 0; i < count; i++) {
      final particle = sparklePool.acquire();
      final angle = (i / count) * 2 * math.pi;
      particle
        ..reset(
          position: at,
          direction: Vector2(math.cos(angle), math.sin(angle)),
          color: NeonTheme.gemColors[i % NeonTheme.gemColors.length],
        )
        ..attachToPool(() => sparklePool.release(particle));
      add(particle);
    }
  }
}

/// One decaying particle in a tap-triggered burst (ENH-81) — shrinks and
/// fades over [_lifetimeSeconds], then removes itself; [PooledComponent]
/// then returns it to [RoyGame.sparklePool] automatically. [reset] (not the
/// constructor) sets per-spawn state, since a pooled instance is reused
/// across many bursts instead of being constructed fresh each time.
class SparkleParticle extends CircleComponent with PooledComponent {
  SparkleParticle() : super(radius: 6, anchor: Anchor.center);

  static const _lifetimeSeconds = 0.6;
  static const _speed = 120.0;

  Vector2 _direction = Vector2.zero();
  double _age = 0;

  void reset({
    required Vector2 position,
    required Vector2 direction,
    required Color color,
  }) {
    this.position = position.clone();
    _direction = direction;
    _age = 0;
    scale = Vector2.all(1);
    paint = Paint()..color = color;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    position += _direction * _speed * dt;
    final t = (_age / _lifetimeSeconds).clamp(0.0, 1.0);
    paint.color = paint.color.withValues(alpha: 1 - t);
    scale = Vector2.all(1 - t * 0.6);
    if (_age >= _lifetimeSeconds) removeFromParent();
  }
}

/// A circle that flips between two `NeonTheme` accents on tap — the single
/// piece of interactive state this starter template proves works through a
/// real `GameWidget` (see `neon_dialog.dart`'s overlay pattern doc comment,
/// which this template's demo screen also exercises).
class TappableCircle extends CircleComponent
    with TapCallbacks, HasGameReference<RoyGame> {
  TappableCircle()
    : super(
        radius: 40,
        anchor: Anchor.center,
        paint: Paint()..color = NeonTheme.cyan,
      );

  bool tapped = false;

  @override
  void onTapDown(TapDownEvent event) {
    tapped = !tapped;
    paint.color = tapped ? NeonTheme.magenta : NeonTheme.cyan;
    // ENH-81: tap trigger for the pooled sparkle burst demo.
    game.spawnSparkleBurst(position);
    // FEAT-88: bridges this Flame-world tap to any business-logic
    // subscriber (EconomyWallet, AchievementService, ...) wired up through
    // the optional GameEventBus — see GameDemoScreen for a live example.
    game.eventBus?.emit(const CircleTappedEvent());
  }
}

/// Fires whenever [TappableCircle] is tapped — the one demo [GameEvent]
/// this starter template ships, so `GameDemoScreen` has something concrete
/// to subscribe to (FEAT-88). A real game defines its own event types
/// (`EntityDefeated`, `LevelCompleted`, ...) the same way, outside this
/// package.
class CircleTappedEvent extends GameEvent {
  const CircleTappedEvent();
}

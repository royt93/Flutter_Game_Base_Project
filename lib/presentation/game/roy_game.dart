import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Color, Paint;

import '../../core/neon_theme.dart';

/// Minimal Flame starter template (FEAT-14): proves `FlameGame`/`Component`/
/// `GameWidget` actually wire up end-to-end in this package — the `flame`
/// dependency existed but nothing used the game-loop engine before this.
/// Deliberately not a real game: one background color + one tappable
/// [TappableCircle]. A consumer app building a real game should extend this
/// rather than reading it as a template to copy-paste from scratch.
class RoyGame extends FlameGame {
  late final TappableCircle circle;

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
}

/// A circle that flips between two `NeonTheme` accents on tap — the single
/// piece of interactive state this starter template proves works through a
/// real `GameWidget` (see `neon_dialog.dart`'s overlay pattern doc comment,
/// which this template's demo screen also exercises).
class TappableCircle extends CircleComponent with TapCallbacks {
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
  }
}

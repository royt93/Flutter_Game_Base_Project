import 'package:flame/camera.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flame/game.dart' show FlameGame;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Converts a Flame world-space [worldPosition] (e.g. a component's
/// `position`) into an on-screen Flutter [Offset], via [camera]'s own
/// `localToGlobal` (which already accounts for viewfinder pan/zoom and
/// viewport scaling — see `camera_component.dart` in the `flame` package).
///
/// [gameWidgetTopLeft] is the hosting `GameWidget`'s top-left corner in the
/// same coordinate space Flutter's `Positioned`/`Stack` overlays use (from
/// `renderBox.localToGlobal(Offset.zero)`).
///
/// Known limitation: this assumes `game.size` maps 1:1 to the `GameWidget`'s
/// own rendered logical size — true for a plain `GameWidget` with no custom
/// `Viewport`/aspect-ratio letterboxing (exactly [RoyGame]'s setup). A
/// consumer using a `FixedResolutionViewport` or similar would need to
/// additionally account for that scaling ratio; out of scope here.
Offset worldToScreenOffset({
  required CameraComponent camera,
  required Vector2 worldPosition,
  required Offset gameWidgetTopLeft,
}) {
  final global = camera.localToGlobal(worldPosition);
  return gameWidgetTopLeft + Offset(global.x, global.y);
}

/// Bridges a Flame [FlameGame]'s world-space entity position to a Flutter
/// widget that lives in the same `Stack` as the game's `GameWidget` — a
/// `TooltipBubble`, a damage-number `Text`, an HP-bar-style widget that
/// should visually track a moving/resizing/panning entity.
///
/// Usage: attach the SAME [GlobalKey] to your own `GameWidget` instance
/// (`GameWidget(key: sameKey, game: ...)`) and pass it as [gameWidgetKey]
/// here, plus a [worldPositionOf] callback re-read every frame. This widget
/// MUST be used as a direct child of a `Stack` (it builds a `Positioned`) —
/// the same convention as `NeonDialog.overlay`'s usage over a full-screen
/// `GameWidget` (see `example/lib/screens/game_demo_screen.dart`).
class FlameTrackedOverlay extends StatefulWidget {
  const FlameTrackedOverlay({
    super.key,
    required this.game,
    required this.gameWidgetKey,
    required this.worldPositionOf,
    required this.child,
    this.childAnchor = Alignment.center,
  });

  final FlameGame game;
  final GlobalKey gameWidgetKey;

  /// Re-read every frame — the tracked entity may move or be removed. If
  /// this throws, the overlay hides itself rather than crash.
  final Vector2 Function() worldPositionOf;

  final Widget child;

  /// Which point of [child] aligns to the computed screen position — e.g.
  /// [Alignment.bottomCenter] for a health bar that should sit just above an
  /// entity's feet.
  final Alignment childAnchor;

  @override
  State<FlameTrackedOverlay> createState() => _FlameTrackedOverlayState();
}

class _FlameTrackedOverlayState extends State<FlameTrackedOverlay>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  Offset? _screenOffset;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final next = _computeScreenOffset();
    if (next != _screenOffset && mounted) {
      setState(() => _screenOffset = next);
    } else {
      _screenOffset = next;
    }
  }

  Offset? _computeScreenOffset() {
    try {
      final renderBox =
          widget.gameWidgetKey.currentContext?.findRenderObject()
              as RenderBox?;
      if (renderBox == null || !renderBox.attached || !renderBox.hasSize) {
        return null;
      }
      final gameWidgetTopLeft = renderBox.localToGlobal(Offset.zero);
      final worldPosition = widget.worldPositionOf();
      return worldToScreenOffset(
        camera: widget.game.camera,
        worldPosition: worldPosition,
        gameWidgetTopLeft: gameWidgetTopLeft,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offset = _screenOffset;
    if (offset == null) return const SizedBox.shrink();

    final a = widget.childAnchor;
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: FractionalTranslation(
        translation: Offset(-(a.x + 1) / 2, -(a.y + 1) / 2),
        child: widget.child,
      ),
    );
  }
}

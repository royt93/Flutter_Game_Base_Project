import 'package:flame/camera.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flame/game.dart' show FlameGame;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  // FEAT-92: position updates flow through this notifier, NOT setState() —
  // see build()'s doc for why this is what makes the per-frame update
  // paint-only (no Stack layout pass) instead of rebuild-based.
  final ValueNotifier<Offset?> _offsetNotifier = ValueNotifier(null);
  bool _everResolved = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final next = _computeScreenOffset();
    if (!_everResolved) {
      if (next == null || !mounted) return;
      // The ONLY setState() this widget ever calls, and only once — the
      // first frame the tracked entity actually resolves. Every update
      // after this point goes through `_offsetNotifier` instead, so
      // build() below never runs again (Positioned's props are fixed
      // constants from here on) and the Stack this widget lives in never
      // re-lays-out this slot on a per-frame basis.
      setState(() {
        _everResolved = true;
        _offsetNotifier.value = next;
      });
      return;
    }
    // `ValueNotifier.value=` already no-ops (skips notifyListeners) when
    // the new value equals the old one, so an unchanged position still
    // triggers zero rebuild work here, same guarantee the old
    // `next != _screenOffset` check gave.
    _offsetNotifier.value = next;
  }

  Offset? _computeScreenOffset() {
    try {
      final renderBox =
          widget.gameWidgetKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.attached || !renderBox.hasSize) {
        return null;
      }
      // BUG-58: `Positioned.left/top` (set from this in `build()`) is LOCAL
      // to the enclosing `Stack`'s own RenderBox, not the screen — using
      // raw global coordinates only happened to work when that Stack sat
      // exactly at the screen origin (0,0). Convert into whatever RenderStack
      // ancestor this widget is actually inside; falls back to raw global
      // if none is found (matches the old, pre-fix behavior rather than
      // crashing — same defensive style as the null/unattached checks
      // above).
      final stackBox = context.findAncestorRenderObjectOfType<RenderStack>();
      final gameWidgetTopLeft = stackBox != null
          ? renderBox.localToGlobal(Offset.zero, ancestor: stackBox)
          : renderBox.localToGlobal(Offset.zero);
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
    _offsetNotifier.dispose();
    super.dispose();
  }

  /// FEAT-92 (zero-jank state bridge): before this, EVERY tick called
  /// `setState()` with a new `Positioned(left:, top:)` — `Positioned`'s
  /// left/top affect `Stack`'s LAYOUT algorithm, so a moving tracked
  /// entity forced a full layout pass for this slot every single frame
  /// (measurably so at N tracked overlays — see
  /// `test/widget/flame_tracked_overlay_benchmark_test.dart`).
  ///
  /// Now: [_everResolved] stays `false` (this returns [SizedBox.shrink]
  /// unchanged — same "hides silently" contract as before) until the
  /// tracked entity resolves for the first time, ONE setState() call.
  /// From then on, `Positioned`'s `left`/`top` are fixed constants
  /// (`0`/`0`) — the Stack lays out this slot exactly once, never again —
  /// and [ValueListenableBuilder] applies the REAL per-frame position via
  /// [Transform.translate], a paint-time-only property on
  /// [RenderTransform] that never triggers a layout pass. The net
  /// rendered position is identical either way (both apply the same
  /// offset in the same Stack-local coordinate space — see
  /// `_computeScreenOffset`'s BUG-58 note), just computed at paint time
  /// instead of layout time.
  @override
  Widget build(BuildContext context) {
    if (!_everResolved) return const SizedBox.shrink();

    final a = widget.childAnchor;
    return Positioned(
      left: 0,
      top: 0,
      child: ValueListenableBuilder<Offset?>(
        valueListenable: _offsetNotifier,
        builder: (context, offset, child) {
          if (offset == null) return const SizedBox.shrink();
          return Transform.translate(offset: offset, child: child);
        },
        child: FractionalTranslation(
          translation: Offset(-(a.x + 1) / 2, -(a.y + 1) / 2),
          child: widget.child,
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Gesture a [TapHintPointer] demonstrates (FEAT-131).
enum TapHintGesture { tap, swipe }

/// Pointer position along a tap/swipe hint at animation [t] (0..1).
///
/// Tap: stays at [start], bobbing [bob] logical px downward on a half sine.
/// Swipe: glides [start] -> [end] over the first 70% (eased), then rests at
/// [end] for the last 30% before the loop restarts.
Offset tapHintPointerOffsetAt({
  required TapHintGesture gesture,
  required double t,
  required Offset start,
  Offset? end,
  double bob = 8,
}) {
  final p = t.clamp(0.0, 1.0);
  if (gesture == TapHintGesture.tap) {
    return start + Offset(0, bob * math.sin(p * math.pi));
  }
  final target = end ?? start;
  final glide = Curves.easeInOut.transform((p / 0.7).clamp(0.0, 1.0));
  return Offset.lerp(start, target, glide)!;
}

/// Non-blocking animated hand that shows the player where to tap or swipe
/// (FEAT-131). Complements `SpotlightOverlay`/`TutorialSequence`, which dim
/// and explain but do not demonstrate the gesture.
///
/// Locate the hint with exactly one of [targetKey] (center of an already
/// laid-out widget, same model as `SpotlightOverlay`) or [position] (a
/// global-coordinate point, e.g. a cell inside a Flame game). For
/// [TapHintGesture.swipe], [swipeTo] is the global end point.
///
/// Mount it inside a `Stack` that covers the same area as the screen (a
/// `Positioned.fill` sibling, like `SpotlightOverlay`). It never intercepts
/// touches. The caller owns [visible]; Reduce Motion shows a static pointer.
class TapHintPointer extends StatefulWidget {
  TapHintPointer({
    super.key,
    this.targetKey,
    this.position,
    this.gesture = TapHintGesture.tap,
    this.swipeTo,
    this.visible = true,
    this.color,
    this.size = 48,
  }) {
    if ((targetKey == null) == (position == null)) {
      throw ArgumentError(
        'Provide exactly one of targetKey or position (got '
        '${targetKey == null ? 'neither' : 'both'}).',
      );
    }
    if (gesture == TapHintGesture.swipe && swipeTo == null) {
      throw ArgumentError.value(swipeTo, 'swipeTo', 'required for swipe');
    }
    if (gesture == TapHintGesture.tap && swipeTo != null) {
      throw ArgumentError.value(swipeTo, 'swipeTo', 'only valid for swipe');
    }
    if (!size.isFinite || size <= 0) {
      throw ArgumentError.value(size, 'size', 'must be finite and positive');
    }
  }

  final GlobalKey? targetKey;
  final Offset? position;
  final TapHintGesture gesture;
  final Offset? swipeTo;
  final bool visible;
  final Color? color;
  final double size;

  @override
  State<TapHintPointer> createState() => _TapHintPointerState();
}

class _TapHintPointerState extends State<TapHintPointer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    // targetKey's RenderBox is not laid out during the first build; rebuild
    // once after the first frame to pick up its real position.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant TapHintPointer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final run = widget.visible && !NeonTheme.reducedMotion(context);
    if (run && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!run && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset? _globalStart() {
    final key = widget.targetKey;
    if (key == null) return widget.position;
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final globalStart = _globalStart();
    if (globalStart == null) return const SizedBox.shrink();

    final self = context.findRenderObject();
    Offset toLocal(Offset global) =>
        self is RenderBox && self.attached && self.hasSize
        ? self.globalToLocal(global)
        : global;
    final start = toLocal(globalStart);
    final end = widget.swipeTo == null ? null : toLocal(widget.swipeTo!);
    final color = widget.color ?? NeonTheme.gold;
    final reduced = NeonTheme.reducedMotion(context);

    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = reduced ? 0.0 : _controller.value;
              final at = tapHintPointerOffsetAt(
                gesture: widget.gesture,
                t: t,
                start: start,
                end: end,
              );
              final ripple = reduced ? 0.6 : Curves.easeOut.transform(t);
              final rippleSize = widget.size * (0.6 + 0.9 * ripple);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  PositionedDirectional(
                    start: start.dx - rippleSize / 2,
                    top: start.dy - rippleSize / 2,
                    child: Container(
                      key: const ValueKey('tapHintRipple'),
                      width: rippleSize,
                      height: rippleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withValues(alpha: 0.7 * (1 - ripple)),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: at.dx - widget.size * 0.25,
                    top: at.dy - widget.size * 0.1,
                    child: Icon(
                      Icons.touch_app_rounded,
                      key: const ValueKey('tapHintHand'),
                      size: widget.size,
                      color: color,
                      shadows: [
                        Shadow(
                          color: NeonTheme.ink.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

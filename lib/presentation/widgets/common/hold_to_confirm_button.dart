import 'package:flutter/material.dart';

import '../../../core/haptic_choreographer.dart';
import '../../../core/haptics.dart';
import '../../../core/neon_theme.dart';
import '../stroke_text.dart';

/// Visual style of the fill-progress indicator while [HoldToConfirmButton]
/// is being held. `radial` draws a ring around a circular icon button (the
/// classic "hold to delete" shape); `linear` fills a pill from the left,
/// like [CommonButton]'s shape.
enum HoldToConfirmShape { radial, linear }

/// A button that only fires [onConfirm] after being held down for
/// [duration] — for a reset/delete/purchase action a stray tap shouldn't be
/// able to trigger.
///
/// State machine lives entirely on raw pointer events (a [Listener], not a
/// [GestureDetector]) so it can track exactly one active pointer: a second
/// pointer touching down while one is already held is ignored outright,
/// rather than interfering with (or restarting) the in-progress hold.
/// Releasing early or dragging outside the button's own bounds both cancel
/// the same way — the fill animates back to empty via [resetCurve] instead
/// of snapping, so a player can see the cancel happen.
///
/// [duration] is the actual safety mechanism, not decoration — unlike this
/// kit's usual `NeonTheme.reducedMotion` convention of collapsing an
/// animation's duration to zero, reduced motion here only affects how the
/// progress fill is *drawn* (nothing currently needs to change about that
/// rendering), never how long a hold must last. Shortening it under
/// reduced motion would defeat the whole point of a hold-to-confirm gate.
///
/// Screen-reader/switch-access users can't perform a timed hold gesture at
/// all, so this widget's [Semantics] exposes a plain `tap` action that
/// calls [onConfirm] immediately — the standard accessibility trade-off for
/// a hold/drag-only interaction (see WCAG's guidance against motion-only
/// activation). It fires through the same [onConfirm] reference exactly
/// once per accessibility tap, independent of the pointer-driven path.
class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    super.key,
    required this.label,
    required this.onConfirm,
    this.duration = const Duration(milliseconds: 900),
    this.shape = HoldToConfirmShape.radial,
    this.resetCurve = Curves.easeOut,
    this.color,
    this.width,
    this.enabled = true,
    this.semanticLabel,
    this.startHaptic = HapticLevel.light,
    this.confirmHaptic = HapticLevel.heavy,
    HapticChoreographer? choreographer,
  }) : _choreographer = choreographer;

  final String label;
  final VoidCallback onConfirm;
  final Duration duration;
  final HoldToConfirmShape shape;
  final Curve resetCurve;
  final Color? color;
  final double? width;
  final bool enabled;
  final String? semanticLabel;

  /// Fired once when a hold starts / once it reaches [duration]. Either can
  /// be set `null` to skip that milestone's haptic ("haptic milestones
  /// optional").
  final HapticLevel? startHaptic;
  final HapticLevel? confirmHaptic;

  final HapticChoreographer? _choreographer;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..addStatusListener(_onStatusChanged);
  late final HapticChoreographer _choreographer =
      widget._choreographer ?? HapticChoreographer();

  int? _activePointer;
  bool _firedThisHold = false;

  void _onStatusChanged(AnimationStatus status) {
    // `animateTo(0)` (a cancel) also reports AnimationStatus.completed once
    // it reaches ITS target — completed alone doesn't mean "reached 1.0",
    // so this must also check the value, or cancelling would confirm.
    if (status == AnimationStatus.completed &&
        _controller.value >= 1.0 &&
        !_firedThisHold) {
      _firedThisHold = true;
      final level = widget.confirmHaptic;
      if (level != null) {
        _choreographer.play(HapticPattern([HapticPulse(level: level)]));
      }
      widget.onConfirm();
    }
  }

  bool _containsGlobal(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return false;
    final local = box.globalToLocal(globalPosition);
    return (Offset.zero & box.size).contains(local);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled || _activePointer != null) return;
    _activePointer = event.pointer;
    _firedThisHold = false;
    final level = widget.startHaptic;
    if (level != null) {
      _choreographer.play(HapticPattern([HapticPulse(level: level)]));
    }
    _controller.forward(from: 0);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    if (!_containsGlobal(event.position)) {
      _cancelHold();
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    if (_controller.status != AnimationStatus.completed) {
      _cancelHold();
    } else {
      _activePointer = null;
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _cancelHold();
  }

  void _cancelHold() {
    _activePointer = null;
    _controller.animateTo(0, curve: widget.resetCurve);
  }

  void _confirmViaAccessibility() {
    if (!widget.enabled || _firedThisHold) return;
    _firedThisHold = true;
    final level = widget.confirmHaptic;
    if (level != null) {
      _choreographer.play(HapticPattern([HapticPulse(level: level)]));
    }
    widget.onConfirm();
  }

  // BUG-73: without this, changing `widget.duration` on the same mounted
  // instance (e.g. an accessibility "hold longer" setting) was silently
  // ignored — the hold-to-confirm safety gate kept using whichever
  // duration was live at first mount.
  @override
  void didUpdateWidget(covariant HoldToConfirmButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.enabled
        ? (widget.color ?? NeonTheme.red)
        : NeonTheme.muted;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel ?? widget.label,
      onTap: widget.enabled ? _confirmViaAccessibility : null,
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return widget.shape == HoldToConfirmShape.radial
                ? _buildRadial(c)
                : _buildLinear(c);
          },
        ),
      ),
    );
  }

  Widget _buildRadial(Color c) {
    final d = widget.width ?? 72.0;
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: NeonTheme.cardAlt,
              shape: BoxShape.circle,
              border: Border.all(color: c, width: 3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: CircularProgressIndicator(
              value: _controller.value,
              strokeWidth: 4,
              color: c,
              backgroundColor: Colors.transparent,
            ),
          ),
          Icon(Icons.delete_outline, color: c, size: d * 0.4),
        ],
      ),
    );
  }

  Widget _buildLinear(Color c) {
    final w = widget.width ?? 240.0;
    return Container(
      width: w,
      height: 52,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: NeonTheme.cardAlt,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c, width: 3),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _controller.value.clamp(0, 1),
            child: Container(color: c.withValues(alpha: 0.35)),
          ),
          StrokeText(widget.label, color: c, fontSize: 17),
        ],
      ),
    );
  }
}

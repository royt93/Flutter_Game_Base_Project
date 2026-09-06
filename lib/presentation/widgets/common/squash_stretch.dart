import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../core/neon_theme.dart';

/// Non-uniform "squash" wrapper (IDEA-08) — unlike [PressableScale]'s
/// uniform scale-down, this squishes horizontally (scaleX up, scaleY down)
/// on tap-down, then a real [SpringSimulation] (not a fixed `Curve`) bounces
/// it back to `(1.0, 1.0)` on release, carrying over whatever velocity the
/// spring already had (so a quick re-tap doesn't reset to a dead stop).
class SquashStretch extends StatefulWidget {
  const SquashStretch({
    super.key,
    required this.child,
    this.onTap,
    this.stretchScale = 1.15,
    this.squashScale = 0.85,
    this.stiffness = 400,
    this.damping = 20,
    this.mass = 1,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// scaleX at maximum squash (tap-down).
  final double stretchScale;

  /// scaleY at maximum squash (tap-down).
  final double squashScale;

  final double stiffness;
  final double damping;
  final double mass;

  @override
  State<SquashStretch> createState() => _SquashStretchState();
}

class _SquashStretchState extends State<SquashStretch>
    with SingleTickerProviderStateMixin {
  // 0.0 = rest (1,1), 1.0 = fully squashed. Driven by SpringSimulation, not
  // a fixed-duration Tween — that's what actually gives a settle/overshoot
  // feel instead of a merely-eased fixed animation.
  late final AnimationController _controller = AnimationController(vsync: this);

  bool _reducedMotion = false;
  bool _startedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery can't be read in initState — see pressable_scale.dart /
    // star_rating.dart for the same didChangeDependencies+guard pattern.
    if (_startedOnce) return;
    _startedOnce = true;
    _reducedMotion = NeonTheme.reducedMotion(context);
  }

  void _springTo(double target) {
    if (_reducedMotion) return;
    final spring = SpringDescription(
      mass: widget.mass,
      stiffness: widget.stiffness,
      damping: widget.damping,
    );
    final sim = SpringSimulation(
      spring,
      _controller.value,
      target,
      _controller.velocity,
    );
    // whenCompleteOrCancel (not .then) so an interrupting dispose — which
    // cancels the driving ticker — resolves quietly instead of throwing.
    _controller.animateWith(sim).whenCompleteOrCancel(() {
      // Snap exactly to target: SpringSimulation.isDone() only guarantees
      // being within tolerance, not bang-on — tests (and callers) expect
      // the settled state to read exactly 1.0, not 0.9997.
      if (mounted) _controller.value = target;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => _springTo(1.0) : null,
      onTapCancel: enabled ? () => _springTo(0.0) : null,
      onTapUp: enabled ? (_) => _springTo(0.0) : null,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final sx = 1.0 + (widget.stretchScale - 1.0) * t;
          final sy = 1.0 + (widget.squashScale - 1.0) * t;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(sx, sy, 1.0),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

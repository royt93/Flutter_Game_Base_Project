import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/neon_theme.dart';

/// Per-screen/per-widget-tree shake controller (IDEA-08) — a plain
/// `ChangeNotifier` the caller creates and owns (like a `TextEditingController`),
/// not a global `GetxService` singleton, since screen-shake state is local to
/// whatever's shaking (a board, a card, a whole screen), not app-wide.
///
/// [offsetAt] is a pure, testable seam (mirrors `FrameBudgetTracker` in
/// `performance_tier_service.dart`): given elapsed time since the last
/// [shake] call, it returns the current decaying-sine displacement with no
/// dependency on a live clock/ticker — [ScreenShake] (the widget below) is
/// what actually drives it off a real `Ticker`.
class ScreenShakeController extends ChangeNotifier {
  double _intensity = 0;
  double _frequency = 0;
  Duration _decay = Duration.zero;
  Offset? _direction;

  /// Starts (or restarts, discarding any shake already in progress) a
  /// decaying oscillation. [intensity] is the max displacement in logical
  /// pixels, [frequency] in Hz, [decay] how long until it fully settles to
  /// [Offset.zero].
  ///
  /// [direction] (IDEA-60) optionally biases the shake toward a collision
  /// vector — e.g. a Flame collision callback's own separation/normal
  /// vector, passed straight through as an [Offset] (this widget has zero
  /// Flame dependency today and stays that way; a `Vector2` from
  /// `package:flame`/`vector_math` converts trivially via
  /// `Offset(v.x, v.y)`, no new import needed here). Left `null` (the
  /// default), the shake keeps its original symmetric elliptical trace —
  /// see [offsetAt] for exactly how the bias is computed.
  void shake({
    double intensity = 12,
    double frequency = 30,
    Duration decay = const Duration(milliseconds: 400),
    Offset? direction,
  }) {
    _intensity = intensity;
    _frequency = frequency;
    _decay = decay;
    _direction = (direction != null && direction.distance > 0)
        ? direction / direction.distance
        : null;
    notifyListeners();
  }

  /// Displacement at [elapsed] time since the most recent [shake] call.
  /// Exactly [Offset.zero] before any shake has ever been triggered, and
  /// again once [elapsed] reaches [_decay] (clamped, not asymptotic) — a
  /// live-driven [ScreenShake] uses this to know when it can stop ticking.
  ///
  /// No [direction] given to [shake] (the default): `primary` uses sin,
  /// `secondary` uses cos at a different phase, mapped straight onto x/y —
  /// this traces a symmetric ellipse, not a straight diagonal line, and is
  /// byte-for-byte the same formula this method always used (IDEA-60 never
  /// changes this path).
  ///
  /// With a [direction]: the SAME `primary` oscillation now runs fully
  /// ALONG that (unit) vector, and `secondary` runs perpendicular to it —
  /// scaled down by [_perpendicularFactor] — so the shake's peak
  /// displacement is visibly biased along the collision direction instead
  /// of tracing a shape-agnostic ellipse.
  Offset offsetAt(Duration elapsed) {
    if (elapsed <= Duration.zero) elapsed = Duration.zero;
    if (_decay <= Duration.zero || elapsed >= _decay) return Offset.zero;

    final t = elapsed.inMicroseconds / 1e6;
    final decaySeconds = _decay.inMicroseconds / 1e6;
    // ponytail: naive exponential envelope tuned so it's ~e^-4 (~1.8% of
    // intensity) by the end of `decay`, not a physically modeled impulse
    // response — good enough for a juice effect, revisit if a designer
    // wants a different "feel" curve.
    final envelope = math.exp(-4 * t / decaySeconds);
    final primary =
        _intensity * envelope * math.sin(2 * math.pi * _frequency * t);
    final secondary =
        _intensity * envelope * math.cos(2 * math.pi * _frequency * 1.3 * t);

    final dir = _direction;
    if (dir == null) return Offset(primary, secondary);

    final perpendicular = Offset(-dir.dy, dir.dx);
    return dir * primary + perpendicular * (secondary * _perpendicularFactor);
  }

  /// How much weaker the perpendicular wobble is relative to the primary,
  /// directed oscillation — 0 would collapse the shake to a straight line
  /// (no ellipse "give" at all, too mechanical), 1 would be no bias at all
  /// (identical peak in every direction, defeating the point). 0.35 keeps
  /// a visible ellipse while still reading as clearly directional.
  static const double _perpendicularFactor = 0.35;
}

/// Wraps [child] in a `Transform.translate` driven by [controller]. Ticks a
/// `Ticker` only while a shake is actually decaying (stops once
/// `controller.offsetAt(...)` returns [Offset.zero], not left running
/// forever). Respects [NeonTheme.reducedMotion] — when on, renders [child]
/// unchanged regardless of what [controller] does, same as the decorative
/// shader layers (`ShaderTickerLayerState`).
class ScreenShake extends StatefulWidget {
  const ScreenShake({super.key, required this.controller, required this.child});

  final ScreenShakeController controller;
  final Widget child;

  @override
  State<ScreenShake> createState() => _ScreenShakeState();
}

class _ScreenShakeState extends State<ScreenShake>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  Duration _rawElapsed = Duration.zero;
  Duration _shakeStart = Duration.zero;
  Offset _offset = Offset.zero;

  bool _reducedMotion = false;
  bool _startedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedOnce) return;
    _startedOnce = true;
    _reducedMotion = NeonTheme.reducedMotion(context);
    if (!_reducedMotion) widget.controller.addListener(_onShake);
  }

  @override
  void didUpdateWidget(covariant ScreenShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_reducedMotion && oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onShake);
      widget.controller.addListener(_onShake);
    }
  }

  void _onShake() {
    _shakeStart = _rawElapsed;
    _ticker ??= createTicker(_onTick);
    if (!_ticker!.isTicking) _ticker!.start();
  }

  void _onTick(Duration elapsed) {
    _rawElapsed = elapsed;
    final offset = widget.controller.offsetAt(elapsed - _shakeStart);
    if (mounted) setState(() => _offset = offset);
    if (offset == Offset.zero) _ticker?.stop();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onShake);
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reducedMotion) return widget.child;
    return Transform.translate(offset: _offset, child: widget.child);
  }
}

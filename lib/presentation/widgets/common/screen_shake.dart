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

  /// Starts (or restarts, discarding any shake already in progress) a
  /// decaying oscillation. [intensity] is the max displacement in logical
  /// pixels, [frequency] in Hz, [decay] how long until it fully settles to
  /// [Offset.zero].
  void shake({
    double intensity = 12,
    double frequency = 30,
    Duration decay = const Duration(milliseconds: 400),
  }) {
    _intensity = intensity;
    _frequency = frequency;
    _decay = decay;
    notifyListeners();
  }

  /// Displacement at [elapsed] time since the most recent [shake] call.
  /// Exactly [Offset.zero] before any shake has ever been triggered, and
  /// again once [elapsed] reaches [_decay] (clamped, not asymptotic) — a
  /// live-driven [ScreenShake] uses this to know when it can stop ticking.
  ///
  /// dx uses sin, dy uses cos (a different phase) so the shake traces an
  /// ellipse rather than a perfectly straight diagonal line.
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
    final dx = _intensity * envelope * math.sin(2 * math.pi * _frequency * t);
    final dy =
        _intensity * envelope * math.cos(2 * math.pi * _frequency * 1.3 * t);
    return Offset(dx, dy);
  }
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

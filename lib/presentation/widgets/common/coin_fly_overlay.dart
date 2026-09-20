import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Position along a quadratic Bézier arc from [from] to [to] at progress
/// [t] (0..1) — IDEA-22, replaces a straight-line `Offset.lerp` so a coin
/// visibly arcs up then down instead of sliding on a dead-straight line.
/// The control point sits above the midpoint by [arcHeight] pixels. Pure
/// function (no widget involved) so the curve shape is unit-testable on
/// its own.
Offset coinArcOffsetAt(
  Offset from,
  Offset to,
  double t, {
  required double arcHeight,
}) {
  final control = Offset.lerp(from, to, 0.5)! - Offset(0, arcHeight);
  final u = 1 - t;
  return Offset(
    u * u * from.dx + 2 * u * t * control.dx + t * t * to.dx,
    u * u * from.dy + 2 * u * t * control.dy + t * t * to.dy,
  );
}

/// Scale at progress [t] (0..1): pops up to 1.2x over the first half of the
/// flight, then eases down to a 0.9x "squash" by the time it lands —
/// IDEA-22, replaces a constant 1.0 scale for the whole flight.
double coinScaleAt(double t) {
  double lerp(double a, double b, double x) => a + (b - a) * x;
  if (t <= 0.5) {
    return lerp(1.0, 1.2, Curves.easeOut.transform(t / 0.5));
  }
  return lerp(1.2, 0.9, Curves.easeIn.transform((t - 0.5) / 0.5));
}

/// N icon "coins" fly from a source point to a target's current on-screen
/// position — read from a [GlobalKey] via `RenderBox.localToGlobal`, the
/// same technique used elsewhere in Flutter for this — staggered slightly
/// so they read as individual coins instead of one blob. FEAT-12's
/// "coin fly to `CurrencyCounter`" reward juice.
///
/// Design note on [onArrive]: this widget doesn't know what a "coin" is
/// worth — it just fires [onArrive] once **per coin**, [coinCount] times
/// total. The caller decides the value split, e.g. bump a `CurrencyCounter`
/// by `totalAmount ~/ coinCount` on every call, so the running total lands
/// exactly on `totalAmount` once the last coin arrives.
///
/// Implementation note: all coins share a *single* `AnimationController`
/// (duration = [duration] + [stagger] * (coinCount - 1)) instead of one
/// controller per coin — each coin just occupies its own `[start, start +
/// duration]` sub-window of that one timeline. One controller/ticker total,
/// no per-coin `Future.delayed` timers to leak or cancel.
///
/// Same self-cleaning static-entry-point convention as
/// `FloatingComboText.show`/`ToastBanner.show`: call [CoinFlyOverlay.show]
/// once, no ambient state to manage — it inserts into the root [Overlay]
/// and removes itself once the last coin lands.
class CoinFlyOverlay extends StatefulWidget {
  const CoinFlyOverlay({
    super.key,
    required this.from,
    required this.to,
    this.coinCount = 5,
    this.icon = Icons.monetization_on,
    this.color,
    this.coinSize = 22,
    this.duration = const Duration(milliseconds: 550),
    this.stagger = const Duration(milliseconds: 70),
    this.onArrive,
    this.onDone,
  }) : assert(coinCount > 0, 'coinCount must be > 0');

  /// Source point, in the [Overlay]'s coordinate space (global).
  final Offset from;

  /// Target point, in the [Overlay]'s coordinate space (global) — usually
  /// the center of a `GlobalKey`'s render box, see [show].
  final Offset to;

  /// How many coin icons fly.
  final int coinCount;
  final IconData icon;
  final Color? color;
  final double coinSize;

  /// How long a single coin's own flight takes.
  final Duration duration;

  /// Delay between one coin starting and the next.
  final Duration stagger;

  /// Called once per coin, when that coin's flight completes — fires
  /// [coinCount] times total.
  final VoidCallback? onArrive;

  /// Called once, right after the last coin arrives, just before the
  /// overlay removes/hides itself.
  final VoidCallback? onDone;

  @override
  State<CoinFlyOverlay> createState() => _CoinFlyOverlayState();

  /// Reads [targetKey]'s current on-screen center and inserts a
  /// self-removing [CoinFlyOverlay] into [context]'s root [Overlay], flying
  /// [coinCount] coins from [from] to it. No-ops if [targetKey] isn't
  /// currently attached to a render object (e.g. its widget isn't on
  /// screen) or if [coinCount] is not positive.
  static void show(
    BuildContext context, {
    required Offset from,
    required GlobalKey targetKey,
    int coinCount = 5,
    IconData icon = Icons.monetization_on,
    Color? color,
    double coinSize = 22,
    Duration duration = const Duration(milliseconds: 550),
    Duration stagger = const Duration(milliseconds: 70),
    VoidCallback? onArrive,
  }) {
    if (coinCount <= 0) return;
    final box = targetKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final to = box.localToGlobal(box.size.center(Offset.zero));

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => CoinFlyOverlay(
        from: from,
        to: to,
        coinCount: coinCount,
        icon: icon,
        color: color,
        coinSize: coinSize,
        duration: duration,
        stagger: stagger,
        onArrive: onArrive,
        // BUG-32: a bare tear-off crashes (AssertionError: "An OverlayEntry
        // should be removed only once") if something else already removed
        // this entry while the coins were still in flight — same guard
        // FloatingComboText.show already uses.
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _CoinFlyOverlayState extends State<CoinFlyOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Fraction of the *shared* timeline (0..1) at which coin i starts/ends.
  late final List<double> _startAt;
  late final List<double> _endAt;
  late final List<bool> _arrived;
  bool _done = false;
  bool _startedOnce = false;
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery can't be read in initState — didChangeDependencies is the
    // earliest safe place, and runs once before the first build. Reduce
    // Motion collapses the whole shared timeline to zero: the controller
    // jumps straight to its end value, every coin's [start, end] window
    // collapses to [0, 1] (see the `totalUs <= 0` branches below), so
    // onArrive/onDone fire immediately without a mid-flight frame — the
    // same effect as "skip the burst entirely", reusing the existing
    // zero-duration machinery instead of a separate code path.
    if (_startedOnce) return;
    _startedOnce = true;
    final reduced = NeonTheme.reducedMotion(context);
    _reducedMotion = reduced;
    final totalUs = reduced
        ? 0
        : widget.duration.inMicroseconds +
              widget.stagger.inMicroseconds * (widget.coinCount - 1);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(microseconds: totalUs < 0 ? 0 : totalUs),
    );
    _startAt = List.generate(widget.coinCount, (i) {
      if (totalUs <= 0) return 0.0;
      return (widget.stagger.inMicroseconds * i) / totalUs;
    });
    _endAt = List.generate(widget.coinCount, (i) {
      if (totalUs <= 0) return 1.0;
      final endUs =
          widget.stagger.inMicroseconds * i + widget.duration.inMicroseconds;
      return (endUs / totalUs).clamp(0.0, 1.0);
    });
    _arrived = List.filled(widget.coinCount, false);
    _controller
      ..addListener(_checkArrivals)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_done) {
          _done = true;
          widget.onDone?.call();
        }
      })
      ..forward();
  }

  void _checkArrivals() {
    for (var i = 0; i < widget.coinCount; i++) {
      if (!_arrived[i] && _controller.value >= _endAt[i]) {
        _arrived[i] = true;
        widget.onArrive?.call();
      }
    }
  }

  /// This coin's own progress (0..1) within its `[start, end]` sub-window
  /// of the shared timeline.
  double _coinProgress(int i) {
    final v = _controller.value;
    final start = _startAt[i];
    final end = _endAt[i];
    if (v <= start) return 0;
    if (v >= end || end <= start) return 1;
    return (v - start) / (end - start);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? NeonTheme.gold;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Stack(
          children: [
            for (var i = 0; i < widget.coinCount; i++)
              Builder(
                builder: (context) {
                  // BUG-32: without this, a coin not yet at its turn sits
                  // drawn at `from` (every not-yet-started coin stacked
                  // there), and a coin that already arrived stays drawn at
                  // `to` for the rest of the shared timeline (every already-
                  // arrived coin stacked there) — only render it during its
                  // own `[startAt, endAt]` window.
                  final v = _controller.value;
                  if (v < _startAt[i] || v > _endAt[i]) {
                    return const SizedBox.shrink();
                  }
                  final t = Curves.easeInOut.transform(_coinProgress(i));
                  final pos = _reducedMotion
                      ? Offset.lerp(widget.from, widget.to, t)!
                      : coinArcOffsetAt(
                          widget.from,
                          widget.to,
                          t,
                          arcHeight: (widget.to - widget.from).distance * 0.3,
                        );
                  final scale = _reducedMotion ? 1.0 : coinScaleAt(t);
                  return Positioned(
                    left: pos.dx - widget.coinSize / 2,
                    top: pos.dy - widget.coinSize / 2,
                    child: Transform.scale(
                      scale: scale,
                      child: Icon(
                        widget.icon,
                        color: color,
                        size: widget.coinSize,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

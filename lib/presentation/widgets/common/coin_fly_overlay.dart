import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

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
        onDone: entry.remove,
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

  @override
  void initState() {
    super.initState();
    final totalUs =
        widget.duration.inMicroseconds +
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
      final endUs = widget.stagger.inMicroseconds * i + widget.duration.inMicroseconds;
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
                  final t = Curves.easeInOut.transform(_coinProgress(i));
                  final pos = Offset.lerp(widget.from, widget.to, t)!;
                  return Positioned(
                    left: pos.dx - widget.coinSize / 2,
                    top: pos.dy - widget.coinSize / 2,
                    child: Icon(
                      widget.icon,
                      color: color,
                      size: widget.coinSize,
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

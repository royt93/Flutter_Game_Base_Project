import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

Offset itemArcOffsetAt(
  Offset from,
  Offset to,
  double t, {
  Offset curveOffset = const Offset(0, -60),
}) {
  final control = Offset.lerp(from, to, 0.5)! + curveOffset;
  final u = 1 - t;
  return from * (u * u) + control * (2 * u * t) + to * (t * t);
}

double itemScaleAt(double t) {
  if (t <= 0.5) return 1 + 0.25 * Curves.easeOut.transform(t * 2);
  return 1.25 - 0.35 * Curves.easeIn.transform((t - 0.5) * 2);
}

class ItemFlyOverlay extends StatefulWidget {
  ItemFlyOverlay({
    super.key,
    required this.from,
    required this.to,
    this.itemCount = 5,
    this.itemBuilder,
    this.item,
    this.icon,
    this.color,
    this.itemSize = 32,
    this.flightDuration = const Duration(milliseconds: 500),
    this.stagger = const Duration(milliseconds: 60),
    this.curveOffset = const Offset(0, -60),
    this.onItemArrive,
    this.onDone,
  }) {
    if (itemCount < 1 || itemCount > 20) {
      throw ArgumentError.value(
        itemCount,
        'itemCount',
        'must be between 1 and 20',
      );
    }
    if (flightDuration <= Duration.zero) {
      throw ArgumentError.value(
        flightDuration,
        'flightDuration',
        'must be positive',
      );
    }
    if (stagger < Duration.zero) {
      throw ArgumentError.value(stagger, 'stagger', 'must not be negative');
    }
    if (!itemSize.isFinite || itemSize <= 0) {
      throw ArgumentError.value(
        itemSize,
        'itemSize',
        'must be finite and positive',
      );
    }
    for (final entry in {
      'from': from,
      'to': to,
      'curveOffset': curveOffset,
    }.entries) {
      if (!entry.value.dx.isFinite || !entry.value.dy.isFinite) {
        throw ArgumentError.value(entry.value, entry.key, 'must be finite');
      }
    }
  }

  final Offset from;
  final Offset to;
  final int itemCount;
  final Widget Function(BuildContext context, int index)? itemBuilder;
  final Widget? item;
  final IconData? icon;
  final Color? color;
  final double itemSize;
  final Duration flightDuration;
  final Duration stagger;
  final Offset curveOffset;
  final ValueChanged<int>? onItemArrive;
  final VoidCallback? onDone;

  @override
  State<ItemFlyOverlay> createState() => _ItemFlyOverlayState();

  /// Direct offsets are global; unattached keys do not launch a flight.
  static void show(
    BuildContext context, {
    Offset? from,
    GlobalKey? fromKey,
    Offset? to,
    GlobalKey? toKey,
    int itemCount = 5,
    Widget Function(BuildContext context, int index)? itemBuilder,
    Widget? item,
    IconData? icon,
    Color? color,
    double itemSize = 32,
    Duration flightDuration = const Duration(milliseconds: 500),
    Duration stagger = const Duration(milliseconds: 60),
    Offset curveOffset = const Offset(0, -60),
    ValueChanged<int>? onItemArrive,
    VoidCallback? onDone,
  }) {
    if (from == null && fromKey == null) {
      throw ArgumentError('from or fromKey is required');
    }
    if (to == null && toKey == null) {
      throw ArgumentError('to or toKey is required');
    }
    Offset? center(Offset? direct, GlobalKey? key) {
      if (direct != null) return direct;
      final box = key?.currentContext?.findRenderObject();
      return box is RenderBox && box.attached && box.hasSize
          ? box.localToGlobal(box.size.center(Offset.zero))
          : null;
    }

    final source = center(from, fromKey);
    final target = center(to, toKey);
    if (source == null || target == null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final box = overlay.context.findRenderObject()! as RenderBox;
    late OverlayEntry entry;
    final flight = ItemFlyOverlay(
      from: box.globalToLocal(source),
      to: box.globalToLocal(target),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      item: item,
      icon: icon,
      color: color,
      itemSize: itemSize,
      flightDuration: flightDuration,
      stagger: stagger,
      curveOffset: curveOffset,
      onItemArrive: onItemArrive,
      onDone: () {
        if (entry.mounted) entry.remove();
        entry.dispose();
        onDone?.call();
      },
    );
    entry = OverlayEntry(builder: (_) => Positioned.fill(child: flight));
    overlay.insert(entry);
  }
}

class _ItemFlyOverlayState extends State<ItemFlyOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addListener(_tick);
  late List<bool> _arrived;
  var _generation = 0;
  var _done = false;
  var _reduced = false;
  var _startScheduled = false;
  var _started = false;

  int get _totalUs =>
      widget.flightDuration.inMicroseconds +
      widget.stagger.inMicroseconds * (widget.itemCount - 1);

  @override
  void initState() {
    super.initState();
    _arrived = List.filled(widget.itemCount, false);
    _controller.duration = Duration(microseconds: _totalUs);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = NeonTheme.reducedMotion(context);
    _reduced = reduced;
    if (!_done && !_started && !_startScheduled) _scheduleStart();
    if (reduced && !_done) _scheduleFinish();
  }

  @override
  void didUpdateWidget(covariant ItemFlyOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.from != widget.from ||
        oldWidget.to != widget.to ||
        oldWidget.itemCount != widget.itemCount ||
        oldWidget.flightDuration != widget.flightDuration ||
        oldWidget.stagger != widget.stagger) {
      _generation++;
      _controller.stop();
      _controller.value = 0;
      _arrived = List.filled(widget.itemCount, false);
      _done = false;
      _started = false;
      _startScheduled = false;
      _controller.duration = Duration(microseconds: _totalUs);
      _scheduleStart();
    }
  }

  void _scheduleStart() {
    if (_startScheduled || _started || _done) return;
    _startScheduled = true;
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScheduled = false;
      if (!mounted || generation != _generation || _done || _started) return;
      if (_reduced) {
        _finish();
      } else {
        _started = true;
        _controller.forward();
      }
    });
  }

  void _scheduleFinish() {
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation && !_done) _finish();
    });
  }

  void _tick() {
    if (_done) return;
    for (var i = 0; i < _arrived.length; i++) {
      final end =
          (widget.stagger.inMicroseconds * i +
              widget.flightDuration.inMicroseconds) /
          _totalUs;
      if (!_arrived[i] && _controller.value >= end) {
        _arrived[i] = true;
        widget.onItemArrive?.call(i);
      }
    }
    if (_controller.value == 1) _scheduleFinish();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _controller.stop();
    for (var i = 0; i < _arrived.length; i++) {
      if (!_arrived[i]) {
        _arrived[i] = true;
        widget.onItemArrive?.call(i);
      }
    }
    setState(() {});
    widget.onDone?.call();
  }

  @override
  void dispose() {
    _generation++;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done || _reduced) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Stack(
          children: [
            for (var i = 0; i < widget.itemCount; i++)
              PositionedDirectional(
                start: 0,
                top: 0,
                child: AnimatedBuilder(
                  animation: _controller,
                  child: RepaintBoundary(
                    child: SizedBox.square(
                      dimension: widget.itemSize,
                      child: Center(
                        child:
                            widget.itemBuilder?.call(context, i) ??
                            widget.item ??
                            Icon(
                              widget.icon ?? Icons.card_giftcard,
                              color: widget.color ?? NeonTheme.purple,
                              size: widget.itemSize,
                            ),
                      ),
                    ),
                  ),
                  builder: (context, child) {
                    final elapsed =
                        _controller.value * _totalUs -
                        widget.stagger.inMicroseconds * i;
                    if (elapsed < 0 ||
                        elapsed >= widget.flightDuration.inMicroseconds) {
                      return const SizedBox.shrink();
                    }
                    final t = NeonTheme.curveSmooth.transform(
                      elapsed / widget.flightDuration.inMicroseconds,
                    );
                    final pos = itemArcOffsetAt(
                      widget.from,
                      widget.to,
                      t,
                      curveOffset: widget.curveOffset,
                    );
                    return Transform.translate(
                      offset:
                          pos -
                          Offset(widget.itemSize / 2, widget.itemSize / 2),
                      child: Transform.scale(
                        scale: itemScaleAt(t),
                        child: child,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

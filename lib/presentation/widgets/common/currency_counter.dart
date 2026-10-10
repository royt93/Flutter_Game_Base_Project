import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/utils/format.dart';

/// Icon + a currency amount, smoothly counting up/down when [value] changes
/// (instead of jumping instantly) — a generic replacement for the old
/// `CoinChip` (removed because it was tightly bound to specific game state).
/// Doesn't know what coins/gems are itself, it just displays a number.
class CurrencyCounter extends StatefulWidget {
  const CurrencyCounter({
    super.key,
    required this.value,
    this.icon = Icons.monetization_on,
    this.color,
    this.fontSize = 18,
    this.compact = true,
    this.semanticLabel,
    this.duration = const Duration(milliseconds: 500),
    this.enableTapToSkip = true,
    this.curve = Curves.easeOut,
  }) : assert(fontSize > 0, 'fontSize must be positive');

  final int value;
  final IconData icon;
  final Color? color;
  final double fontSize;

  /// `true` (default) formats via [fmtNumCompact] (e.g. `1500` → `"1.5K"`).
  /// `false` shows the exact value via [fmtNum] (locale-aware thousands
  /// separator, e.g. `"1,500"`) — for games that only want to compact
  /// truly large numbers, not every currency display.
  final bool compact;

  /// Overrides the default Semantics label (ENH-37), which otherwise reads
  /// the exact (never-compacted) value via [fmtNum] regardless of
  /// [compact] — a screen reader should always hear the precise amount.
  final String? semanticLabel;

  /// Duration of the rolling number animation (default 500ms).
  final Duration duration;

  /// When true (default), tapping the counter instantly skips to [value].
  final bool enableTapToSkip;

  /// Animation curve for rolling numbers (default [Curves.easeOut]).
  final Curve curve;

  @override
  State<CurrencyCounter> createState() => CurrencyCounterState();
}

class CurrencyCounterState extends State<CurrencyCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late CurvedAnimation _curvedAnimation;
  late int _startValue;
  late int _targetValue;
  late int _displayedValue;

  /// Currently visible value as the counter rolls.
  int get displayedValue => _displayedValue;

  /// Whether the number is actively rolling.
  bool get isAnimating => _controller.isAnimating;

  @override
  void initState() {
    super.initState();
    if (widget.duration <= Duration.zero) {
      throw ArgumentError.value(
        widget.duration,
        'duration',
        'must be positive',
      );
    }
    _startValue = widget.value;
    _targetValue = widget.value;
    _displayedValue = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addListener(_handleTick);
    _curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );
  }

  void _handleTick() {
    final double t = _curvedAnimation.value;
    final int next = (_startValue + (_targetValue - _startValue) * t).round();
    if (next != _displayedValue) {
      setState(() {
        _displayedValue = next;
      });
    }
  }

  /// Instantly completes ongoing number rolling to [widget.value].
  void skipToEnd() {
    if (_displayedValue != widget.value || _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
      setState(() {
        _startValue = widget.value;
        _targetValue = widget.value;
        _displayedValue = widget.value;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (NeonTheme.reducedMotion(context) && _controller.isAnimating) {
      skipToEnd();
    }
  }

  @override
  void didUpdateWidget(covariant CurrencyCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration <= Duration.zero) {
      throw ArgumentError.value(
        widget.duration,
        'duration',
        'must be positive',
      );
    }
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.curve != widget.curve) {
      _curvedAnimation.curve = widget.curve;
    }
    if (oldWidget.value != widget.value) {
      _animateTo(widget.value);
    }
  }

  void _animateTo(int newTarget) {
    if (NeonTheme.reducedMotion(context)) {
      _controller.stop();
      _controller.value = 1.0;
      _startValue = newTarget;
      _targetValue = newTarget;
      setState(() {
        _displayedValue = newTarget;
      });
      return;
    }

    _startValue = _displayedValue;
    _targetValue = newTarget;
    if (_startValue == _targetValue) {
      _controller.stop();
      _controller.value = 1.0;
      return;
    }

    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? NeonTheme.gold;
    Widget content = Semantics(
      label: widget.semanticLabel ?? fmtNum(widget.value),
      liveRegion: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, color: c, size: widget.fontSize + 6),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                widget.compact
                    ? fmtNumCompact(_displayedValue)
                    : fmtNum(_displayedValue),
                style: TextStyle(
                  color: NeonTheme.ink,
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.enableTapToSkip) {
      content = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: skipToEnd,
        child: content,
      );
    }

    return content;
  }
}

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

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
  });

  final int value;
  final IconData icon;
  final Color? color;
  final double fontSize;

  @override
  State<CurrencyCounter> createState() => _CurrencyCounterState();
}

class _CurrencyCounterState extends State<CurrencyCounter> {
  late int _from = widget.value;
  int _to = 0;

  @override
  void initState() {
    super.initState();
    _to = widget.value;
    _from = widget.value;
  }

  @override
  void didUpdateWidget(covariant CurrencyCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = old.value;
      _to = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? NeonTheme.gold;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(widget.icon, color: c, size: widget.fontSize + 6),
        const SizedBox(width: 4),
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: _from, end: _to),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          builder: (context, n, _) => Text(
            '$n',
            style: TextStyle(
              color: NeonTheme.ink,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

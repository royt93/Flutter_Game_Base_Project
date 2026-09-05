import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Icon + số lượng currency, đếm chạy mượt lên/xuống khi [value] đổi (thay vì
/// nhảy số tức thì) — thay thế generic cho `CoinChip` cũ (đã xoá vì gắn chặt
/// state game cụ thể). Không tự biết coins/gems là gì, chỉ hiển thị 1 con số.
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

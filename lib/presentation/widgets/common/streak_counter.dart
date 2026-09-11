import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Fire icon + a streak day count (consecutive logins, ...). Same
/// layout/spacing as [CurrencyCounter], but instead of counting up it pops
/// (scale bounce) whenever [days] increases — a reward moment, same spirit
/// as `StarRating`'s pop-in.
class StreakCounter extends StatefulWidget {
  const StreakCounter({
    super.key,
    required this.days,
    this.icon = Icons.local_fire_department,
    this.color,
    this.fontSize = 18,
  });

  final int days;
  final IconData icon;
  final Color? color;
  final double fontSize;

  @override
  State<StreakCounter> createState() => _StreakCounterState();
}

class _StreakCounterState extends State<StreakCounter>
    with SingleTickerProviderStateMixin {
  // Bắt đầu đã settled (value 1.0) — không animate lúc mount dù `days`
  // hiện sẵn là bao nhiêu. Chỉ `forward(from: 0.0)` tường minh khi
  // `days` thực sự tăng (xem didUpdateWidget), không dựa vào việc build
  // lại tween/key để "ép" implicit animation replay — cách đó hoá ra
  // không đáng tin cậy (element mới có thể không được TesterWidget query
  // đúng ngay trong cùng 1 frame do thứ tự deactivate/finalize của
  // Flutter), nên dùng AnimationController tường minh cho chắc.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 1.0,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.7,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void didUpdateWidget(covariant StreakCounter old) {
    super.didUpdateWidget(old);
    if (widget.days > old.days && !NeonTheme.reducedMotion(context)) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? NeonTheme.orange;
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) =>
          Transform.scale(scale: _scale.value, child: child),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, color: c, size: widget.fontSize + 6),
          const SizedBox(width: 4),
          Text(
            '${widget.days}',
            style: TextStyle(
              color: NeonTheme.ink,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Hàng N sao (thường 3) — [earned] sao đầu tô sáng/glow, phần còn lại outline
/// mờ. Kiểu "level complete, đạt 2/3 sao" kinh điển. [animate] = true thì mỗi
/// sao pop-in lệch delay sau sao trước (dùng lúc vừa nhận thưởng); false thì
/// vẽ tĩnh (đã đạt từ trước, hiển thị lại không cần replay animation).
class StarRating extends StatefulWidget {
  const StarRating({
    super.key,
    required this.earned,
    this.total = 3,
    this.size = 40,
    this.animate = false,
  });

  final int earned;
  final int total;
  final double size;
  final bool animate;

  @override
  State<StarRating> createState() => _StarRatingState();
}

class _StarRatingState extends State<StarRating>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _c = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 300 + widget.total * 150),
      )..forward();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stars = List.generate(widget.total, (i) {
      final filled = i < widget.earned;
      final star = Icon(
        filled ? Icons.star_rounded : Icons.star_outline_rounded,
        size: widget.size,
        color: filled ? NeonTheme.gold : NeonTheme.muted,
        shadows: filled
            ? [Shadow(color: NeonTheme.gold, blurRadius: widget.size * 0.3)]
            : null,
      );
      if (_c == null) return star;
      final start = i / widget.total;
      final anim = CurvedAnimation(
        parent: _c!,
        curve: Interval(start, 1.0, curve: Curves.easeOutBack),
      );
      return ScaleTransition(scale: anim, child: star);
    });
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in stars) ...[s, if (s != stars.last) const SizedBox(width: 4)],
      ],
    );
  }
}

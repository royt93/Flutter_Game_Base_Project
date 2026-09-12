import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// A row of N stars (usually 3) — the first [earned] stars are lit/glowing,
/// the rest are a dim outline. The classic "level complete, got 2/3 stars"
/// look. [animate] = true makes each star pop in with a staggered delay
/// after the previous one (used right after earning the reward); false
/// draws it statically (already earned earlier, shown again without
/// replaying the animation).
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
    with TickerProviderStateMixin {
  AnimationController? _c;
  bool _startedOnce = false;

  // BUG-31: a star newly earned AFTER mount (no unmount/remount — e.g. the
  // player scores another star in the same level-complete screen) gets its
  // own independent pop-in controller here, separate from [_c] (which only
  // ever plays once, at mount, for whatever was already earned then).
  final Map<int, AnimationController> _perStar = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery can't be read in initState — didChangeDependencies is the
    // earliest safe place, and runs once before the first build.
    if (_startedOnce) return;
    _startedOnce = true;
    if (widget.animate && !NeonTheme.reducedMotion(context)) {
      _c = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 300 + widget.total * 150),
      )..forward();
    }
  }

  @override
  void didUpdateWidget(covariant StarRating oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.earned <= oldWidget.earned) return;
    if (NeonTheme.reducedMotion(context)) return;
    for (var i = oldWidget.earned; i < widget.earned; i++) {
      (_perStar[i] ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ))
        ..value = 0.0
        ..forward();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    for (final c in _perStar.values) {
      c.dispose();
    }
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
      final perStar = _perStar[i];
      if (perStar != null) {
        final anim = CurvedAnimation(parent: perStar, curve: Curves.easeOutBack);
        return ScaleTransition(scale: anim, child: star);
      }
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
        for (final s in stars) ...[
          s,
          if (s != stars.last) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

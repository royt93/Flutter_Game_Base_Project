import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Skeleton-loading block for list/grid content that hasn't finished
/// loading yet (a shop item row, a level list waiting on a cloud-save
/// sync) — unlike [LoadingOverlay] (a full-screen barrier), this sits
/// in-place as a stand-in for the real content.
///
/// A rounded [NeonTheme.cardAlt] block with a lighter band sweeping across
/// it on a loop, built from a plain looping `AnimationController` +
/// `LinearGradient` — no `shimmer` package needed for this.
class ShimmerPlaceholder extends StatefulWidget {
  const ShimmerPlaceholder({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
    this.duration = const Duration(milliseconds: 1200),
  });

  final double? width;
  final double height;
  final double borderRadius;
  final Duration duration;

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _startedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery can't be read in initState — didChangeDependencies is the
    // earliest safe place, and runs once before the first build. The sweep
    // is purely decorative (a static cardAlt block still reads as "loading"
    // without it), so Reduce Motion just never starts the repeat() loop —
    // the controller stays at its initial value (0), rendering a static
    // block instead of trying to "instantly complete" a looping animation
    // that has no natural end state.
    if (_startedOnce) return;
    _startedOnce = true;
    if (!NeonTheme.reducedMotion(context)) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = NeonTheme.cardAlt;
    final highlight = NeonTheme.card;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // t sweeps the highlight band from fully off-left to fully off-right
        // of the box, then loops.
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-3 + 6 * t, 0),
              end: Alignment(-1 + 6 * t, 0),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

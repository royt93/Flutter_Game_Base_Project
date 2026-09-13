import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Rounded pill-shaped progress bar with 1-3 star markers along the track —
/// a marker the fill has passed lights up (filled), otherwise it stays a
/// dim outline. Used for world progress / event tracks like "reach
/// 33%/66%/100% to unlock a star".
///
/// A marker pops (scale bounce) the moment [progress] crosses its
/// threshold — same "earned a star" moment `StarRating` already animates —
/// but never on initial mount even if that threshold is already met (a
/// `StatefulWidget` starting all its markers at rest avoids every
/// already-earned star popping in unison on first build).
class ProgressBarStars extends StatefulWidget {
  const ProgressBarStars({
    super.key,
    required this.progress,
    this.starThresholds = const [0.33, 0.66, 1.0],
    this.height = 20,
    this.fillColor,
    this.trackColor,
    this.semanticLabel,
  });

  /// 0.0-1.0.
  final double progress;

  /// Star markers (0.0-1.0), in practice 1-3 of them at most.
  final List<double> starThresholds;
  final double height;
  final Color? fillColor;
  final Color? trackColor;

  /// Overrides the default "Progress: N%" Semantics label (ENH-37).
  final String? semanticLabel;

  @override
  State<ProgressBarStars> createState() => _ProgressBarStarsState();
}

class _ProgressBarStarsState extends State<ProgressBarStars>
    with TickerProviderStateMixin {
  final Map<double, AnimationController> _controllers = {};

  AnimationController _controllerFor(double t) {
    return _controllers.putIfAbsent(
      t,
      () => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
        value: 1.0,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant ProgressBarStars old) {
    super.didUpdateWidget(old);
    if (NeonTheme.reducedMotion(context)) return;
    final p = widget.progress.clamp(0.0, 1.0);
    final oldP = old.progress.clamp(0.0, 1.0);
    for (final t in widget.starThresholds) {
      if (oldP < t && p >= t) _controllerFor(t).forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress.clamp(0.0, 1.0);
    final fill = widget.fillColor ?? NeonTheme.lime;
    final track = widget.trackColor ?? NeonTheme.cardAlt;
    return Semantics(
      label: widget.semanticLabel ?? 'Progress: ${(p * 100).round()}%',
      value: '${(p * 100).round()}%',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return SizedBox(
            height: widget.height + 10,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomLeft,
              children: [
                Container(
                  width: w,
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: track,
                    borderRadius: BorderRadius.circular(widget.height),
                    border: Border.all(color: NeonTheme.muted, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: p),
                      duration: NeonTheme.reducedMotion(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      builder: (context, t, _) => FractionallySizedBox(
                        widthFactor: t,
                        child: Container(
                          height: widget.height,
                          decoration: BoxDecoration(
                            color: fill,
                            borderRadius: BorderRadius.circular(widget.height),
                            boxShadow: NeonTheme.glow(
                              fill,
                              blur: 10,
                              spread: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                for (final t in widget.starThresholds)
                  Positioned(
                    left: (w * t.clamp(0.0, 1.0) - 12).clamp(0.0, w - 24),
                    bottom: widget.height - 6,
                    child: AnimatedBuilder(
                      animation: _controllerFor(t),
                      builder: (context, child) {
                        final scale = Tween<double>(begin: 0.6, end: 1.0)
                            .transform(
                              Curves.easeOutBack.transform(
                                _controllerFor(t).value,
                              ),
                            );
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Icon(
                        p >= t
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 24,
                        color: p >= t ? NeonTheme.gold : NeonTheme.muted,
                        shadows: p >= t
                            ? [Shadow(color: NeonTheme.gold, blurRadius: 8)]
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

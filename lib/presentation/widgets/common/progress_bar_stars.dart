import 'dart:math' as math;

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
    this.staggerDuration = const Duration(milliseconds: 250),
    this.onStarPopped,
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

  /// Delay between each star pop when progress crosses multiple thresholds.
  final Duration staggerDuration;

  /// Called with the threshold index as each newly earned star pops.
  final ValueChanged<int>? onStarPopped;

  @override
  State<ProgressBarStars> createState() => _ProgressBarStarsState();
}

class _ProgressBarStarsState extends State<ProgressBarStars>
    with SingleTickerProviderStateMixin {
  static const _popDuration = Duration(milliseconds: 300);

  late final AnimationController _burstController;
  final Map<int, int> _startAtUs = {};
  final Set<int> _visibleStars = {};
  final Set<int> _notifiedIndices = {};
  int _elapsedUs = 0;
  bool _burstRunning = false;

  @override
  void initState() {
    super.initState();
    if (widget.staggerDuration < Duration.zero) {
      throw ArgumentError.value(
        widget.staggerDuration,
        'staggerDuration',
        'must not be negative',
      );
    }
    final initial = widget.progress.clamp(0.0, 1.0);
    for (var i = 0; i < widget.starThresholds.length; i++) {
      if (initial >= widget.starThresholds[i]) _visibleStars.add(i);
    }
    _burstController = AnimationController(vsync: this)
      ..addListener(_onBurstTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _burstRunning = false;
          _startAtUs.clear();
          _notifiedIndices.clear();
          _elapsedUs = 0;
        }
      });
  }

  void _onBurstTick() {
    final durationUs = _burstController.duration?.inMicroseconds ?? 0;
    if (durationUs == 0) return;
    _elapsedUs = math.max(
      _elapsedUs,
      (_burstController.value * durationUs).round(),
    );
    for (final entry in _startAtUs.entries) {
      if (_elapsedUs >= entry.value && _visibleStars.add(entry.key)) {
        if (_notifiedIndices.add(entry.key)) {
          widget.onStarPopped?.call(entry.key);
        }
        setState(() {});
      }
    }
  }

  @override
  void didUpdateWidget(covariant ProgressBarStars old) {
    super.didUpdateWidget(old);
    if (widget.staggerDuration < Duration.zero) {
      throw ArgumentError.value(
        widget.staggerDuration,
        'staggerDuration',
        'must not be negative',
      );
    }
    _captureElapsed();
    final p = widget.progress.clamp(0.0, 1.0);
    final oldP = old.progress.clamp(0.0, 1.0);
    if (p < oldP) {
      for (var i = 0; i < widget.starThresholds.length; i++) {
        if (widget.starThresholds[i] > p) {
          _startAtUs.remove(i);
          _visibleStars.remove(i);
          _notifiedIndices.remove(i);
        }
      }
      _resumeRemainingBurst();
    }

    final crossed = <int>[];
    for (var i = 0; i < widget.starThresholds.length; i++) {
      final threshold = widget.starThresholds[i];
      if (oldP < threshold && p >= threshold) crossed.add(i);
    }
    if (crossed.isEmpty) return;

    if (NeonTheme.reducedMotion(context)) {
      for (final index in crossed) {
        _startAtUs.remove(index);
        _visibleStars.add(index);
        if (_notifiedIndices.add(index)) widget.onStarPopped?.call(index);
      }
      _resumeRemainingBurst();
      return;
    }
    _scheduleBurst(crossed);
  }

  void _captureElapsed() {
    final durationUs = _burstController.duration?.inMicroseconds ?? 0;
    if (_burstRunning && durationUs > 0) {
      _elapsedUs = math.max(
        _elapsedUs,
        (_burstController.value * durationUs).round(),
      );
    }
  }

  void _scheduleBurst(List<int> indices) {
    _captureElapsed();
    var nextStart = _startAtUs.values.isEmpty
        ? _elapsedUs
        : math.max(
            _elapsedUs,
            _startAtUs.values.reduce(math.max) +
                widget.staggerDuration.inMicroseconds,
          );
    for (final index in indices) {
      if (_visibleStars.contains(index) || _startAtUs.containsKey(index)) {
        continue;
      }
      _startAtUs[index] = nextStart;
      nextStart += widget.staggerDuration.inMicroseconds;
    }
    _resumeRemainingBurst();
  }

  void _resumeRemainingBurst() {
    if (_startAtUs.isEmpty) {
      _burstController.stop();
      _burstRunning = false;
      _elapsedUs = 0;
      return;
    }
    final durationUs =
        _startAtUs.values.reduce(math.max) + _popDuration.inMicroseconds;
    _burstController.duration = Duration(microseconds: durationUs);
    _burstRunning = true;
    _burstController.forward(from: (_elapsedUs / durationUs).clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    _burstController.dispose();
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
          // ENH-38: bottomStart/centerStart resolve against ambient
          // Directionality, so the fill grows from the natural reading
          // start (physical left in LTR, physical right in RTL) instead of
          // always growing from the physical left.
          return SizedBox(
            height: widget.height + 10,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: AlignmentDirectional.bottomStart,
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
                    alignment: AlignmentDirectional.centerStart,
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
                  Positioned.directional(
                    textDirection: Directionality.of(context),
                    start: (w * t.clamp(0.0, 1.0) - 12).clamp(0.0, w - 24),
                    bottom: widget.height - 6,
                    child: AnimatedBuilder(
                      animation: _burstController,
                      builder: (context, child) {
                        final index = widget.starThresholds.indexOf(t);
                        var scale = 1.0;
                        final startUs = _startAtUs[index];
                        if (_burstRunning &&
                            startUs != null &&
                            _elapsedUs >= startUs) {
                          final localUs = _elapsedUs - startUs;
                          final local = (localUs / _popDuration.inMicroseconds)
                              .clamp(0.0, 1.0);
                          scale = Tween<double>(
                            begin: 0.6,
                            end: 1.0,
                          ).transform(Curves.easeOutBack.transform(local));
                        }
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Icon(
                        _visibleStars.contains(widget.starThresholds.indexOf(t))
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

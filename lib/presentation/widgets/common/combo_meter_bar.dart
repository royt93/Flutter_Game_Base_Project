import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Returns the theme color for a combo [multiplier] level (FEAT-128).
///
/// Ladder heats up as combo builds:
/// - 1x: [NeonTheme.cyan] (cool / entry)
/// - 2x: [NeonTheme.lime] (warming)
/// - 3x: [NeonTheme.gold] (high)
/// - 4x: [NeonTheme.orange] (hot)
/// - 5x+: [NeonTheme.magenta] (maximum heat / frenzy)
Color comboTierColor(int multiplier) {
  if (multiplier <= 1) return NeonTheme.cyan;
  if (multiplier == 2) return NeonTheme.lime;
  if (multiplier == 3) return NeonTheme.gold;
  if (multiplier == 4) return NeonTheme.orange;
  return NeonTheme.magenta;
}

/// A compact, dynamic combo HUD meter (FEAT-128).
///
/// Features:
/// - Capsule-shaped progress bar that heats up in color with the [multiplier] tier.
/// - Playful squash-stretch pop (via [NeonTheme.curvePop]) on the multiplier
///   badge when [multiplier] increases.
/// - Smooth progress easing without celebration shakes when combo decays or resets.
/// - Pure data-driven presentation: caller computes [multiplier] and [progress]
///   (0.0..1.0), matching the kit's convention (e.g. `ComboHeatBackground`).
/// - Reduced Motion: bypasses the squash-stretch pop, still animating progress and colors.
class ComboMeterBar extends StatefulWidget {
  ComboMeterBar({
    super.key,
    required this.multiplier,
    required this.progress,
    this.height = 22,
    this.width,
    this.trackColor,
    this.showMultiplierBadge = true,
    this.semanticLabel,
  }) {
    if (multiplier < 1) {
      throw ArgumentError.value(multiplier, 'multiplier', 'must be at least 1');
    }
    if (!progress.isFinite || progress < 0.0 || progress > 1.0) {
      throw ArgumentError.value(
        progress,
        'progress',
        'must be finite and between 0.0 and 1.0',
      );
    }
    if (!height.isFinite || height <= 0) {
      throw ArgumentError.value(
        height,
        'height',
        'must be finite and positive',
      );
    }
    if (width != null && (!width!.isFinite || width! <= 0)) {
      throw ArgumentError.value(width, 'width', 'must be finite and positive');
    }
  }

  /// Current combo multiplier tier (1 for base 1x, 2 for 2x, etc.).
  final int multiplier;

  /// Progress toward the next multiplier level or decay bar (0.0 to 1.0).
  final double progress;

  /// Height of the meter bar.
  final double height;

  /// Optional fixed width. If omitted, expands to fill available width.
  final double? width;

  /// Custom track background color. Defaults to [NeonTheme.cardAlt].
  final Color? trackColor;

  /// Whether to render the leading "xN" multiplier badge.
  final bool showMultiplierBadge;

  /// Overrides the default Semantics announcement.
  final String? semanticLabel;

  @override
  State<ComboMeterBar> createState() => _ComboMeterBarState();
}

class _ComboMeterBarState extends State<ComboMeterBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _popController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void didUpdateWidget(covariant ComboMeterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Celebrate ONLY on multiplier increases (IDEA-21 motion convention).
    // Decays, drops, or same-tier progress updates glide smoothly with no pop.
    if (widget.multiplier > oldWidget.multiplier &&
        !NeonTheme.reducedMotion(context)) {
      _popController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = NeonTheme.reducedMotion(context);
    final tierColor = comboTierColor(widget.multiplier);
    final track = widget.trackColor ?? NeonTheme.cardAlt;
    final animDuration = NeonTheme.motionDuration(
      context,
      const Duration(milliseconds: 250),
    );

    final percent = (widget.progress * 100).round();
    final defaultSemantic = 'Combo x${widget.multiplier}, $percent percent';

    final barContent = SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final fillWidth = totalWidth * widget.progress.clamp(0.0, 1.0);

          return Container(
            decoration: BoxDecoration(
              color: track,
              borderRadius: BorderRadius.circular(widget.height / 2),
              border: Border.all(
                color: tierColor.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.height / 2),
              child: Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [
                  AnimatedContainer(
                    duration: animDuration,
                    curve: Curves.easeOut,
                    width: fillWidth,
                    height: widget.height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color.lerp(tierColor, Colors.white, 0.25)!,
                          tierColor,
                        ],
                      ),
                      boxShadow: widget.progress > 0
                          ? NeonTheme.glow(tierColor, blur: 8)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    final badge = widget.showMultiplierBadge
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: tierColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: NeonTheme.drop(blur: 4),
            ),
            child: Text(
              'x${widget.multiplier}',
              key: const ValueKey('comboMultiplierLabel'),
              style: TextStyle(
                color: NeonTheme.ink,
                fontSize: math.max(12.0, widget.height * 0.65),
                fontWeight: FontWeight.w900,
              ),
            ),
          )
        : null;

    final row = Row(
      mainAxisSize: widget.width != null ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (badge != null) ...[badge, const SizedBox(width: NeonTheme.s8)],
        Expanded(child: barContent),
      ],
    );

    // Apply squash-stretch pop on tier-up
    final animatedRow = AnimatedBuilder(
      animation: _popController,
      builder: (context, child) {
        final t = _popController.value;
        final popScale = reducedMotion
            ? 1.0
            : 1.0 + 0.12 * math.sin(t * math.pi);
        return Transform.scale(
          key: const ValueKey('comboMeterPopScale'),
          scale: popScale,
          child: child,
        );
      },
      child: row,
    );

    Widget root = RepaintBoundary(
      child: widget.width != null
          ? SizedBox(width: widget.width, child: animatedRow)
          : animatedRow,
    );

    return Semantics(
      label: widget.semanticLabel ?? defaultSemantic,
      value: '$percent%',
      excludeSemantics: true,
      child: root,
    );
  }
}
